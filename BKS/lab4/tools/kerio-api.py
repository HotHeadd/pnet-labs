#!/usr/bin/env python3
"""Kerio administration through a local SSH tunnel; secrets stay outside the repo."""
import http.cookiejar,json,os,ssl,sys,urllib.request
from pathlib import Path
class Kerio:
 def __init__(self,url=None):
  self.url=url or os.environ.get('KERIO_URL','https://localhost:14081/admin/api/jsonrpc/')
  self.opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=ssl._create_unverified_context()),urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
  self.token=None;self.n=0
 def call(self,method,params=None):
  self.n+=1;headers={'Content-Type':'application/json'}
  if self.token:headers['X-Token']=self.token
  r=json.loads(self.opener.open(urllib.request.Request(self.url,data=json.dumps({'jsonrpc':'2.0','id':self.n,'method':method,'params':params or {}}).encode(),headers=headers),timeout=20).read())
  if 'error' in r:raise RuntimeError(json.dumps(r['error'],ensure_ascii=False))
  return r.get('result',{})
 def login(self):
  p=Path(os.environ.get('KERIO_PASSWORD_FILE','/tmp/bks4-kerio-password'))
  pw=p.read_text().strip() if p.exists() else ''
  self.token=self.call('Session.login',{'userName':'Admin','password':pw,'application':{'name':'BKS4 lab','vendor':'MEPhI','version':'1.0'}})['token']
if __name__=='__main__':
 k=Kerio();k.login();r=k.call(sys.argv[1],json.loads(sys.argv[2]) if len(sys.argv)>2 else {})
 print(json.dumps(r,ensure_ascii=False,indent=2))
