//############################################################################//
//Made in 2017 by Artyom Litvinovich
//medet: extract MCUs and do the JPG
//############################################################################//
unit met_jpg;
interface
uses asys,bitop,bmp,huffman,dct;
//############################################################################//  
procedure mj_dump_image(fn:string);
procedure mj_dec_mcus(p:pbytea;len:integer;apd,pck_cnt,mcu_id:integer;q:byte);    
procedure mj_init;
//############################################################################//
const
OUT_COMBO=1;
OUT_SPLIT=2;
OUT_BOTH =OUT_COMBO or OUT_SPLIT;
//############################################################################//
var
red_apid:integer=68;
green_apid:integer=65;
blue_apid:integer=64;
output_mode:integer=OUT_COMBO;
//############################################################################//
implementation  
//############################################################################//
const
mcu_per_packet=14;
mcu_per_line=196;
//############################################################################//
standard_quantization_table:array[0..63]of byte=(
	16,  11,  10,  16,  24,  40,  51,  61,
	12,  12,  14,  19,  26,  58,  60,  55,
	14,  13,  16,  24,  40,  57,  69,  56,
	14,  17,  22,  29,  51,  87,  80,  62,
	18,  22,  37,  56,  68, 109, 103,  77,
	24,  35,  55,  64,  81, 104, 113,  92,
	49,  64,  78,  87, 103, 121, 120, 101,
	72,  92,  95,  98, 112, 100, 103,  99
);

zigzag:array[0..63]of byte=(
  0, 1, 5, 6,14,15,27,28,
  2, 4, 7,13,16,26,29,42,
  3, 8,12,17,25,30,41,43,
  9,11,18,24,31,40,44,53,
 10,19,23,32,39,45,52,54,
 20,22,33,38,46,51,55,60,
 21,34,37,47,50,56,59,61,
 35,36,48,49,57,58,62,63
);
//############################################################################//
var big_img:array of crgba;
last_mcu:integer=-1;
cur_y:integer=0;
last_y:integer=-1;
first_pck:integer=0;
prev_pck:integer=0;
//############################################################################//
procedure mj_dump_image(fn:string);
var small_img:array of byte;
i,j:integer;
pal:pallette;
begin
 if length(big_img)=0 then exit;

 if (output_mode and OUT_SPLIT)<>0 then begin
  for i:=0 to 255 do begin
   pal[i][0]:=i;
   pal[i][1]:=i;
   pal[i][2]:=i;
   pal[i][3]:=255;
  end;

  setlength(small_img,length(big_img));
  for j:=0 to 2 do begin
   for i:=0 to length(small_img)-1 do small_img[i]:=big_img[i][j];
   storebmp8(fn+'_'+stri(j)+'.bmp',@small_img[0],8*mcu_per_line,cur_y+8,true,false,pal);
  end;
 end;

 if (output_mode and OUT_COMBO)<>0 then storebmp32(fn+'.bmp',@big_img[0],8*mcu_per_line,cur_y+8,true,false);
end;
//############################################################################//
procedure fill_dqt_by_q(const dqt:pinta;q:integer);   
var f:single;
i:integer;
begin
 if (q>20)and(q<50) then f:=5000/q else f:=200-2*q;
	for i:=0 to 63 do begin
  dqt[i]:=round(f/100*standard_quantization_table[i]);
  if dqt[i]<1 then dqt[i]:=1;
 end;
end;
//############################################################################//
procedure fill_pix(img_dct:psinglea;apd,mcu_id,m:integer);
var i,t,x,y,off:integer;
begin
 for i:=0 to 63 do begin
  t:=round(img_dct[i]+128);
  if t<0 then t:=0;
  if t>255 then t:=255;
  x:=(mcu_id+m)*8+i mod 8;
  y:=cur_y+i div 8;
  off:=x+y*mcu_per_line*8;

  if apd=red_apid   then big_img[off][CLRED]:=t;
  if apd=green_apid then big_img[off][CLGREEN]:=t;
  if apd=blue_apid  then big_img[off][CLBLUE]:=t;
 end;
end;
//############################################################################//
function progress_image(apd,mcu_id,pck_cnt:integer):boolean;
begin
 result:=false;

 if apd=0 then exit;
 if apd=70 then exit;

 if last_mcu=-1 then begin
  if mcu_id<>0 then exit;
  prev_pck:=pck_cnt;
  first_pck:=pck_cnt;
  if apd=65 then first_pck:=first_pck-14;
  if apd=66 then first_pck:=first_pck-2*14;
  if apd=68 then first_pck:=first_pck-2*14;
  last_mcu:=0;
  cur_y:=-1;
 end;

 if pck_cnt<prev_pck then first_pck:=first_pck-16384;
 prev_pck:=pck_cnt;

 cur_y:=8*((pck_cnt-first_pck) div (14+14+14+1));
 if cur_y>last_y then setlength(big_img,(mcu_per_line*8)*(cur_y+8));
 last_y:=cur_y;

 result:=true;
end;
//############################################################################//
procedure mj_dec_mcus(p:pbytea;len:integer;apd,pck_cnt,mcu_id:integer;q:byte);
var b:bit_io_rec;
i,m:integer;
k,n:word;
prev_dc:single;
dc_cat,ac:integer;
dct:array[0..63]of single;
zdct:array[0..63]of single;
img_dct:array[0..63]of single;
dqt:array[0..63]of integer;
ac_run,ac_size,ac_len:integer;
begin
 b.p:=p;
 b.pos:=0;

 if not progress_image(apd,mcu_id,pck_cnt) then exit;

 fill_dqt_by_q(@dqt[0],q);

 prev_dc:=0;
 m:=0;
 while m<mcu_per_packet do begin
  //if b.pos>=len*8-16 then break;  //WTF?
  dc_cat:=get_dc(bio_peek_n_bits(b,16));
  if dc_cat=-1 then begin writeln('Bad DC huffman code!');exit;end;
  bio_advance_n_bits(b,dc_cat_off[dc_cat]);
  n:=bio_fetch_n_bits(b,dc_cat);

  zdct[0]:=map_range(dc_cat,n)+prev_dc;
  prev_dc:=zdct[0];

  k:=1;
  while k<64 do begin
   ac:=get_ac(bio_peek_n_bits(b,16));
   if ac=-1 then begin writeln('Bad AC huffman code!');exit;end;
   ac_len :=ac_table[ac].len;
   ac_size:=ac_table[ac].size;
   ac_run :=ac_table[ac].run;
   bio_advance_n_bits(b,ac_len);

   if (ac_run=0)and(ac_size=0)then begin
    for i:=k to 63 do zdct[i]:=0;
    break;
   end;

   for i:=0 to ac_run-1 do begin zdct[k]:=0;k:=k+1;end;

   if ac_size<>0 then begin
    n:=bio_fetch_n_bits(b,ac_size);
    zdct[k]:=map_range(ac_size,n);
    k:=k+1;
   end else if ac_run=15 then begin
    zdct[k]:=0;
    k:=k+1;
   end;
  end;

  for i:=0 to 63 do dct[i]:=zdct[zigzag[i]]*dqt[i];

  flt_idct_8x8(@img_dct[0],@dct[0]);

  fill_pix(@img_dct[0],apd,mcu_id,m);

  m:=m+1;
 end;
end;
//############################################################################//
procedure mj_init;
begin
 default_huffman_table;
end;
//############################################################################//
begin
end.       
//############################################################################//

