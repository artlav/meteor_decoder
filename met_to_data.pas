//############################################################################//
//Made in 2017 by Artyom Litvinovich
//medet: Convert soft QPSK to real data
//############################################################################//
unit met_to_data;
interface
uses asys,ecc,correlator,viterbi27,bitop,tim;
//############################################################################//
const
hard_frame_len=1024;
frame_bits=hard_frame_len*8;
soft_frame_len=frame_bits*2;
min_correlation=45;

prand:array[0..254]of byte=(
 $ff, $48, $0e, $c0, $9a, $0d, $70, $bc,
 $8e, $2c, $93, $ad, $a7, $b7, $46, $ce,
 $5a, $97, $7d, $cc, $32, $a2, $bf, $3e,
 $0a, $10, $f1, $88, $94, $cd, $ea, $b1,
 $fe, $90, $1d, $81, $34, $1a, $e1, $79,
 $1c, $59, $27, $5b, $4f, $6e, $8d, $9c,
 $b5, $2e, $fb, $98, $65, $45, $7e, $7c,
 $14, $21, $e3, $11, $29, $9b, $d5, $63,
 $fd, $20, $3b, $02, $68, $35, $c2, $f2,
 $38, $b2, $4e, $b6, $9e, $dd, $1b, $39,
 $6a, $5d, $f7, $30, $ca, $8a, $fc, $f8,
 $28, $43, $c6, $22, $53, $37, $aa, $c7,
 $fa, $40, $76, $04, $d0, $6b, $85, $e4,
 $71, $64, $9d, $6d, $3d, $ba, $36, $72,
 $d4, $bb, $ee, $61, $95, $15, $f9, $f0,
 $50, $87, $8c, $44, $a6, $6f, $55, $8f,
 $f4, $80, $ec, $09, $a0, $d7, $0b, $c8,
 $e2, $c9, $3a, $da, $7b, $74, $6c, $e5,
 $a9, $77, $dc, $c3, $2a, $2b, $f3, $e0,
 $a1, $0f, $18, $89, $4c, $de, $ab, $1f,
 $e9, $01, $d8, $13, $41, $ae, $17, $91,
 $c5, $92, $75, $b4, $f6, $e8, $d9, $cb,
 $52, $ef, $b9, $86, $54, $57, $e7, $c1,
 $42, $1e, $31, $12, $99, $bd, $56, $3f,
 $d2, $03, $b0, $26, $83, $5c, $2f, $23,
 $8b, $24, $eb, $69, $ed, $d1, $b3, $96,
 $a5, $df, $73, $0c, $a8, $af, $cf, $82,
 $84, $3c, $62, $25, $33, $7a, $ac, $7f,
 $a4, $07, $60, $4d, $06, $b8, $5e, $47,
 $16, $49, $d6, $d3, $db, $a3, $67, $2d,
 $4b, $be, $e6, $19, $51, $5f, $9f, $05,
 $08, $78, $c4, $4a, $66, $f5, $58
);
//############################################################################//
type mtd_rec=record
 c:corr_rec;
 v:viterbi27_rec;

 pos,prev_pos:integer;
 ecced_data:array[0..hard_frame_len-1]of byte;
            
 word,cpos,corr,last_sync:dword;
 r:array[0..3]of integer;
 sig_q:integer;
end;
//############################################################################//
procedure mtd_init(out m:mtd_rec);
function mtd_one_frame(var m:mtd_rec;raw:pbytea):boolean;
//############################################################################//
var dt_data:integer;
stat_corr:int64=0;
stat_vit:int64=0;
stat_ecc:int64=0;
//############################################################################//
implementation
//############################################################################//
procedure mtd_init(out m:mtd_rec);
begin
 corr_init(m.c,qword($fca2b63db00d9794));   //sync is $1ACFFC1D,  00011010 11001111 11111100 00011101
 mk_viterbi27(m.v);
 m.pos:=0;
 m.cpos:=0;
 m.word:=0;
