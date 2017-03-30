//############################################################################//
//Made in 2017 by Artyom Litvinovich
//Meteor decoder
//############################################################################//
program medet;
{$ifdef mswindows}{$APPTYPE console}{$endif}
uses asys,met_to_data,met_jpg,met_packet,tim;
//############################################################################//
var
quiet:boolean=false;
print_stats:boolean=true;
//############################################################################//
procedure process_file(fn,out_name:string);
var f:file;
sz:integer;
raw:array of byte;
m:mtd_rec;
ok:boolean;
dt_total,dt_proc:integer;
stat_proc,stat_total:int64;
ok_cnt,total_cnt:integer;
begin  
 mj_init;
 mtd_init(m);

 assignfile(f,fn);
 reset(f,1);
 sz:=filesize(f);
 setlength(raw,sz);
 blockread(f,raw[0],sz);
 closefile(f);

 dt_total:=getdt;
 dt_proc:=getdt;   
 stat_corr:=0;
 stat_vit:=0;
 stat_ecc:=0;
 stat_proc:=0;
 ok_cnt:=0;
 total_cnt:=0;

 m.pos:=0;
 stdt(dt_total);
 while m.pos<sz-soft_frame_len do begin
  ok:=mtd_one_frame(m,@raw[0]);
  if ok then begin              
   stdt(dt_proc);
   parse_cvcdu(@m.ecced_data[0],hard_frame_len-4-128);
   stat_proc:=stat_proc+rtdt(dt_proc);
   ok_cnt:=ok_cnt+1;
   if not quiet then writeln(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync));
  end else begin
   if not quiet then writeln(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync));
  end;
  total_cnt:=total_cnt+1;
 end;
 stat_total:=rtdt(dt_total);

 if print_stats then begin
  writeln('Total:       ',stat_total/1e6:6:6);
  writeln('Processing:  ',stat_proc/1e6:6:6);
  writeln('Correlation: ',stat_corr/1e6:6:6);
  writeln('Viterbi:     ',stat_vit/1e6:6:6);
  writeln('ECC:         ',stat_ecc/1e6:6:6);
  writeln('Remainder:   ',(stat_total-stat_ecc-stat_vit-stat_corr-stat_proc)/1e6:6:6);
  writeln('Packets:     ',ok_cnt,' / ',total_cnt);
 end;

 freedt(dt_total);
 freedt(dt_proc);

 mj_dump_image(out_name);
end;
//############################################################################//
procedure set_apid(n:integer;var i:integer);
var k:integer;
begin
 if paramcount<i+1 then begin writeln('Missing apid parameter!');halt;end;
 k:=vali(paramstr(i+1));
 case n of
  0:red_apid:=k;
  1:green_apid:=k;
  2:blue_apid:=k;
 end;
 i:=i+1;
end;
//############################################################################//
procedure main;
var inp,outp:string;
i:integer;
begin
 if paramcount<2 then begin
  writeln('medet input_file output_name [OPTIONS]'); 
  writeln;
  writeln('Expects 8 bit signed soft QPSK input');
  writeln('Image would be written to output_name.bmp');
  writeln;
  writeln('Options:');
  writeln(' -q    Don''t print verbose info');
  writeln(' -Q    Don''t print anything');
  writeln(' -d    Print loads of debug info');
  writeln(' -r x  APID for red   (default: ',red_apid,')');
  writeln(' -g x  APID for green (default: ',green_apid,')');
  writeln(' -b x  APID for blue  (default: ',blue_apid,')');
  writeln(' -s    Split image by channels');
  writeln;
  writeln('As of March 2017, N2 got APIDs 64 (0.5-0.7), 65 (0.7-1.1) and 68 (10.5-11.5)');
  writeln('Defaults produce 125 image compatible with many tools');
  writeln('Nice false color image is produced with -r 65 -g 65 -b 64'); 
  writeln;


  {$ifdef win32}readln;{$endif}
  {$ifdef win64}readln;{$endif}
  exit;
 end;

 if paramcount>2 then begin
  i:=3;
  while i<=paramcount do begin
   if paramstr(i)='-d' then md_debug:=true;
   if paramstr(i)='-q' then quiet:=true;
   if paramstr(i)='-Q' then begin quiet:=true; print_stats:=false;end;
   if paramstr(i)='-r' then set_apid(0,i);
   if paramstr(i)='-g' then set_apid(1,i);
   if paramstr(i)='-b' then set_apid(2,i);
   if paramstr(i)='-s' then split_channels:=true;
   i:=i+1;
  end;
 end;
    
 inp:=paramstr(1);
 outp:=paramstr(2);

 process_file(inp,outp);
end;
//############################################################################//
begin
 main;
end. 
//############################################################################//

