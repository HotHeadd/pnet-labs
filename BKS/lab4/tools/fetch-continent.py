#!/usr/bin/env python3
"""Fetch selected files from the MEPhI public archive without downloading all VMs."""
import io,struct,zipfile,http.cookiejar,urllib.request
from pathlib import Path
TOKEN='gAo2R38AwgaQPcF'
ROOT='https://box.digital.mephi.ru'
DEST=Path('/opt/unetlab/bks4-preparation/distrib')
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
 opener.open(ROOT+'/s/'+TOKEN,timeout=30).read()
 url=ROOT+'/public.php/dav/files/'+TOKEN+'/421.zip'
 def get(a,b):
  with opener.open(urllib.request.Request(url,headers={'Range':'bytes=%d-%d'%(a,b)}),timeout=120) as r:
   if r.status!=206:raise RuntimeError('Range not supported')
   return r.read()
 req=opener.open(urllib.request.Request(url,headers={'Range':'bytes=-131072'}),timeout=60)
 shift=int(req.headers['Content-Range'].split()[1].split('-')[0]);tail=req.read();outer=zipfile.ZipFile(io.BytesIO(tail))
 def offset(i):
  o=i.header_offset+shift;h=struct.unpack('<4s5H3I2H',get(o,o+29));return o+30+h[-2]+h[-1]
 entry=outer.getinfo('421/Distrib.zip');start=offset(entry)
 class RangeFile(io.RawIOBase):
  def __init__(self):self.pos=0
  def tell(self):return self.pos
  def seekable(self):return True
  def seek(self,n,w=0):self.pos=n if w==0 else self.pos+n if w==1 else entry.file_size+n;return self.pos
  def read(self,n=-1):
   n=min(n if n>=0 else entry.file_size-self.pos,entry.file_size-self.pos)
   if not n:return b''
   b=get(start+self.pos,start+self.pos+n-1);self.pos+=len(b);return b
 inner=zipfile.ZipFile(RangeFile())
 names=['Distrib/MS/Rus/CCM.msi','Distrib/MS/Rus/Data1.cab','Distrib/MS/Rus/setup.exe','Distrib/MS/Rus/VersionInfo.txt','Distrib/IPS-4.2.1.53.tgz.signed','Distrib/docs/Continent - Firewall - Admin Guide (5).pdf','Distrib/docs/Continent - Deployment - Admin Guide (2).pdf']
 for name in names:
  dest=DEST/Path(name).name
  if dest.exists():print('Already exists',dest,flush=True);continue
  dest.write_bytes(inner.read(name));print('Saved',dest,dest.stat().st_size,flush=True)
 for i in outer.infolist():
  if i.filename.startswith('421/lic_2026/') and not i.is_dir():
   dest=DEST/'lic_2026'/Path(i.filename).name;dest.parent.mkdir(exist_ok=True)
   if not dest.exists():dest.write_bytes(get(offset(i),offset(i)+i.compress_size-1))
 print('License files downloaded; contents not printed',flush=True)
if __name__=='__main__':main()
