//############################################################################//
//Made in 2017 by Artyom Litvinovich
//viterbi27 decoder, with standard polynomials and non-inverted G1 and G2
//Assumes signed 8 bit soft samples
//############################################################################//
unit viterbi27;
interface
uses asys,correlator,bitop;
//############################################################################//
const
VITERBI27_POLYA= 79;   // 1001111
VITERBI27_POLYB=109;   // 1101101

soft_max=255;
distance_max=65535;
frame_bits=1024*8;
num_states=128;
high_bit=64;
encode_len=2*(frame_bits+8);    
num_iter=high_bit shl 1;

min_traceback=5*7;
traceback_length=15*7;
renormalize_interval=distance_max div (2*soft_max);
//############################################################################//
type
error_array=array[0..num_states-1]of word; perror_array=^error_array;
hist_array =array[0..num_states-1]of byte; phist_array =^hist_array;
viterbi27_rec=record
 ber:integer;

 dist_table:array[0..3]of array[0..65535]of word;
 table:array[0..num_states-1]of byte;
 distances:array[0..3]of word;

 bit_writer:bit_io_rec;

 //pair_lookup
 pair_keys:array[0..63]of dword;      //1 shl (order-1)
 pair_distances:array of dword;
 pair_outputs:array[0..15]of dword;   //1 shl (2*rate)
 pair_outputs_len:dword;

 history:array[0..min_traceback+traceback_length-1]of hist_array;
 fetched:array[0..min_traceback+traceback_length-1]of byte;
 hist_index,len,renormalize_counter:integer;

 err_index:integer;
 errors:array[0..1]of error_array;
 read_errors,write_errors:perror_array;
end;
//############################################################################//
procedure mk_viterbi27(out v:viterbi27_rec);
procedure vit_decode(var v:viterbi27_rec;input,output:pbytea);
function vit_get_percent_BER(const v:viterbi27_rec):single;
//############################################################################//
implementation
//############################################################################//
function vit_get_percent_BER(const v:viterbi27_rec):single;begin result:=(100*v.BER)/frame_bits;end;
//############################################################################//
function metric_soft_distance(hard,soft_y0,soft_y1:byte):word;
const mag=255;
var soft_x0,soft_x1:integer;
begin
 case hard and 3 of
  0:begin soft_x0:= mag;soft_x1:= mag;end;
  1:begin soft_x0:=-mag;soft_x1:= mag;end;
  2:begin soft_x0:= mag;soft_x1:=-mag;end;
  3:begin soft_x0:=-mag;soft_x1:=-mag;end;
  else begin soft_x0:=0;soft_x1:=0;end; //Dewarning
 end;

   result:=abs(shortint(soft_y0)-soft_x0)+abs(shortint(soft_y1)-soft_x1);                //Linear distance
 //result:=round(sqrt(sqr(shortint(soft_y0)-soft_x0)+sqr(shortint(soft_y1)-soft_x1)));   //Quadratic distance, not much better or worse.
end;
//############################################################################//
procedure pair_lookup_create(var v:viterbi27_rec);
var inv_outputs:array[0..15]of dword;
output_counter,o:dword;
i:integer;
begin
 for i:=0 to 15 do inv_outputs[i]:=0;
 output_counter:=1;

 for i:=0 to 63 do begin
  o:=(v.table[i*2+1] shl 2) or v.table[i*2];

  if inv_outputs[o]=0 then begin
   inv_outputs[o]:=output_counter;
   v.pair_outputs[output_counter]:=o;
   output_counter:=output_counter+1;
  end;

  v.pair_keys[i]:=inv_outputs[o];
 end;
 v.pair_outputs_len:=output_counter;
 setlength(v.pair_distances,v.pair_outputs_len);
end;
//############################################################################//
procedure pair_lookup_fill_distance(var v:viterbi27_rec);
var i:integer;
c,i0,i1:dword;
begin
 for i:=1 to v.pair_outputs_len-1 do begin
  c:=v.pair_outputs[i];
  i0:=c and 3;
  i1:=c shr 2;

  v.pair_distances[i]:=(v.distances[i1] shl 16) or v.distances[i0];
 end;
end;
//############################################################################//
function history_buffer_search(var v:viterbi27_rec;search_every:integer):dword;
var least,bestpath:dword;
state:integer;
begin
 bestpath:=0;
 least:=$FFFF;

 state:=0;
 while state<num_states div 2 do begin
  if v.write_errors[state]<least then begin least:=v.write_errors[state];bestpath:=state;end;
  state:=state+search_every;
 end;
 result:=bestpath;
end;
//############################################################################//
procedure history_buffer_renormalize(var v:viterbi27_rec;min_register:dword);
var min_distance:word;
i:integer;
begin
 min_distance:=v.write_errors[min_register];
 for i:=0 to num_states div 2-1 do v.write_errors[i]:=v.write_errors[i]-min_distance;
