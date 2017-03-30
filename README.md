A portable decoder for METEOR M weather satellite LRPT signal

Requires Free Pascal to compile ( [http://www.freepascal.org](http://www.freepascal.org) , or in your Linux distro repositories), no dependencies.

## Build

Use ./build_medet.sh, or fpc -CX -XX -O3 -Mdelphi -FUunits -Fualib medet.dpr

On Windows, edit path to FPC in build.bat, then use build.bat (or the same direct invocation line as above)

## Binaries

Binaries for Windows, Linux, Raspberry Pi and MacOS X are available at [Orbides](http://orbides.org/page.php?id=1023)

## Usage

medet input_file output_name [OPTIONS]  

Expects 8 bit signed soft QPSK input  
Image would be written to output_name.bmp
  
Options:  
-q    Don't print verbose info  
-Q    Don't print anything  
-d    Print loads of debug info  
-r x  APID for red   (default: 68)  
-g x  APID for green (default: 65)  
-b x  APID for blue  (default: 64)  
-s    Split image by channels  
-S    Both split image by channels, and output composite  
-t    Write stat file with time information  
 
As of March 2017, N2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 68 (10.5-11.5)  
Defaults produce 125 image compatible with many tools  
Nice false color image is produced with -r 65 -g 65 -b 64  
