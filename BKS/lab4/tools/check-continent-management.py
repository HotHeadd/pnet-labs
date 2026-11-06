#!/usr/bin/env python3
"""Read-only authenticated access check. Password from stdin, never stored.
The same credentials are tested from each data segment; no configuration writes.
"""
import sys,json
from c4_lib import ApiConnector
from requests.adapters import HTTPAdapter
class BindAddress(HTTPAdapter):
 def init_poolmanager(self,connections,maxsize,block=False,**kw):
  return super().init_poolmanager(connections,maxsize,block,source_address=(sys.argv[1],0),**kw)
a=ApiConnector(ip='10.1.99.1',password=sys.stdin.read().strip(),verbosity=False);a.session.trust_env=False;a.session.mount('https://',BindAddress())
try:
 r=a.session.get(a._base_url_objects+'/config',timeout=10)
 print('Data source:',sys.argv[1]);print('HTTP status:',r.status_code)
 try:
  data=r.json()
  if r.status_code==200:print('Authenticated read: configurations',len(data.get('data',[])))
  else:print('Denial:',json.dumps(data,ensure_ascii=False))
 except ValueError:print('Response prefix:',r.text[:200])
except Exception as e:print('Data source:',sys.argv[1]);print('Transport result:',type(e).__name__,str(e)[:220])
