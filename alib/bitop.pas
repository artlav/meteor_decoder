//############################################################################//
//Made in 2017 by Artyom Litvinovich
//Various bit operations
//############################################################################//
{$ifdef FPC}{$MODE delphi}{$endif}
unit bitop;
interface
uses asys;
//############################################################################//
type
bit_io_rec=record
 p:pbytea;
 pos,len:integer;

 cur:byte;
 cur_len:integer;
end;
//############################################################################//   
function count_bits(n:dword):integer;

function bio_peek_n_bits    (var b:bit_io_rec;const n:integer):dword;
procedure bio_advance_n_bits(var b:bit_io_rec;const n:integer);
function bio_fetch_n_bits   (var b:bit_io_rec;const n:integer):dword;

procedure bit_writer_create(var w:bit_io_rec;bytes:pbytea;len:integer);
procedure bio_write_bitlist_reversed(var w:bit_io_rec;l:pbytea;len:integer);
//############################################################################//
implementation        
//############################################################################//
const bitcnt:array[0..255]of integer=(
 0, 1, 1, 2, 1, 2, 2, 3,
 1, 2, 2, 3, 2, 3, 3, 4,
 1, 2, 2, 3, 2, 3, 3, 4,
 2, 3, 3, 4, 3, 4, 4, 5,
 1, 2, 2, 3, 2, 3, 3, 4,
 2, 3, 3, 4, 3, 4, 4, 5,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 1, 2, 2, 3, 2, 3, 3, 4,
 2, 3, 3, 4, 3, 4, 4, 5,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 3, 4, 4, 5, 4, 5, 5, 6,
 4, 5, 5, 6, 5, 6, 6, 7,
 1, 2, 2, 3, 2, 3, 3, 4,
 2, 3, 3, 4, 3, 4, 4, 5,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 3, 4, 4, 5, 4, 5, 5, 6,
 4, 5, 5, 6, 5, 6, 6, 7,
 2, 3, 3, 4, 3, 4, 4, 5,
 3, 4, 4, 5, 4, 5, 5, 6,
 3, 4, 4, 5, 4, 5, 5, 6,
 4, 5, 5, 6, 5, 6, 6, 7,
 3, 4, 4, 5, 4, 5, 5, 6,
 4, 5, 5, 6, 5, 6, 6, 7,
 4, 5, 5, 6, 5, 6, 6, 7,
 5, 6, 6, 7, 6, 7, 7, 8
);
//############################################################################//
function count_bits(n:dword):integer;
begin
 result:=bitcnt[n and $FF]+bitcnt[(n shr 8) and $FF]+bitcnt[(n shr 16) and $FF]+bitcnt[(n shr 24) and $FF];
 //result:=0;while n<>0 do begin n:=n and (n-1);result:=result+1;end;
end;
//############################################################################//
function bio_peek_n_bits(var b:bit_io_rec;const n:integer):dword;
var bit,i,p:integer;
begin
 result:=0;
 for i:=0 to n-1 do begin
  p:=b.pos+i;
  bit:=(b.p[p shr 3] shr (7-(p and 7))) and 1;
  result:=(result shl 1) or bit;
 end;
end;
//############################################################################//
procedure bio_advance_n_bits(var b:bit_io_rec;const n:integer);begin b.pos:=b.pos+n;end;
function bio_fetch_n_bits(var b:bit_io_rec;const n:integer):dword;begin result:=bio_peek_n_bits(b,n);bio_advance_n_bits(b,n);end;
//############################################################################//
procedure bit_writer_create(var w:bit_io_rec;bytes:pbytea;len:integer);
begin
 w.p:=bytes;
 w.len:=len;

 w.cur:=0;
 w.cur_len:=0;
 w.pos:=0;
end;
//############################################################################//
function byte_off(l:pbytea;n:integer):byte;
begin
 result:=pbyte(intptr(l)+n)^;
end;
//############################################################################//
procedure bio_write_bitlist_reversed(var w:bit_io_rec;l:pbytea;len:integer);
var bytes:pbytea;
i,byte_index,close_len,full_bytes:integer;
b:word;
begin
 l:=@l[len-1];

 bytes:=w.p;
 byte_index:=w.pos;

 if w.cur_len<>0 then begin
  close_len:=8-w.cur_len;
  if close_len>=len then close_len:=len;

  b:=w.cur;

  for i:=0 to close_len-1 do begin
   b:=b or l[0];
   b:=b shl 1;
   l:=pointer(intptr(l)-1);
  end;

  len:=len-close_len;

  if w.cur_len+close_len=8 then begin
   b:=b shr 1;
   bytes[byte_index]:=b;
   byte_index:=byte_index+1;
  end else begin
   w.cur:=b;
   w.cur_len:=w.cur_len+close_len;
   exit;
  end;
 end;

 full_bytes:=len div 8;

 for i:=0 to full_bytes-1 do begin
  bytes[byte_index]:=(byte_off(l, 0) shl 7) or (byte_off(l,-1) shl 6) or (byte_off(l,-2) shl 5) or
                     (byte_off(l,-3) shl 4) or (byte_off(l,-4) shl 3) or (byte_off(l,-5) shl 2) or
                     (byte_off(l,-6) shl 1) or byte_off(l,-7);
  byte_index:=byte_index+1;
  l:=pointer(intptr(l)-8);
 end;

 len:=len-8*full_bytes;

 b:=0;
 for i:=0 to len-1 do begin
  b:=b or l[0];
  b:= b shl 1;
  l:=pointer(intptr(l)-1);
 end;

 w.cur:=b;
 w.pos:=byte_index;
 w.cur_len:=len;
end;
//############################################################################//
begin
end. 
//############################################################################//

