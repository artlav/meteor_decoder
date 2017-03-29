@echo off
set path=P:\fpc-300\bin\i386-win32;%path%
mkdir units
call fpc -Mdelphi -Fualib -FUunits -CX -XX -O3 medet.dpr
pause