end;
//############################################################################//
procedure history_buffer_traceback(var v:viterbi27_rec;bestpath,min_traceback_length:dword);
var j:integer;
index,fetched_index,pathbit,prefetch_index,len:dword;
history:byte;
begin
 fetched_index:=0;
 index:=v.hist_index;
 for j:=0 to min_traceback_length-1 do begin
  if index=0 then index:=min_traceback+traceback_length-1
             else index:=index-1;
  history:=v.history[index][bestpath];
  if history<>0 then pathbit:=high_bit else pathbit:=0;
  bestpath:=(bestpath or pathbit) shr 1;
 end;
 prefetch_index:=index;
 if prefetch_index=0 then prefetch_index:=min_traceback+traceback_length-1
                     else prefetch_index:=prefetch_index-1;
 len:=v.len;
 for j:=min_traceback_length to len-1 do begin
  index:=prefetch_index;
  if prefetch_index=0 then prefetch_index:=min_traceback+traceback_length-1
                      else prefetch_index:=prefetch_index-1;
  history:=v.history[index][bestpath];
  if history<>0 then pathbit:=high_bit else pathbit:=0;
  bestpath:=(bestpath or pathbit) shr 1;
  if pathbit<>0 then v.fetched[fetched_index]:=1
                else v.fetched[fetched_index]:=0;
  fetched_index:=fetched_index+1;
 end;
 bio_write_bitlist_reversed(v.bit_writer,@v.fetched[0],fetched_index);
 v.len:=v.len-fetched_index;
end;
//############################################################################//
procedure history_buffer_process_skip(var v:viterbi27_rec;skip:integer);
var bestpath:dword;
begin
 v.hist_index:=v.hist_index+1;
 if v.hist_index=min_traceback+traceback_length then v.hist_index:=0;

 v.renormalize_counter:=v.renormalize_counter+1;
 v.len:=v.len+1;

 if v.renormalize_counter=renormalize_interval then begin
  v.renormalize_counter:=0;
  bestpath:=history_buffer_search(v,skip);
  history_buffer_renormalize(v,bestpath);
  if v.len=min_traceback+traceback_length then history_buffer_traceback(v,bestpath,min_traceback);
 end else if v.len=min_traceback+traceback_length then begin
  bestpath:=history_buffer_search(v,skip);
  history_buffer_traceback(v,bestpath,min_traceback);
 end
end;
//############################################################################//
procedure error_buffer_swap(var v:viterbi27_rec);
begin
 v.read_errors:=@v.errors[v.err_index];
 v.err_index:=(v.err_index+1) mod 2;
 v.write_errors:=@v.errors[v.err_index];
end;
//############################################################################//
procedure vit_inner(var v:viterbi27_rec;soft:pbytea);
var highbase,low,high,base,offset,base_offset:dword;
i,j:integer;
history:phist_array;
low_key,high_key,low_concat_dist,high_concat_dist,successor,low_plus_one,plus_one_successor:dword;
low_past_error,high_past_error,low_error,high_error,error,low_plus_one_error,high_plus_one_error,plus_one_error:word;
history_mask,plus_one_history_mask:byte;
begin
 for i:=0 to 5 do begin
  for j:=0 to (1 shl (i+1))-1 do v.write_errors[j]:=v.dist_table[v.table[j]][pword(@soft[i*2])^]+v.read_errors[j shr 1];
  error_buffer_swap(v);
 end;

 for i:=6 to frame_bits-7 do begin
  for j:=0 to 3 do v.distances[j]:=v.dist_table[j][pword(@soft[i*2])^];   
  history:=@v.history[v.hist_index];

  pair_lookup_fill_distance(v);

  highbase:=high_bit shr 1;
  low:=0;
  high:=high_bit;
  base:=0;
  while high<num_iter do begin
   offset:=0;
   base_offset:=0;
   while base_offset<4 do begin
    low_key :=v.pair_keys[base         +base_offset];
    high_key:=v.pair_keys[highbase+base+base_offset];

    low_concat_dist :=v.pair_distances[low_key];
    high_concat_dist:=v.pair_distances[high_key];

    low_past_error :=v.read_errors[         base+base_offset];
    high_past_error:=v.read_errors[highbase+base+base_offset];

    low_error :=(low_concat_dist  and $ffff)+low_past_error;
    high_error:=(high_concat_dist and $ffff)+high_past_error;

    successor:=low+offset;
    if low_error<=high_error then begin error:=low_error; history_mask:=0;end
                             else begin error:=high_error;history_mask:=1;end;
    v.write_errors[successor]:=error;
    history[successor]:=history_mask;

    low_plus_one:=low+offset+1;

    low_plus_one_error :=(low_concat_dist  shr 16)+low_past_error;
    high_plus_one_error:=(high_concat_dist shr 16)+high_past_error;

    plus_one_successor:=low_plus_one;
    if low_plus_one_error<=high_plus_one_error then begin plus_one_error:=low_plus_one_error; plus_one_history_mask:=0;end
                                               else begin plus_one_error:=high_plus_one_error;plus_one_history_mask:=1;end;
    v.write_errors[plus_one_successor]:=plus_one_error;
    history[plus_one_successor]:=plus_one_history_mask;

    offset:=offset+2;
    base_offset:=base_offset+1;
   end;

   low:=low+8;
   high:=high+8;
   base:=base+4;
  end;

  history_buffer_process_skip(v,1);
  error_buffer_swap(v);
 end
