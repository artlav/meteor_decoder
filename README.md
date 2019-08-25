A portable decoder for METEOR M weather satellite LRPT signal

Requires Free Pascal to compile ( [http://www.freepascal.org](http://www.freepascal.org) , or in your Linux distro repositories), no dependencies.

## Build

Use ./build_medet.sh, or fpc -CX -XX -O3 -Mdelphi -FUunits -Fualib medet.dpr

On Windows, edit path to FPC in build.bat, then use build.bat (or the same direct invocation line as above)

## Binaries

Binaries for Windows, Linux, Raspberry Pi and MacOS X are available at [Orbides](http://orbides.org/page.php?id=1023)

## Usage

medet input_file output_name [OPTIONS]  

Expects 8 bit signed soft samples, 1 bit hard samples or decoded dump input  
Image would be written to output_name.bmp

Input:  
 -soft      Use 8 bit soft samples (default)  
 -h -hard   Use hard samples  
 -d -dump   Use decoded dump  
  
Process:  
 -diff      Diff coding (for Meteor M2-2)  
  
Output:  
 -ch        Make hard samples (as decoded)  
 -cd        Make decoded dump  
 -cn        Make image (default)  
 -r x       APID for red   (default: ',red_apid,')  
 -g x       APID for green (default: ',green_apid,')  
 -b x       APID for blue  (default: ',blue_apid,')  
 -s         Split image by channels  
 -S         Both split image by channels, and output composite  
 -t         Write stat file with time information  
  
Print:  
 -q         Don't print verbose info  
 -Q         Don't print anything  
 -p         Print loads of debug info  
 -na        Don't compress the debug output to a single line  
  
As of August 2019, N2 and N2-2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 66 (10.5-11.5)  
As of March 2017, N2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 68 (10.5-11.5)  
Defaults produce 125 image compatible with many tools  
Nice false color image is produced with -r 65 -g 65 -b 64  
Decoded dump is 9 times smaller than the raw signal, and can be re-decoded 20x as fast, so it's a good format to store images and play with channels  
