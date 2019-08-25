//############################################################################//
// Made in 2003-2017 by Artyom Litvinovich
// AlgorLib: Truncated version for meteor_decoder
//############################################################################//
{$ifdef fpc}{$mode delphi}{$endif}
unit asys;
{$define fake_vfs}
interface
uses sysutils;
//############################################################################//
//ASYS
type
int32=integer;
dword=cardinal;
{$ifndef fpc}qword=int64;{$endif}

{$ifndef CPUX86_64}
intptr=dword;
{$else}
intptr=PtrUInt;
{$endif}

pdword=^dword;

bytea=array[0..maxint-1]of byte;
pbytea=^bytea;
inta=array[0..maxint div 4-1]of integer;
pinta=^inta;
shortinta=array[0..maxint div 4-1]of shortint;
pshortinta=^shortinta;
singlea=array[0..maxint div 4-1]of single;
psinglea=^singlea;
//############################################################################//
{$ifdef fake_vfs}
const
VFERR_OK=0;
VFO_READ=1;
VFO_WRITE=2;
VFO_RW=3;
type vfile=file;

function vfopen(out f:file;n:string;m:integer):dword;
procedure vfclose(var f:file);
procedure vfwrite(var f:file;p:pointer;s:int32);
{$endif}
//############################################################################//
//GRPH
type
crgba=array[0..3]of byte;
pcrgba=^crgba;
bcrgba=array[0..1000000]of crgba;
pbcrgba=^bcrgba;

pallette=array[0..255]of crgba;
ppallette=^pallette;
//############################################################################//
const
gclaz:crgba=(0,0,0,0);

CLBLUE=0;
CLGREEN=1;
CLRED=2;
gclwhite:crgba=(255,255,255,255);
gclblack:crgba=(0,0,0,255);
gclred:crgba=(0,0,255,255);
gclgreen:crgba=(0,255,0,255);
gcllightgreen:crgba=(128,255,128,255);
gcldarkgreen:crgba=(0,128,0,255);
gclblue:crgba=(255,0,0,255);
gcllightblue:crgba=(255,128,128,255);
gclgray:crgba=(128,128,128,255);
gcllightgray:crgba=(200,200,200,255);
gcldarkgray:crgba=(64,64,64,255);
gclyellow:crgba=(0,255,255,255);
gcldarkyellow:crgba=(0,128,128,255);
gclorange:crgba=(0,128,255,255);
gclbrown:crgba=(0,75,150,255);
gclcyan:crgba=(255,255,0,255);
gclmagenta:crgba=(255,0,255,255);
//############################################################################//
//STRVAL
function stri(par:int64):string;
function strhex(bit:dword):string;
function vali(par:string):int64;
function trimsl(s:string;n:integer;c:char):string;
//############################################################################//
implementation
//############################################################################//
//ASYS
{$ifdef fake_vfs}
function vfopen(out f:file;n:string;m:integer):dword;
begin
 {$ifndef unix}if n[1]='/' then n:=copy(n,2,length(n));{$endif}
 if m=1 then if not fileexists(n) then begin result:=9999; exit; end;
 assignfile(f,n);
 filemode:=0;
 if m=1 then reset(f,1);
 if m=2 then rewrite(f,1);
 result:=VFERR_OK;
end;
procedure vfclose(var f:file);begin closefile(f);end;
procedure vfwrite(var f:file;p:pointer;s:integer);begin blockwrite(f,p^,s);end;
{$endif}
//############################################################################//
//STRVAL
function stri(par:int64):string;begin str(par,result);end;
function strhex(bit:dword):string;begin result:=inttohex(bit,8);end;
function vali(par:string):int64;var n:integer;begin val(trim(par),result,n);if n=0 then exit;end;
function trimsl(s:string;n:integer;c:char):string;begin result:=s;while length(result)<n do result:=c+result;end;
//############################################################################//
begin
end.
//############################################################################//
