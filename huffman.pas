//############################################################################//
//Made in 2017 by Artyom Litvinovich
//Naive huffman decoder
//############################################################################//
unit huffman;
interface
uses asys;
//############################################################################//
const
dc_cat_off:array[0..11]of integer=(2,3,3,3,3,3,4,5,6,7,8,9);
//############################################################################//
type ac_table_rec=record
 run,size,len:integer;
 mask,code:dword;
end;
//############################################################################//
var ac_table:array of ac_table_rec;
//############################################################################//
function get_dc(const w:word):integer;
function get_ac(const w:word):integer;
function map_range(const cat,vl:integer):integer;
procedure default_huffman_table;
//############################################################################//
implementation
//############################################################################//
var ac_lookup,dc_lookup:array[0..65535]of integer;
//############################################################################//
const
t_ac_0:array[0..16+162-1]of byte=(
 0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,125,
 1,2,3,0,4,17,5,18,33,49,65,6,19,81,97,7,34,113,20,50,129,145,161,8,35,66,177,193,
 21,82,209,240,36,51,98,114,130,9,10,22,23,24,25,26,37,38,39,40,41,42,52,53,54,55,
 56,57,58,67,68,69,70,71,72,73,74,83,84,85,86,87,88,89,90,99,100,101,102,103,104,
 105,106,115,116,117,118,119,120,121,122,131,132,133,134,135,136,137,138,146,147,
 148,149,150,151,152,153,154,162,163,164,165,166,167,168,169,170,178,179,180,181,
 182,183,184,185,186,194,195,196,197,198,199,200,201,202,210,211,212,213,214,215,
 216,217,218,225,226,227,228,229,230,231,232,233,234,241,242,243,244,245,246,247,
 248,249,250
);
//############################################################################//
function get_ac(const w:word):integer;begin result:=ac_lookup[w];end;
function get_dc(const w:word):integer;begin result:=dc_lookup[w];end;
//############################################################################//
function get_ac_real(const w:word):integer;
var i:integer;
begin
 result:=-1;
 for i:=0 to length(ac_table)-1 do begin
  if ((w shr (16-ac_table[i].len))and ac_table[i].mask)=ac_table[i].code then begin result:=i;exit;end;
 end;
end;
//############################################################################//
function get_dc_real(const w:word):integer;
begin
 result:=-1;
 case w shr 14 of
  0:begin result:=0;exit;end;
  else case w shr 13 of
   2:begin result:=1;exit;end;
   3:begin result:=2;exit;end;
   4:begin result:=3;exit;end;
   5:begin result:=4;exit;end;
   6:begin result:=5;exit;end;
   else begin
         if (w shr 12)=$00E then begin result:=6;exit;end
    else if (w shr 11)=$01E then begin result:=7;exit;end
    else if (w shr 10)=$03E then begin result:=8;exit;end
    else if (w shr  9)=$07E then begin result:=9;exit;end
    else if (w shr  8)=$0FE then begin result:=10;exit;end
    else if (w shr  7)=$1FE then begin result:=11;exit;end
    else exit;
   end;
  end;
 end;
end;
//############################################################################//
function map_range(const cat,vl:integer):integer;
var maxval:integer;
sig:boolean;
begin
 maxval:=(1 shl cat)-1;
 sig:=(vl shr (cat-1))<>0;
 if sig then result:=vl else result:=vl-maxval;
end;
//############################################################################//
procedure default_huffman_table;
var k,i,n:integer;
code:dword;
t:pbytea;
p:integer;
v:array[0..65535]of byte;
min_code,maj_code:array[0..16]of word;
max_val,min_val,size_val:word;
min_valn,max_valn,run,size:integer;
begin
 t:=@t_ac_0[0];

 p:=16;
 for k:=1 to 16 do for i:=0 to t[k-1]-1 do begin
  v[(k shl 8)+i]:=t[p];
  p:=p+1;
 end;

 code:=0;
 for k:=1 to 16 do begin
  min_code[k]:=code;
  for i:=1 to t[k-1] do inc(code);
  maj_code[k]:=code-dword(1*ord(code<>0));
  code:=code*2;
  if t[k-1]=0 then begin
   min_code[k]:=$FFFF;
   maj_code[k]:=0;
  end;
 end;

 setlength(ac_table,256);
 n:=0;

 min_valn:=1;
 max_valn:=1;
 min_val:=min_code[min_valn];
 max_val:=maj_code[max_valn];
 for k:=1 to 16 do begin
  for i:=0 to (1 shl k)-1 do begin
   if (i<=max_val)and(i>=min_val) then begin
    size_val:=v[(k shl 8)+i-min_val];
    run:=size_val shr 4;
    size:=size_val and $F;
    ac_table[n].run:=run;
    ac_table[n].size:=size;
    ac_table[n].len:=k;
    ac_table[n].mask:=(1 shl k)-1;
    ac_table[n].code:=i;
    n:=n+1;
    //writeln(run:2,' ',size:3,' ',k:2,' $',strhex4((1 shl k)-1),' $',strhex4(i),' %',strbin4(i));
   end;
  end;
  min_valn:=min_valn+1;
  max_valn:=max_valn+1;
  min_val:=min_code[min_valn];
  max_val:=maj_code[max_valn];
 end;

 setlength(ac_table,n);

 for i:=0 to 65535 do ac_lookup[i]:=get_ac_real(i);
 for i:=0 to 65535 do dc_lookup[i]:=get_dc_real(i);
end;
//############################################################################//
begin
end.
//############################################################################//

