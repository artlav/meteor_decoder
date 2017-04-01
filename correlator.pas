//############################################################################//
//Made in 2017 by Artyom Litvinovich
//medet: Find a pattern i the soft samples
//############################################################################//
unit correlator;
interface
uses asys;
//############################################################################//
const
pattern_size=64;
pattern_cnt=8;
corr_limit=55;
//############################################################################//
type
corr_rec=record
 patts:array[0..pattern_size-1]of array[0..pattern_cnt-1]of byte;
 correlation,tmp_corr,position:array[0..pattern_cnt-1]of integer;
end;      
//############################################################################//
procedure fix_packet(data:pointer;len:integer;shift:integer);  
procedure hard_packet(data:pointer;len:integer);

procedure soft_to_hard(input,output:pointer;soft_len:integer);
procedure hard_to_soft(input,output:pointer;hard_len:integer);

function hard_correlate(const d,w:byte):integer;
function corr_correlate(var c:corr_rec;data:pbytea;len:dword):integer; 
procedure corr_init(out c:corr_rec;q:qword);
//############################################################################//
implementation
//############################################################################//
var
rotate_iq_tab:array[0..255]of byte;
invert_iq_tab:array[0..255]of byte;
corr_tab:array[0..255]of array[0..255]of integer;
//############################################################################//
function hard_correlate(const d,w:byte):integer;begin result:=corr_tab[d][w];end;
//############################################################################//
procedure init_corr_tables;
var i,j:integer;
begin
 for i:=0 to 255 do begin
  rotate_iq_tab[i]:=(((i and $55) xor $55) shl 1) or ((i and $AA) shr 1);
  invert_iq_tab[i]:=( (i and $55)          shl 1) or ((i and $AA) shr 1);
  for j:=0 to 255 do corr_tab[i][j]:=ord(((i>127) and (j=0)) or ((i<=127) and (j=255))); //Correlation between a soft sample i and a hard value j
 end;
end;
//############################################################################//
//1=90, 2=180, ...
function rotate_iq(data:byte;shift:integer):byte;
begin
 result:=data;
 if (shift=1)or(shift=3) then result:=rotate_iq_tab[result];
 if (shift=2)or(shift=3) then result:=result xor $FF;
end;
//############################################################################//
function rotate_iq_qw(data:qword;shift:integer):qword;
var i:integer;
begin
 for i:=0 to pattern_cnt-1 do pbytea(@result)[i]:=rotate_iq(pbytea(@data)[i],shift);
end;
//############################################################################//
function flip_iq_qw(data:qword):qword;
var i:integer;
begin
 for i:=0 to pattern_cnt-1 do pbytea(@result)[i]:=invert_iq_tab[pbytea(@data)[i]];
end;
//############################################################################//
procedure fix_packet(data:pointer;len:integer;shift:integer);
var j:integer;
d:pshortinta;
b:shortint;
begin
 d:=data;
 case shift of
  4:for j:=0 to len div 2-1 do begin
   b:=d[j*2+0];
   d[j*2+0]:=d[j*2+1];
   d[j*2+1]:=b;
  end;
  5:for j:=0 to len div 2-1 do begin
   d[j*2+0]:=-d[j*2+0];
   d[j*2+1]:= d[j*2+1];
  end;
  6:for j:=0 to len div 2-1 do begin
   b:=d[j*2+0];
   d[j*2+0]:=-d[j*2+1];
   d[j*2+1]:=-b;
  end;
  7:for j:=0 to len div 2-1 do begin
   d[j*2+0]:= d[j*2+0];
   d[j*2+1]:=-d[j*2+1];
  end;
 end;
end;
//############################################################################//
procedure hard_packet(data:pointer;len:integer);
var i:integer;
d:pbytea;
begin
 d:=data;
 for i:=0 to len-1 do case d[i] of
  0..127:d[i]:=127;
  else d[i]:=128;
 end;
