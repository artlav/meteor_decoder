//############################################################################//
//Made in 2003-2010 by Artyom Litvinovich
//
//Reed-Solomon (255,223,8) encoding/decoding
//Fixes 16 bytes of errors in 255 bytes block (223 of them are data)
//Typical use is 128 byte block, with 96 bytes of data
//############################################################################//
{$ifdef FPC}{$MODE delphi}{$endif}
unit ecc;
interface
uses asys;
//############################################################################//
procedure ecc_encode(idata:pointer;pad:integer);
function  ecc_decode(idata:pointer;pad:integer):integer;

procedure ecc_deinterleave(data,output:pbytea;pos,n:integer);
procedure ecc_interleave(data,output:pbytea;pos,n:integer);

{$ifdef self_tests}procedure ecc_test;{$endif}
//############################################################################//
implementation
//############################################################################//
const
alpha:array[0..255]of byte=(
 $01,$02,$04,$08,$10,$20,$40,$80,
 $87,$89,$95,$ad,$dd,$3d,$7a,$f4,
 $6f,$de,$3b,$76,$ec,$5f,$be,$fb,
 $71,$e2,$43,$86,$8b,$91,$a5,$cd,
 $1d,$3a,$74,$e8,$57,$ae,$db,$31,
 $62,$c4,$0f,$1e,$3c,$78,$f0,$67,
 $ce,$1b,$36,$6c,$d8,$37,$6e,$dc,
 $3f,$7e,$fc,$7f,$fe,$7b,$f6,$6b,
 $d6,$2b,$56,$ac,$df,$39,$72,$e4,
 $4f,$9e,$bb,$f1,$65,$ca,$13,$26,
 $4c,$98,$b7,$e9,$55,$aa,$d3,$21,
 $42,$84,$8f,$99,$b5,$ed,$5d,$ba,
 $f3,$61,$c2,$03,$06,$0c,$18,$30,
 $60,$c0,$07,$0e,$1c,$38,$70,$e0,
 $47,$8e,$9b,$b1,$e5,$4d,$9a,$b3,
 $e1,$45,$8a,$93,$a1,$c5,$0d,$1a,
 $34,$68,$d0,$27,$4e,$9c,$bf,$f9,
 $75,$ea,$53,$a6,$cb,$11,$22,$44,
 $88,$97,$a9,$d5,$2d,$5a,$b4,$ef,
 $59,$b2,$e3,$41,$82,$83,$81,$85,
 $8d,$9d,$bd,$fd,$7d,$fa,$73,$e6,
 $4b,$96,$ab,$d1,$25,$4a,$94,$af,
 $d9,$35,$6a,$d4,$2f,$5e,$bc,$ff,
 $79,$f2,$63,$c6,$0b,$16,$2c,$58,
 $b0,$e7,$49,$92,$a3,$c1,$05,$0a,
 $14,$28,$50,$a0,$c7,$09,$12,$24,
 $48,$90,$a7,$c9,$15,$2a,$54,$a8,
 $d7,$29,$52,$a4,$cf,$19,$32,$64,
 $c8,$17,$2e,$5c,$b8,$f7,$69,$d2,
 $23,$46,$8c,$9f,$b9,$f5,$6d,$da,
 $33,$66,$cc,$1f,$3e,$7c,$f8,$77,
 $ee,$5b,$b6,$eb,$51,$a2,$c3,$00
);
//############################################################################//
idx:array[0..255]of byte=(
 255,  0,  1, 99,  2,198,100,106,
   3,205,199,188,101,126,107, 42,
   4,141,206, 78,200,212,189,225,
 102,221,127, 49,108, 32, 43,243,
   5, 87,142,232,207,172, 79,131,
 201,217,213, 65,190,148,226,180,
 103, 39,222,240,128,177, 50, 53,
 109, 69, 33, 18, 44, 13,244, 56,
   6,155, 88, 26,143,121,233,112,
 208,194,173,168, 80,117,132, 72,
 202,252,218,138,214, 84, 66, 36,
 191,152,149,249,227, 94,181, 21,
 104, 97, 40,186,223, 76,241, 47,
 129,230,178, 63, 51,238, 54, 16,
 110, 24, 70,166, 34,136, 19,247,
  45,184, 14, 61,245,164, 57, 59,
   7,158,156,157, 89,159, 27,  8,
 144,  9,122, 28,234,160,113, 90,
 209, 29,195,123,174, 10,169,145,
  81, 91,118,114,133,161, 73,235,
 203,124,253,196,219, 30,139,210,
 215,146, 85,170, 67, 11, 37,175,
 192,115,153,119,150, 92,250, 82,
 228,236, 95, 74,182,162, 22,134,
 105,197, 98,254, 41,125,187,204,
 224,211, 77,140,242, 31, 48,220,
 130,171,231, 86,179,147, 64,216,
  52,176,239, 38, 55, 12, 17, 68,
 111,120, 25,154, 71,116,167,193,
  35, 83,137,251, 20, 93,248,151,
  46, 75,185, 96, 15,237, 62,229,
 246,135,165, 23, 58,163, 60,183
);
//############################################################################//
poly:array[0..32]of byte=(
  0,249,59 ,66 ,4  ,43 ,126,251,
 97,30 ,3  ,213,50 ,66 ,170,5  ,
 24,5  ,170,66 ,50 ,213,3  ,30 ,
 97,251,126,43 ,4  ,66 ,59 ,249,
  0
);
//############################################################################//
procedure ecc_encode(idata:pointer;pad:integer);
var i,j:integer;
feedback:byte;
data,bb:pbytea;
begin
 data:=idata;
 bb:=@data[255-32-pad];
 fillchar(bb[0],32,0);
 for i:=0 to 223-pad-1 do begin
  feedback:=idx[data[i] xor bb[0]];
  if feedback<>255 then begin
   for j:=1 to 32-1 do bb[j]:=bb[j] xor alpha[(feedback+poly[32-j]) mod 255];
  end;

  move(bb[1],bb[0],31);
  if feedback<>255 then bb[31]:=alpha[(feedback+poly[0]) mod 255]
                   else bb[31]:=0;
 end;
