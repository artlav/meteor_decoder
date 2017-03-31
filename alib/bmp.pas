//############################################################################//
//Made in 2003-2016 by Artyom Litvinovich
//AlgorLib: BMP Loader
//############################################################################//
{$ifdef FPC}{$MODE delphi}{$endif}
unit bmp;
interface
uses asys;
//############################################################################//
const default_bmp_dpi=96;
//############################################################################//
type
bmp_filehdr=packed record
 typ:word;
 size:dword;
 reserved1,reserved2:word;
 off_bits:dword;
end;
bmp_infohdr=packed record
 size:dword;
 wid,hei:integer;
 planes:word;
 bit_count:word;
 compression,img_size:dword;
 xpels_per_meter,ypels_per_meter:integer;
 clr_used,clr_important:dword;
end;
//############################################################################//
procedure make_bmp_headers(xr,yr,bpp:integer;out fh:bmp_filehdr;out ih:bmp_infohdr);
function  storebmp32(fn:string;p:pointer;xr,yr:integer;rev,bgr:boolean):boolean;      
function  storebmp8 (fn:string;p:pointer;xr,yr:integer;rev,bgr:boolean;pal:pallette):boolean;
//############################################################################//
implementation     
//############################################################################//
procedure make_bmp_headers(xr,yr,bpp:integer;out fh:bmp_filehdr;out ih:bmp_infohdr);
var pcnt:integer;
begin      
 fh.typ:=19778;   
 fh.reserved1:=0;
 fh.reserved2:=0;
 fh.off_bits:=54;   
  
 ih.wid:=xr;
 ih.hei:=yr;  
 ih.size:=sizeof(ih); 
 ih.planes:=1; 
 ih.compression:=0;

 //LRPT_places is confused by this field
 ih.xpels_per_meter:=0; //round((default_bmp_dpi*2.54*xr)/100);    //DPI
 ih.ypels_per_meter:=ih.xpels_per_meter;
 ih.clr_used:=0; 
 ih.clr_important:=0; 
 
 case bpp of 
  32:begin
   fh.size:=xr*yr*4;  
   ih.bit_count:=32;
   ih.img_size:=xr*yr*4;
  end;
  24:begin
   fh.size:=xr*yr*3;    
   ih.bit_count:=24;
   ih.img_size:=xr*yr*3;
  end;
  8:begin          
   pcnt:=0;
   if (xr mod 4)<>0 then pcnt:=4-(xr mod 4);
   fh.size:=(xr+pcnt)*yr;     
   fh.off_bits:=54+1024;
   ih.bit_count:=8;
   ih.img_size:=0;
  end;
 end;
end;
//############################################################################//   
//############################################################################//
function storebmp_rgb(bpp:integer;fn:string;p:pointer;xr,yr:integer;rev,bgr:boolean):boolean;
var f:vfile;  
fh:bmp_filehdr;
ih:bmp_infohdr;
i,j:integer;
pp:pointer;
c1,c2:pcrgba;
begin  
 result:=false;
 if vfopen(f,fn,2)<>VFERR_OK then exit;
              
 make_bmp_headers(xr,yr,bpp*8,fh,ih);
   
 vfwrite(f,@fh,sizeof(Fh));
 vfwrite(f,@ih,sizeof(Ih));
 if bgr then begin
  getmem(pp,xr*bpp);
  for i:=yr-1 downto 0 do begin
   for j:=0 to xr-1 do begin
    c1:=pointer(intptr(p)+intptr((j+i*xr)*bpp));
    c2:=pointer(intptr(pp)+intptr(j*bpp));
    c2[0]:=c1[CLRED];
    c2[1]:=c1[CLGREEN];
    c2[2]:=c1[CLBLUE];
    if bpp=4 then c2[3]:=c1[3];
   end;
   vfwrite(f,pp,xr*bpp);
  end;
  freemem(pp);
 end else begin
  if not rev then vfwrite(f,p,xr*yr*bpp) else for i:=yr-1 downto 0 do vfwrite(f,pointer(intptr(p)+intptr(i*xr*bpp)),xr*bpp);
 end;
 vfclose(f);
 result:=true;
end;
//############################################################################//
function storebmp8(fn:string;p:pointer;xr,yr:integer;rev,bgr:boolean;pal:pallette):boolean;
var f:vfile;
fh:bmp_filehdr;
ih:bmp_infohdr;
pcnt,i:integer;
cl:byte;
pad:dword;
begin
 result:=false;
 if vfopen(f,fn,2)<>VFERR_OK then exit;

 pad:=0;
 pcnt:=0;
 if (xr mod 4)<>0 then pcnt:=4-(xr mod 4);
 make_bmp_headers(xr,yr,8,fh,ih);

 vfwrite(f,@fh,sizeof(Fh));
 vfwrite(f,@ih,sizeof(Ih));

 if bgr then for i:=0 to 255 do begin
  cl:=pal[i][0];
  pal[i][0]:=pal[i][2];
  pal[i][2]:=cl;
 end;

 vfwrite(f,@pal,1024);
 if not rev then begin
  for i:=0 to yr-1 do begin
   vfwrite(f,pointer(intptr(p)+intptr(i*xr)),xr);
   if pcnt<>0 then vfwrite(f,@pad,pcnt);
  end;
 end else begin
  for i:=yr-1 downto 0 do begin
   vfwrite(f,@pbytea(p)[i*xr],xr);
   if pcnt<>0 then vfwrite(f,@pad,pcnt);
  end;
 end;

 vfclose(f);
 result:=true;
end;
//############################################################################//
function storebmp32(fn:string;p:pointer;xr,yr:integer;rev,bgr:boolean):boolean;
begin  
 result:=storebmp_rgb(4,fn,p,xr,yr,rev,bgr);
end;   
//############################################################################//
begin   
end.  
//############################################################################//