end;
//############################################################################//
procedure do_full_correlate(var m:mtd_rec;raw,aligned:pbytea);
begin
 m.word:=corr_correlate(m.c,@raw[m.pos],soft_frame_len);

 m.cpos:=m.c.position[m.word];
 m.corr:=m.c.correlation[m.word];

 if m.corr<min_correlation then begin
  m.prev_pos:=m.pos;
  writeln('Not even ',min_correlation,' bits found!.');
  move(raw[m.pos],aligned[0],soft_frame_len);
  m.pos:=m.pos+soft_frame_len div 4;
 end else begin
  m.prev_pos:=m.pos+m.cpos;

  move(raw[m.pos+m.cpos],aligned[0],soft_frame_len-m.cpos);
  move(raw[m.pos+soft_frame_len],aligned[soft_frame_len-m.cpos],m.cpos);
  m.pos:=m.pos+soft_frame_len+m.cpos;

  fix_packet(@aligned[0],soft_frame_len,m.word);
 end;
end; 
//############################################################################//
procedure do_next_correlate(var m:mtd_rec;raw,aligned:pbytea);
begin
 m.cpos:=0;
 move(raw[m.pos],aligned[0],soft_frame_len);
 m.prev_pos:=m.pos;
 m.pos:=m.pos+soft_frame_len;

 fix_packet(@aligned[0],soft_frame_len,m.word);
end;
//############################################################################//
function try_frame(var m:mtd_rec;aligned:pbytea):boolean;  
var j:integer;
decoded:array[0..hard_frame_len-1]of byte;
ecc_buf:array[0..255-1]of byte;
begin 
 stdt(dt_data);
 vit_decode(m.v,aligned,@decoded[0]);  
 stat_vit:=stat_vit+rtdt(dt_data);

 m.last_sync:=pdword(@decoded[0])^;
 m.sig_q:=round(100-(vit_get_percent_BER(m.v)*10));

 //Curiously enough, you can flip all bits in a packet and get a correct ECC anyway.
 //Check for that case
 if count_bits(m.last_sync xor $E20330E5)<count_bits(m.last_sync xor $1DFCCF1A) then begin
  for j:=0 to hard_frame_len-1 do decoded[j]:=decoded[j] xor $FFFFFFFF;
  m.last_sync:=pdword(@decoded[0])^;
 end;

 stdt(dt_data);
 for j:=0 to hard_frame_len-4-1 do decoded[4+j]:=decoded[4+j] xor prand[j mod 255];
 for j:=0 to 3 do begin
  ecc_deinterleave(@decoded[4],@ecc_buf[0],j,4);
  m.r[j]:=ecc_decode(@ecc_buf[0],0);
  ecc_interleave(@ecc_buf[0],@m.ecced_data[0],j,4);
 end;
 stat_ecc:=stat_ecc+rtdt(dt_data);

 result:=(m.r[0]<>-1)and(m.r[1]<>-1)and(m.r[2]<>-1)and(m.r[3]<>-1);
end;
//############################################################################//
function mtd_one_frame(var m:mtd_rec;raw:pbytea):boolean;
var aligned:array[0..soft_frame_len-1]of byte;
begin
 result:=false;

 if m.cpos=0 then begin      
  stdt(dt_data);
  do_next_correlate(m,raw,@aligned[0]); 
  stat_corr:=stat_corr+rtdt(dt_data);

  result:=try_frame(m,@aligned[0]);
  {
  if not result then begin
   hard_packet(@aligned[0],soft_frame_len);
   result:=try_frame(m,@aligned[0]);
  end;
  }
  if not result then m.pos:=m.pos-soft_frame_len;
 end;

 if not result then begin
  stdt(dt_data);
  do_full_correlate(m,raw,@aligned[0]);
  stat_corr:=stat_corr+rtdt(dt_data);

  result:=try_frame(m,@aligned[0]);
 end;
end; 
//############################################################################//
begin
 dt_data:=getdt;
end.     
//############################################################################//


