//############################################################################//
// Made in 2003-2010 by Artyom Litvinovich
// AlgorLib: Timer 
//############################################################################//
//FIXME: Is TimeStampToMSecs(DateTimeToTimeStamp(Time))*1000 universal?
unit tim;   
{$ifdef win32}{$define i386}{$endif}
{$ifdef cpu86}{$define i386}{$endif}
{$ifdef win32}{$define windows}{$endif}
{$ifdef win64}{$define windows}{$endif}

{$ifdef delphi}{$define asmdir}{$endif}
{$ifdef i386}{$define asmdir}{$endif}
{$ifdef cpu64}{$define asmdir}{$endif}

{$ifdef fpc}
 {$mode delphi}
 {$ifdef asmdir}{$asmmode intel}{$endif}
{$endif}

interface
{$ifdef windows}uses windows;{$endif}
{$ifdef ape3}uses akernel;{$endif}
{$ifdef unix}uses sysutils,unix;{$endif}
//############################################################################//
procedure stdt(d:integer);
function rtdt(d:integer):Int64;  
{$ifdef asmdir}function rdtsc:Int64;{$endif}
function getdt:integer;
procedure freedt(n:integer);
//############################################################################//
implementation    
//############################################################################//
var dtts:array[0..100]of int64;
dtused:array[0..100]of boolean;
{$ifdef windows}frq:int64;{$endif} 
{$ifdef ape3}
dttsf:array[0..100]of double;
timer_ticks:pinteger;
sethz:pinteger;
{$endif}
//############################################################################//
{$ifdef asmdir}
function rdtsc:Int64;
asm
 rdtsc
 mov dword ptr [Result], eax
 mov dword ptr [Result + 4], edx
end;
{$endif}
//############################################################################//
{$ifdef unix}
function getuscount:int64;
var tv:TimeVal;
begin
 FPGetTimeOfDay(@tv,nil);
 result:=tv.tv_Sec*int64(1000000)+tv.tv_uSec;
end;
{$endif}
//############################################################################//
{$ifdef windows}
function getuscount:int64;
begin
 QueryPerformanceCounter(result);
 result:=(int64(1000000)*result) div frq;
end;
{$endif}
//############################################################################//
procedure stdt(d:integer);
begin
 {$ifdef darwin} dtts[d]:=round(TimeStampToMSecs(DateTimeToTimeStamp(Time))*1000);exit;{$endif}
 {$ifdef windows}dtts[d]:=getuscount;exit;{$endif}
 {$ifdef ape3}   dttsf[d]:=timer_ticks^/sethz^;exit;{$endif}
 {$ifdef unix}   dtts[d]:=getuscount;exit;{$endif}
 {$ifdef paser}  dtts[d]:=nano_time;exit;{$endif}
end;
//############################################################################//
function rtdt(d:integer):Int64;
begin
 {$ifdef darwin} result:=round(TimeStampToMSecs(DateTimeToTimeStamp(Time))*1000)-dtts[d];exit;{$endif}
 {$ifdef windows}result:=getuscount-dtts[d];exit;{$endif}
 {$ifdef unix}   result:=getuscount-dtts[d];exit;{$endif}
 {$ifdef ape3}   result:=round((timer_ticks^/sethz^-dttsf[d])*1000000);exit;{$endif}
 {$ifdef paser}  result:=nano_time-dtts[d];exit;{$endif}
end; 
//############################################################################//
function getdt:integer;
var i:integer;
begin
 result:=0;
 for i:=100 downto 0 do if not dtused[i] then begin dtused[i]:=true;result:=i;exit;end;
end;
//############################################################################//
procedure freedt(n:integer);begin dtused[n]:=false;end;
//############################################################################//
var i:integer;
begin
 for i:=0 to 100 do dtused[i]:=false;
 dtused[0]:=true;
 {$ifdef windows}QueryPerformanceFrequency(frq);{$endif}
 {$ifdef ape3}timer_ticks:=sckereg($02);sethz:=sckereg($03);{$endif}
 stdt(0);
end.
//############################################################################//