end;
//############################################################################//
procedure vit_tail(var v:viterbi27_rec;soft:pbytea);
var i,j:integer;
history:phist_array;
skip,base_skip,highbase,low,high,base,low_output,high_output:dword;
low_dist,high_dist,low_past_error,high_past_error,low_error,high_error:word;
successor:dword;
error:word;
history_mask:byte;
begin
 for i:=frame_bits-6 to frame_bits-1 do begin
  for j:=0 to 3 do v.distances[j]:=v.dist_table[j][pword(@soft[i*2])^];
  history:=@v.history[v.hist_index];

  skip:=1 shl (7-(frame_bits-i));
  base_skip:=skip shr 1;

  highbase:=high_bit shr 1;
  low:=0;
  high:=high_bit;
  base:=0;
  while high<num_iter do begin
   low_output :=v.table[low];
   high_output:=v.table[high];

   low_dist :=v.distances[low_output];
   high_dist:=v.distances[high_output];

   low_past_error :=v.read_errors[         base];
   high_past_error:=v.read_errors[highbase+base];

   low_error :=low_dist +low_past_error;
   high_error:=high_dist+high_past_error;

   successor:=low;
   if low_error<high_error then begin error:=low_error; history_mask:=0;end
                           else begin error:=high_error;history_mask:=1;end;
   v.write_errors[successor]:=error;
   history[successor]:=history_mask;

   low:=low+skip;
   high:=high+skip;
   base:=base+base_skip;
  end;

  history_buffer_process_skip(v,skip);
  error_buffer_swap(v);
 end;
end;
//############################################################################//
procedure vit_conv_decode(var v:viterbi27_rec;msg,soft_encoded:pbytea);
begin
 bit_writer_create(v.bit_writer,msg,frame_bits*2 div 8);

 //history_buffer
 v.len:=0;
 v.hist_index:=0;
 v.renormalize_counter:=0;

 //Error buffer
 fillchar(v.errors[0][0],num_states*2,0);
 fillchar(v.errors[1][0],num_states*2,0);
 v.err_index:=0;
 v.read_errors :=@v.errors[0][0];
 v.write_errors:=@v.errors[1][0];

 vit_inner (v,soft_encoded);
 vit_tail  (v,soft_encoded);

 history_buffer_traceback(v,0,0);
end;
//############################################################################//
procedure vit_conv_encode(var v:viterbi27_rec;input,output:pbytea);
var sh:dword;
i:integer;
b:bit_io_rec;
begin
 b.p:=input;
 b.pos:=0;
      
 sh:=0;
 for i:=0 to frame_bits-1 do begin
  sh:=((sh shl 1) or bio_fetch_n_bits(b,1)) and $7F;
  if (v.table[sh] and 1)<>0 then output[i*2+0]:=0 else output[i*2+0]:=255;
  if (v.table[sh] and 2)<>0 then output[i*2+1]:=0 else output[i*2+1]:=255;
 end;
end;
//############################################################################//
procedure vit_decode(var v:viterbi27_rec;input,output:pbytea);    
var i:integer;
corrected:array[0..frame_bits*2-1]of byte;
begin
 vit_conv_decode(v,output,input);

 //Gauge error level
 vit_conv_encode(v,output,@corrected[0]);
 v.BER:=0;
 for i:=0 to frame_bits*2-1 do v.BER:=v.BER+hard_correlate(input[i],$FF xor corrected[i]);
end;
//############################################################################//
procedure mk_viterbi27(out v:viterbi27_rec);
var i,j:integer;
begin
 v.BER:=0;

 //Metric lookup table
 for i:=0 to 3 do for j:=0 to 65535 do v.dist_table[i][j]:=metric_soft_distance(i,j and $FF,j shr 8);

 //Polynomial table
 for i:=0 to 127 do begin
  v.table[i]:=0;
  if (count_bits(i and VITERBI27_POLYA) mod 2)<>0 then v.table[i]:=v.table[i] or 1;
  if (count_bits(i and VITERBI27_POLYB) mod 2)<>0 then v.table[i]:=v.table[i] or 2;
 end;

 pair_lookup_create(v);
end;
//############################################################################//
begin
end.
//############################################################################//
