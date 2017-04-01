//############################################################################//
//Made in 2017 by Artyom Litvinovich
//Meteor decoder
//############################################################################//
program medet;
{$ifdef mswindows}{$APPTYPE console}{$endif}
uses sysutils,asys,met_to_data,met_jpg,met_packet,tim,correlator,viterbi27,ecc;
//############################################################################//
procedure print_times(out_name:string);  
var h,m,s,ms,dh,dm,ds,dms,delta:integer;
f:text;
begin
 if no_time_yet then exit;
 if last_time<first_time then last_time:=last_time+86400*1000;  //If it crossed midnight

 delta:=last_time-first_time;

 dh:=delta div (3600*1000); delta:=delta-dh*3600*1000;
 dm:=delta div (60*1000);   delta:=delta-dm*60*1000;
 ds:=delta div 1000;        delta:=delta-ds*1000;
 dms:=delta;
            
 h:=first_time div (3600*1000); first_time:=first_time-h*3600*1000;
 m:=first_time div (60*1000);   first_time:=first_time-m*60*1000;
 s:=first_time div 1000;        first_time:=first_time-s*1000;
 ms:=first_time;

 if print_stats then writeln('Elapsed time: ',trimsl(stri(dh),2,'0'),':',trimsl(stri(dm),2,'0'),':',trimsl(stri(ds),2,'0'),'.',trimsl(stri(dms),3,'0'));

 if time_file then begin
  assignfile(f,out_name+'.stat');
  rewrite(f);

  //LRPT_places needs windows line endings
  write(f,trimsl(stri( h),2,'0'),':',trimsl(stri( m),2,'0'),':',trimsl(stri( s),2,'0'),'.',trimsl(stri( ms),3,'0')+#$0D#$0A);
  write(f,trimsl(stri(dh),2,'0'),':',trimsl(stri(dm),2,'0'),':',trimsl(stri(ds),2,'0'),'.',trimsl(stri(dms),3,'0')+#$0D#$0A);
  write(f,'0,1538925'+#$0D#$0A);   //WTF? Appears irrelevant

  closefile(f);
 end;
end;
//############################################################################//
procedure recreate_packet(var m:mtd_rec;pck,hard:pbytea;var hard_pos:integer);
var raw:array[0..frame_bits*2-1]of byte;
input:array[0..hard_frame_len-1]of byte;
i:integer;
begin
 move(pck[0],input[4],hard_frame_len-4);
 pdword(@input[0])^:=$1DFCCF1A;
 for i:=0 to hard_frame_len-4-1 do input[4+i]:=input[4+i] xor prand[i mod 255];

 vit_conv_encode(m.v,@input[0],@raw[0]);

 soft_to_hard(@raw[0],@hard[hard_pos],soft_frame_len);
 hard_pos:=hard_pos+2*hard_frame_len;
end;
//############################################################################//
procedure process_file(fn,out_name:string;do_hard,make_hard:boolean);
var f:file;
sz,hard_pos:integer;
hard,raw:array of byte;
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
 if do_hard then begin
  setlength(hard,sz);
  blockread(f,hard[0],sz);

  setlength(raw,sz*8);
  hard_to_soft(@hard[0],@raw[0],sz);
  setlength(hard,0);
  sz:=sz*8;
 end else begin
  setlength(raw,sz);
  blockread(f,raw[0],sz);
 end;
 closefile(f);

 dt_total:=getdt;
 dt_proc:=getdt;   
 stat_corr:=0;
 stat_vit:=0;
 stat_ecc:=0;
 stat_proc:=0;
 ok_cnt:=0;
 total_cnt:=0;

 if make_hard then begin
  setlength(hard,sz);
  hard_pos:=0;
 end;

 m.pos:=0;
 stdt(dt_total);
 while m.pos<sz-soft_frame_len do begin
  ok:=mtd_one_frame(m,@raw[0]);
  if ok then begin
   if make_hard then recreate_packet(m,@m.ecced_data[0],@hard[0],hard_pos);
   if not quiet then write(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync),' ');
   if not quiet and md_debug then writeln;
   stdt(dt_proc);
   parse_cvcdu(@m.ecced_data[0],hard_frame_len-4-128);
   stat_proc:=stat_proc+rtdt(dt_proc);
   ok_cnt:=ok_cnt+1;
   if not quiet and not md_debug then writeln;
  end else begin
   if not quiet then writeln(' pos=',m.prev_pos:8,' (',(m.prev_pos/sz)*100:6:2,'%) (',m.word:2,',',m.cpos:5,',',m.corr:2,') sig=',m.sig_q:5,' rs=(',m.r[0]:2,',',m.r[1]:2,',',m.r[2]:2,',',m.r[3]:2,') ',strhex(m.last_sync),' ');
  end;
  total_cnt:=total_cnt+1;
 end;
 stat_total:=rtdt(dt_total);

 if print_stats then begin
  writeln('Total:        ',stat_total/1e6:6:6);
  writeln('Processing:   ',stat_proc/1e6:6:6);
  writeln('Correlation:  ',stat_corr/1e6:6:6);
  writeln('Viterbi:      ',stat_vit/1e6:6:6);
  writeln('ECC:          ',stat_ecc/1e6:6:6);
  writeln('Remainder:    ',(stat_total-stat_ecc-stat_vit-stat_corr-stat_proc)/1e6:6:6);
  writeln('Packets:      ',ok_cnt,' / ',total_cnt);
 end;

 print_times(out_name);

 freedt(dt_total);
 freedt(dt_proc);

 mj_dump_image(out_name);

 if make_hard and (hard_pos<>0) then begin
  assignfile(f,out_name+'.hard');
  rewrite(f,1);
  blockwrite(f,hard[0],hard_pos);
  closefile(f);
 end;
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
do_hard,make_hard:boolean;
begin
 do_hard:=false;
 make_hard:=false;
 if paramcount<2 then begin
  writeln('medet input_file output_name [OPTIONS]'); 
  writeln;
  writeln('Expects 8 bit signed soft QPSK or 1 bit hard QPSK input');
  writeln('Image would be written to output_name.bmp');
  writeln;
  writeln('Options:');
  writeln(' -h    Use hard samples (default - 8 bit soft)');
  writeln(' -ch   Make hard samples (as decoded)');
  writeln(' -q    Don''t print verbose info');
  writeln(' -Q    Don''t print anything');
  writeln(' -d    Print loads of debug info');
  writeln(' -r x  APID for red   (default: ',red_apid,')');
  writeln(' -g x  APID for green (default: ',green_apid,')');
  writeln(' -b x  APID for blue  (default: ',blue_apid,')');
  writeln(' -s    Split image by channels');
  writeln(' -S    Both split image by channels, and output composite');
  writeln(' -t    Write stat file with time information');
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
   if paramstr(i)='-h' then do_hard:=true;
   if paramstr(i)='-ch' then make_hard:=true;
   if paramstr(i)='-d' then md_debug:=true;
   if paramstr(i)='-q' then quiet:=true;
   if paramstr(i)='-Q' then begin quiet:=true; print_stats:=false;end;
   if paramstr(i)='-r' then set_apid(0,i);
   if paramstr(i)='-g' then set_apid(1,i);
   if paramstr(i)='-b' then set_apid(2,i);
   if paramstr(i)='-s' then output_mode:=OUT_SPLIT;
   if paramstr(i)='-S' then output_mode:=OUT_BOTH;
   if paramstr(i)='-t' then time_file:=true;
   i:=i+1;
  end;
 end;
    
 inp:=paramstr(1);
 outp:=paramstr(2);
 
 if not fileexists(inp) then begin
  writeln('Input file "',inp,'" not found!');
  exit;
 end;

 process_file(inp,outp,do_hard,make_hard);
end;
//############################################################################//
begin
 main;
end. 
//############################################################################//