end;
//############################################################################//
procedure soft_to_hard(input,output:pointer;soft_len:integer);
var i,bit_pos,pos:integer;
s:pshortinta;
h:pbytea;
x,y:shortint;
b,hb:byte;
begin
 s:=input;
 h:=output;

 bit_pos:=0;
 pos:=0;
 b:=0;
 for i:=0 to soft_len div 2-1 do begin
  x:=s[i*2+0];
  y:=s[i*2+1];
  hb:=0;
  if x>=0 then hb:=hb+2;
  if y>=0 then hb:=hb+1;

  b:=(b shl 2) or hb;
  bit_pos:=bit_pos+1;
  if bit_pos=4 then begin
   h[pos]:=b;
   pos:=pos+1;
   bit_pos:=0;
  end;
 end;
end;
//############################################################################//
procedure hard_to_soft(input,output:pointer;hard_len:integer);
var s:pshortinta;
h:pbytea;
i,j,k:integer;
begin
 h:=input;
 s:=output;
 for i:=0 to hard_len-1 do for j:=0 to 7 do begin
  k:=(h[i] shr (7-j)) and 1;
  if k=1 then s[i*8+j]:=127 else s[i*8+j]:=-127;
 end;
end;
//############################################################################//
procedure corr_set_patt(var c:corr_rec;n:integer;p:qword);
var i:integer;
begin
 for i:=0 to pattern_size-1 do if ((p shr (pattern_size-i-1)) and 1)<>0 then c.patts[i][n]:=$FF else c.patts[i][n]:=0;
end;
//############################################################################//
procedure corr_init(out c:corr_rec;q:qword);
var i:integer;
begin
 fillchar(c.correlation[0],pattern_cnt*4,0);
 fillchar(c.position[0],   pattern_cnt*4,0);
 fillchar(c.tmp_corr[0],   pattern_cnt*4,0);
 for i:=0 to 3 do corr_set_patt(c,i  ,rotate_iq_qw(q,i));
 for i:=0 to 3 do corr_set_patt(c,i+4,rotate_iq_qw(flip_iq_qw(q),i));
end;
//############################################################################//
procedure corr_reset(var c:corr_rec);
begin
 fillchar(c.correlation[0],pattern_cnt*4,0);
 fillchar(c.position[0],   pattern_cnt*4,0);
 fillchar(c.tmp_corr[0],   pattern_cnt*4,0);
end;
//############################################################################//
function corr_correlate(var c:corr_rec;data:pbytea;len:dword):integer;
var i,n,k:integer;
d:pinta;
p:pbytea;
begin
 result:=-1;
 corr_reset(c);

 for i:=0 to len-pattern_size-1 do begin
  for n:=0 to pattern_cnt-1 do c.tmp_corr[n]:=0;
  for k:=0 to pattern_size-1 do begin
   d:=@corr_tab[data[i+k]][0];
   p:=@c.patts[k][0];
   //Unrolled to pattern_cnt times
   c.tmp_corr[0]:=c.tmp_corr[0]+d[p[0]];
   c.tmp_corr[1]:=c.tmp_corr[1]+d[p[1]];
   c.tmp_corr[2]:=c.tmp_corr[2]+d[p[2]];
   c.tmp_corr[3]:=c.tmp_corr[3]+d[p[3]];
   c.tmp_corr[4]:=c.tmp_corr[4]+d[p[4]];
   c.tmp_corr[5]:=c.tmp_corr[5]+d[p[5]];
   c.tmp_corr[6]:=c.tmp_corr[6]+d[p[6]];
   c.tmp_corr[7]:=c.tmp_corr[7]+d[p[7]];
  end;

  for n:=0 to pattern_cnt-1 do if c.tmp_corr[n]>c.correlation[n] then begin
   c.correlation[n]:=c.tmp_corr[n];
   c.position[n]:=i;
   c.tmp_corr[n]:=0;
   if c.correlation[n]>corr_limit then begin result:=n;exit;end;
  end;
 end;

 k:=0;
 for i:=0 to pattern_cnt-1 do if c.correlation[i]>k then begin result:=i;k:=c.correlation[i];end;
end;
//############################################################################//
begin
 init_corr_tables;
end.
//############################################################################//