end;
//############################################################################//
//Fixes the data in place
//Returns amount of errors fixed.
//Returns -1 if unfixable.
function ecc_decode(idata:pointer;pad:integer):integer;
var i,j,r,k,deg_lambda,el,deg_omega:integer;
syn_error:integer;
q,tmp,num1,num2,den,discr_r:byte;
lambda,b,reg,t,omega:array[0..32]of byte;
root,s,loc:array[0..31]of byte;
data:pbytea;
begin
 data:=idata;

 for i:=0 to 32-1 do s[i]:=data[0];
 for j:=1 to 255-pad-1 do for i:=0 to 32-1 do if s[i]=0 then s[i]:=data[j] else s[i]:=data[j] xor alpha[(idx[s[i]]+(112+i)*11)mod 255];
 syn_error:=0;

 for i:=0 to 32-1 do begin
  syn_error:=syn_error or s[i];
  s[i]:=idx[s[i]];
 end;

 if syn_error=0 then begin result:=0;exit; end;

 fillchar(lambda[1],32,0);
 lambda[0]:=1;

 for i:=0 to 33-1 do b[i]:=idx[lambda[i]];
 r:=0;
 el:=0;

 r:=r+1;
 while r<=32 do begin
  discr_r:=0;
  for i:=0 to r-1 do if(lambda[i]<>0)and(s[r-i-1]<>255)then discr_r:=discr_r xor alpha[(idx[lambda[i]]+s[r-i-1])mod 255];
  discr_r:=idx[discr_r];
  if discr_r=255 then begin
   move(b[0],b[1],32);
   b[0]:=255;
  end else begin
   t[0]:=lambda[0];
   for i:=0 to 32-1 do begin
    if b[i]<>255 then t[i+1]:=lambda[i+1] xor alpha[(discr_r+b[i])mod 255]
                 else t[i+1]:=lambda[i+1];
   end;
   if 2*el<=r-1 then begin
    el:=r-el;
    for i:=0 to 32-1 do begin
     if lambda[i]=0 then b[i]:=255 else b[i]:=byte((idx[lambda[i]]-discr_r+255)mod 255);
    end;
   end else begin
    move(b[0],b[1],32);
    b[0]:=255;
   end;
   move(t[0],lambda[0],33);
  end;
  r:=r+1;
 end;

 deg_lambda:=0;
 for i:=0 to 33-1 do begin
  lambda[i]:=idx[lambda[i]];
  if lambda[i]<>255 then deg_lambda:=i;
 end;

 move(lambda[1],reg[1],32);
 result:=0;

 i:=1;
 k:=115;
 repeat
  if not(i<=255) then break;

  q:=1;
  for j:=deg_lambda downto 1 do begin
   if reg[j]<>255 then begin
    reg[j]:=byte((reg[j]+j)mod 255);
    q:=q xor alpha[reg[j]];
   end;
  end;

  if q<>0 then begin i:=i+1;k:=(k+116)mod 255; continue;end;
  root[result]:=i;
  loc[result]:=k;
  result:=result+1;
  if result=deg_lambda then break;

  i:=i+1;k:=(k+116)mod 255;
 until false;

 if deg_lambda<>result then begin result:=-1;exit;end;

 deg_omega:=deg_lambda-1;
 for i:=0 to deg_omega do begin
  tmp:=0;
  for j:=i downto 0 do if(s[i-j]<>255)and(lambda[j]<>255)then tmp:=tmp xor alpha[(s[i-j]+lambda[j])mod 255];
  omega[i]:=idx[tmp];
 end;

 for j:=result-1 downto 0 do begin
  num1:=0;
  for i:=deg_omega downto 0 do if omega[i]<>255 then num1:=num1 xor alpha[(omega[i]+i*root[j])mod 255];
  num2:=alpha[(root[j]*111+255)mod 255];
  den:=0;

  if deg_lambda<31 then i:=deg_lambda else i:=31;
  i:=i and not 1;
  repeat
   if not (i>=0) then break;
   if lambda[i+1]<>255 then den:=den xor alpha[(lambda[i+1]+i*root[j])mod 255];
   i:=i-2;
  until false;

  if(num1<>0)and(loc[j]>=pad)then data[loc[j]-pad]:=data[loc[j]-pad] xor alpha[(idx[num1]+idx[num2]+255-idx[den])mod 255];
 end;
end;
//############################################################################//
procedure ecc_deinterleave(data,output:pbytea;pos,n:integer);
var i:integer;
begin
 for i:=0 to 255-1 do output[i]:=data[i*n+pos];
end;
//############################################################################//
procedure ecc_interleave(data,output:pbytea;pos,n:integer);
var i:integer;
begin
 for i:=0 to 255-1 do output[i*n+pos]:=data[i];
end;
//############################################################################//
{$ifdef self_tests}
procedure ecc_test;
var ref,blk:array[0..127]of byte;
i,k:integer;
begin
 randomize;
 for k:=0 to 100-1 do begin
  for i:=0 to 96-1 do begin
   ref[i]:=random(256);
   blk[i]:=ref[i];
  end;
  ecc_encode(@blk[0],127);
  for i:=0 to random(16) do blk[random(128)]:=random(256);
  ecc_decode(@blk[0],127);
  for i:=0 to 96-1 do if blk[i]<>ref[i] then begin writeln('ECC: error ',i);exit;  end;
 end;
 writeln('ECC: ok');
end;
{$endif}
//############################################################################//
begin
end.
//############################################################################//

