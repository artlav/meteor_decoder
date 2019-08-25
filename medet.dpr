//############################################################################//
//Made in 2017-2019 by Artyom Litvinovich
//Meteor decoder
//############################################################################//
program medet;
{$ifdef mswindows}{$APPTYPE console}{$endif}
uses sysutils,asys,met_to_data,met_jpg,met_packet,tim,correlator,viterbi27;
//############################################################################//
const
INP_SOFT=0;
INP_HARD=1;
INP_DEC=2;

CONV_NONE=0;
CONV_HARD=1;
CONV_DEC=2;
//############################################################################//
ansi_back_to_start=#27'[2K'#27'[1G';
//############################################################################//
//Interleaver parameters
inter_branches=36;
inter_delay=2048;
inter_base_len=inter_branches*inter_delay;
//############################################################################//
var isqrt_tab:array[0..32768]of shortint;
//############################################################################//
procedure print_times(out_name:string);
var h,m,s,ms,dh,dm,ds,dms,delta:integer;
f:text;
begin
 if no_time_yet then exit;
 if last_time<first_time then last_time:=last_time+86400*1000;  //If it crossed midnight

 delta:=last_time-first_time;

 dh:=delta div (3600*1000); delta:=delta-dh*3600*1000;
 dm:=delta div (60*1000);   delta:=delta-dm*60*1000;
 ds:=delta div 1000;        delta:=delta-ds*1000;
 dms:=delta;

 h:=first_time div (3600*1000); first_time:=first_time-h*3600*1000;
 m:=first_time div (60*1000);   first_time:=first_time-m*60*1000;
 s:=first_time div 1000;        first_time:=first_time-s*1000;
 ms:=first_time;

 if print_stats then writeln('Elapsed time: ',trimsl(stri(dh),2,'0'),':',trimsl(stri(dm),2,'0'),':',trimsl(stri(ds),2,'0'),'.',trimsl(stri(dms),3,'0'));

 if time_file then begin
  assignfile(f,out_name+'.stat');
  rewrite(f);

  //LRPT_places needs windows line endings
  write(f,trimsl(stri( h),2,'0'),':',trimsl(stri( m),2,'0'),':',trimsl(stri( s),2,'0'),'.',trimsl(stri( ms),3,'0')+#$0D#$0A);
  write(f,trimsl(stri(dh),2,'0'),':',trimsl(stri(dm),2,'0'),':',trimsl(stri(ds),2,'0'),'.',trimsl(stri(dms),3,'0')+#$0D#$0A);
  write(f,'0,1538925'+#$0D#$0A);   //WTF? Appears irrelevant

  closefile(f);
 end;
end;
//############################################################################//
procedure recreate_packet(var m:mtd_rec;pck,hard:pbytea;var hard_pos:integer);
var raw:array[0..frame_bits*2-1]of byte;
input:array[0..hard_frame_len-1]of byte;
i:integer;
begin
 move(pck[0],input[4],hard_frame_len-4);
 pdword(@input[0])^:=$1DFCCF1A;
 for i:=0 to hard_frame_len-4-1 do input[4+i]:=input[4+i] xor prand[i mod 255];

 vit_conv_encode(m.v,@input[0],@raw[0]);

 soft_to_hard(@raw[0],@hard[hard_pos],soft_frame_len);
 hard_pos:=hard_pos+2*hard_frame_len;
end;
//############################################################################//
procedure dump_packet(pck,hard:pbytea;var hard_pos:integer);
begin
 move(pck[0],hard[hard_pos+4],hard_frame_len-4);
 pdword(@hard[hard_pos])^:=$1DFCCF1A;

 hard_pos:=hard_pos+hard_frame_len;
end;
//############################################################################//
procedure do_one_conv(var m:mtd_rec;hard:pbytea;var hard_pos:integer;conv_mode:integer);
begin
 if conv_mode=CONV_HARD then recreate_packet(m,@m.ecced_data[0],@hard[0],hard_pos);
 if conv_mode=CONV_DEC  then dump_packet(@m.ecced_data[0],@hard[0],hard_pos);
end;
//############################################################################//
procedure do_one_frame(var m:mtd_rec;dt_proc:integer;var stat_proc:int64);
begin
 stdt(dt_proc);
 parse_cvcdu(@m.ecced_data[0],hard_frame_len-4-128);
 stat_proc:=stat_proc+rtdt(dt_proc);
end;
//############################################################################//
//Exact order does not matter, it's not used anywhere else.
function byte_at_off(data:pbytea):byte;
var b:integer;
begin
 result:=0;
 for b:=0 to 7 do result:=result or (ord((data[b])<128) shl b);
end;
//############################################################################//
//The sync word could be in any of 8 different orientations,
//so we will just look for a repeating bit pattern the right distance apart
function find_sync(data:pbytea;sz,step,depth:integer;out off:integer;out sync:byte):boolean;
var i,j:integer;
begin
 result:=false;
 off:=0;
 for i:=0 to sz-1-step*depth do begin
  sync:=byte_at_off(@data[i]);
  result:=true;
  for j:=1 to depth do if sync<>byte_at_off(@data[i+j*step]) then begin result:=false;break;end;
  if result then begin off:=i; exit;end;
 end;
end;
//############################################################################//
//80k stream: 00100111 36 bits 36 bits 00100111 36 bits 36 bits 00100111 ...
procedure resync_stream(raw:pbytea;raw_sz:integer;out sz:integer);
var src:array of byte;
pos,i,off:integer;
sync:byte;
ok:boolean;
begin
 setlength(src,raw_sz);
 move(raw[0],src[0],raw_sz);

 sz:=0;
 pos:=0;
 while pos<raw_sz-80*4 do begin
  if not find_sync(@src[pos],80*5,80,4,off,sync) then begin
   pos:=pos+80*3;
   continue;
  end;
  if not quiet then begin
   if ansi then write(ansi_back_to_start);
   write(' (',(pos/raw_sz)*100:6:2,'%) sync: Found sync at ',pos,' ',sync);
   if not ansi then writeln;
  end;

  pos:=pos+off;
  while pos<raw_sz-80 do begin
   //Look ahead to prevent it losing sync on weak signal
   ok:=false;
   for i:=0 to 127 do if pos+i*80<raw_sz-80 then if byte_at_off(@src[pos+i*80])=sync then begin ok:=true;break;end;
   if not ok then break;

   move(src[pos+8],raw[sz],72);
   pos:=pos+80;
   sz:=sz+72;
  end;
  if not quiet then begin
   if ansi then write(ansi_back_to_start);
   write(' (',(pos/raw_sz)*100:6:2,'%) sync: Lost sync at ',pos);
   if not ansi then writeln;
  end;
 end;

 if not quiet then begin
  if ansi then writeln;
  writeln('sync: ',sz,' / ',raw_sz*72 div 80);
 end;
end;
//############################################################################//
// https://en.wikipedia.org/wiki/Burst_error-correcting_code#Convolutional_interleaver
procedure deint_block(src,dst:pbytea;sz:integer);
var i,pos:integer;
begin
 for i:=0 to sz-1 do begin
  pos:=i+(inter_branches-1)*inter_delay-(i mod inter_branches)*inter_base_len;
  //Offset it by half a message, to capture both leading and trailing fuzz
  pos:=pos+(inter_branches div 2)*inter_base_len;
  if (pos>=0)and(pos<sz) then dst[pos]:=src[i];
 end;
end;
//############################################################################//
procedure deinterleave(raw:pbytea;raw_sz:integer;out sz:integer);
var src:array of byte;
begin
 resync_stream(raw,raw_sz,sz);

 setlength(src,sz);
 move(raw[0],src[0],sz);
 fillchar(raw[0],sz,0);

 deint_block(@src[0],@raw[0],sz);
end;
//############################################################################//
function mean(const cur,prev:integer):integer;
var v:integer;
begin
 result:=0;
 v:=cur*prev;
 if (v>32768)or(v<-32768) then exit;
 if v>=0 then result:=isqrt_tab[v] else result:=-isqrt_tab[-v];
end;
//############################################################################//
procedure de_diffcode(raw:pshortinta;sz:integer);
var i,pa,pb,a,b:integer;
begin
 if sz<2 then exit;

 //Using a lookup table due to a lack of integer sqrt.
 //Should preserve the sanity of FPU-less devices.
 for i:=0 to 32768 do isqrt_tab[i]:=round(sqrt(i));

 pa:=raw[0];
 pb:=raw[1];
 raw[0]:=0;
 raw[1]:=0;
 for i:=1 to sz div 2-1 do begin
  a:=raw[i*2+0];
  b:=raw[i*2+1];
  raw[i*2+0]:=mean( a,pa);
  raw[i*2+1]:=mean(-b,pb);
  pa:=a;
  pb:=b;
 end;
end;
//############################################################################//
procedure process_file(fn,out_name:string;inp_mode,conv_mode:integer;deint,dediff:boolean);
var f:file;
sz,hard_pos:integer;
hard,raw:array of byte;
m:mtd_rec;
ok:boolean;
dt_total,dt_proc:integer;
stat_proc,stat_total:int64;
ok_cnt,total_cnt:integer;
begin
 mj_init;
 mtd_init(m);

 assignfile(f,fn);
 reset(f,1);
 sz:=filesize(f);
 if not quiet then writeln('Reading '+fn+'...');
 if inp_mode=INP_HARD then begin
  setlength(hard,sz);
  blockread(f,hard[0],sz);

  if not quiet then writeln('Parsing hard file...');
  setlength(raw,sz*8);
  hard_to_soft(@hard[0],@raw[0],sz);
  setlength(hard,0);
  sz:=sz*8;
 end else if inp_mode=INP_SOFT then begin
  setlength(raw,sz);
  blockread(f,raw[0],sz);
 end else if inp_mode=INP_DEC then begin
  setlength(raw,sz);
  blockread(f,raw[0],sz);
 end else exit;
 closefile(f);

 dt_total:=getdt;
 dt_proc:=getdt;
 stat_corr:=0;
 stat_vit:=0;
 stat_ecc:=0;
 stat_proc:=0;
 ok_cnt:=0;
 total_cnt:=0;

 if conv_mode<>CONV_NONE then begin
  if inp_mode=INP_DEC then setlength(hard,3*sz*8) else setlength(hard,sz);
  hard_pos:=0;
 end;

 m.pos:=0;
 stdt(dt_total);
 if inp_mode=INP_DEC then begin
  while m.pos<=sz-hard_frame_len do begin
   if pdword(@raw[m.pos])^<>$1DFCCF1A then begin
    writeln('Decoded file format error');
    exit;
   end;
   if not quiet then write(' pos=',m.pos:8,' (',(m.pos/sz)*100:6:2,'%) ');
   if not quiet and md_debug then writeln;

   move(raw[m.pos+4],m.ecced_data[0],hard_frame_len-4);
   m.pos:=m.pos+hard_frame_len;
   do_one_conv(m,@hard[0],hard_pos,conv_mode);
   do_one_frame(m,dt_proc,stat_proc);
   ok_cnt:=ok_cnt+1;
   total_cnt:=total_cnt+1;

   if not quiet and not md_debug then writeln;
  end;
 end else begin
  if deint then begin
   if not quiet then writeln('Deinterleaving...');
   deinterleave(@raw[0],sz,sz);
  end;
  if dediff then begin
   if not quiet then writeln('Dediffing...');
   de_diffcode(@raw[0],sz);
  end;
  while m.pos<sz-soft_frame_len do begin
   ok:=mtd_one_frame(m,@raw[0]);
   if ok then begin
    if not quiet then begin
     if ansi then write(ansi_back_to_start);
     write(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync),' ');
     if md_debug and not ansi then writeln;
    end;

    do_one_conv(m,@hard[0],hard_pos,conv_mode);
    do_one_frame(m,dt_proc,stat_proc);
    ok_cnt:=ok_cnt+1;

    if not quiet and not md_debug and not ansi then writeln;
   end else begin
    if not quiet then begin
     if ansi then write(ansi_back_to_start);
     write(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync),' ');
     if not ansi then writeln;
    end;
   end;
   total_cnt:=total_cnt+1;
  end;
 end;
 if not quiet and ansi then writeln;

 stat_total:=rtdt(dt_total);

 if print_stats then begin
  writeln('Total:        ',stat_total/1e6:6:6);
  writeln('Processing:   ',stat_proc/1e6:6:6);
  writeln('Correlation:  ',stat_corr/1e6:6:6);
  writeln('Viterbi:      ',stat_vit/1e6:6:6);
  writeln('ECC:          ',stat_ecc/1e6:6:6);
  writeln('Remainder:    ',(stat_total-stat_ecc-stat_vit-stat_corr-stat_proc)/1e6:6:6);
  writeln('Packets:      ',ok_cnt,' / ',total_cnt);
 end;

 print_times(out_name);

 freedt(dt_total);
 freedt(dt_proc);

 mj_dump_image(out_name);

 if (conv_mode=CONV_HARD) and (hard_pos<>0) then begin
  assignfile(f,out_name+'.hard');
  rewrite(f,1);
  blockwrite(f,hard[0],hard_pos);
  closefile(f);
 end;
 if (conv_mode=CONV_DEC) and (hard_pos<>0) then begin
  assignfile(f,out_name+'.dec');
  rewrite(f,1);
  blockwrite(f,hard[0],hard_pos);
  closefile(f);
 end;
end;
//############################################################################//
procedure set_apid(n:integer;var i:integer);
var k:integer;
begin
 if paramcount<i+1 then begin writeln('Missing apid parameter!');halt;end;
 k:=vali(paramstr(i+1));
 case n of
  0:red_apid:=k;
  1:green_apid:=k;
  2:blue_apid:=k;
 end;
 i:=i+1;
end;
//############################################################################//
procedure main;
var inp,outp,s:string;
i,inp_mode,conv_mode:integer;
deint,dediff:boolean;
begin
 deint:=false;
 dediff:=false;
 inp_mode:=INP_SOFT;
 conv_mode:=CONV_NONE;
 {$ifdef mswindows}ansi:=false;{$endif}
 if paramcount<2 then begin
  writeln('medet input_file output_name [OPTIONS]');
  writeln;
  writeln('Version 20190825-0');
  writeln('Expects 8 bit signed soft samples, 1 bit hard samples or decoded dump input');
  writeln('Image would be written to output_name.bmp');
  writeln;
  writeln('Input:');
  writeln(' -soft      Use 8 bit soft samples (default)');
  writeln(' -h -hard   Use hard samples');
  writeln(' -d -dump   Use decoded dump');
  writeln;
  writeln('Process:');
  writeln(' -int       Deinterleave (for 80k signal, i.e. Meteor M2-2, default - 72k)');
  writeln(' -diff      Diff coding (for Meteor M2-2)');
  writeln;
  writeln('Output:');
  writeln(' -ch        Make hard samples (as decoded)');
  writeln(' -cd        Make decoded dump');
  writeln(' -cn        Make image (default)');
  writeln(' -r x       APID for red   (default: ',red_apid,')');
  writeln(' -g x       APID for green (default: ',green_apid,')');
  writeln(' -b x       APID for blue  (default: ',blue_apid,')');
  writeln(' -s         Split image by channels');
  writeln(' -S         Both split image by channels, and output composite');
  writeln(' -t         Write stat file with time information');
  writeln;
  writeln('Print:');
  writeln(' -q         Don''t print verbose info');
  writeln(' -Q         Don''t print anything');
  writeln(' -p         Print loads of debug info');
  {$ifndef mswindows}writeln(' -na        Don''t compress the debug output to a single line');{$endif}
  writeln;
  writeln('As of August 2019, N2 and N2-2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 66 (10.5-11.5)');
  writeln('As of March 2017, N2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 68 (10.5-11.5)');
  writeln('Defaults produce 125 image compatible with many tools');
  writeln('Nice false color image is produced with -r 65 -g 65 -b 64');
  writeln('Decoded dump is 9 times smaller than the raw signal, and can be re-decoded 20x as fast, so it''s a good format to store images and play with channels');
  writeln;


  {$ifdef win32}readln;{$endif}
  {$ifdef win64}readln;{$endif}
  exit;
 end;

 if paramcount>2 then begin
  i:=3;
  while i<=paramcount do begin
   s:=paramstr(i);
        if s='-int' then deint:=true
   else if s='-diff' then dediff:=true

   else if (s='-h')or(s='-hard') then inp_mode:=INP_HARD
   else if s='-soft' then inp_mode:=INP_SOFT
   else if s='-d' then inp_mode:=INP_DEC

   else if s='-ch' then conv_mode:=CONV_HARD
   else if s='-cd' then conv_mode:=CONV_DEC
   else if s='-cn' then conv_mode:=CONV_NONE
   else if s='-r' then set_apid(0,i)
   else if s='-g' then set_apid(1,i)
   else if s='-b' then set_apid(2,i)
   else if s='-s' then output_mode:=OUT_SPLIT
   else if s='-S' then output_mode:=OUT_BOTH
   else if s='-t' then time_file:=true

   else if s='-p' then md_debug:=true
   else if s='-q' then quiet:=true
   else if s='-Q' then begin quiet:=true; print_stats:=false;end
   else if s='-na' then ansi:=false;
   i:=i+1;
  end;
 end;

 inp:=paramstr(1);
 outp:=paramstr(2);

 if not fileexists(inp) then begin
  writeln('Input file "',inp,'" not found!');
  exit;
 end;

 process_file(inp,outp,inp_mode,conv_mode,deint,dediff);
end;
//############################################################################//
begin
 main;
end.
//############################################################################//

