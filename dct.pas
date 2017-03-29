//############################################################################// 
//Made in 2017 by Artyom Litvinovich
//Naive DCT coder/decoder
//############################################################################// 
unit dct;
interface
uses asys;
//############################################################################//
procedure flt_dct_8x8(res,inp:psinglea);
procedure flt_idct_8x8(res,inp:psinglea);
//############################################################################//
implementation
//############################################################################//
var cos_inited:boolean=false;
cosine:array[0..7]of array[0..7]of single;
alpha:array[0..7]of single;
//############################################################################//
procedure init_cos;
var x,y:integer;
begin
 if cos_inited then exit;
 cos_inited:=true;
 for y:=0 to 7 do for x:=0 to 7 do cosine[y][x]:=cos(pi/16*(2*y+1)*x);
 for x:=0 to 7 do if x=0 then alpha[x]:=1/sqrt(2) else alpha[x]:=1;
end;
//############################################################################//
procedure flt_dct_8x8(res,inp:psinglea);
var x,y,u,v:integer;
s:single;
begin
 init_cos;

 for y:=0 to 7 do for x:=0 to 7 do begin
  s:=0;
  for u:=0 to 7 do for v:=0 to 7 do s:=s+inp[v*8+u]*cosine[u][x]*cosine[v][y];
  res[y*8+x]:=s*alpha[x]*alpha[y]/4;
 end;
end;
//############################################################################//
procedure flt_idct_8x8(res,inp:psinglea);
var x,y,u:integer;
s,cxu:single;
begin
 init_cos;

 for y:=0 to 7 do for x:=0 to 7 do begin
  s:=0;
  //for u:=0 to 7 do for v:=0 to 7 do s:=s+inp[v*8+u]*alpha[u]*alpha[v]*cosine[x][u]*cosine[y][v];
  for u:=0 to 7 do begin
   cxu:=alpha[u]*cosine[x][u];
   //Unrolled to 8
   s:=s+cxu*(inp[0*8+u]*alpha[0]*cosine[y][0]+
             inp[1*8+u]*alpha[1]*cosine[y][1]+
             inp[2*8+u]*alpha[2]*cosine[y][2]+
             inp[3*8+u]*alpha[3]*cosine[y][3]+
             inp[4*8+u]*alpha[4]*cosine[y][4]+
             inp[5*8+u]*alpha[5]*cosine[y][5]+
             inp[6*8+u]*alpha[6]*cosine[y][6]+
             inp[7*8+u]*alpha[7]*cosine[y][7]);
  end;
  res[y*8+x]:=s/4;
 end;
end;
//############################################################################//
begin
end.
//############################################################################//

