#!/usr/bin/env python3
"""Use the appliance's existing user portal from a bound lab source address.
The isolated lab portal uses its private CA; passwords never enter command arguments.
"""
import datetime,getpass,http.client,json,ssl,sys
from http.cookies import SimpleCookie
from pathlib import Path
from urllib.parse import urlsplit
source,user=sys.argv[1:3];mode=sys.argv[3] if len(sys.argv)>3 else 'login'
password=(getpass.getpass('Portal password: ') if sys.stdin.isatty() else sys.stdin.read().strip()) if mode=='login' else None
body=json.dumps({'login':user,'password':password,'client':'captive'}) if mode=='login' else ''
path='/user-auth/user-auth' if mode=='login' else '/user-auth/user-exit'
cookie_file=Path.home()/('.bks4-portal-'+source+'-cookies.private')
cookies=json.loads(cookie_file.read_text()) if cookie_file.exists() else {}
def request(method,path,body=None):
 c=http.client.HTTPSConnection('10.1.10.1',443,timeout=20,source_address=(source,0),context=ssl._create_unverified_context())
 headers={'Host':'auth.bks4.test','Origin':'https://auth.bks4.test','Referer':'https://auth.bks4.test/user-auth/login','Content-Type':('application/x-www-form-urlencoded; charset=UTF-8' if path.endswith('user-exit') else 'application/json'),'X-Requested-With':'XMLHttpRequest'}
 if cookies:headers['Cookie']='; '.join(k+'='+v for k,v in cookies.items())
 c.request(method,path,body=body,headers=headers);r=c.getresponse();data=r.read()
 for k,v in r.getheaders():
  if k.lower()=='set-cookie':
   parsed=SimpleCookie();parsed.load(v)
   for name,m in parsed.items():cookies[name]=m.value
 cookie_file.write_text(json.dumps(cookies));cookie_file.chmod(0o600)
 status=r.status;c.close();return status,data
# Follow the same initial page and cookie handling as the native browser form.
request('GET','/user-auth/login')
status,data=request('POST',path,body)
result=json.loads(data)
if isinstance(result,str):result=json.loads(result)
print(json.dumps({'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'user':user,'operation':mode,'http_status':status,'status':result.get('status'),'message':result.get('message') if result.get('status')!='success' else None},ensure_ascii=False))
assert status==200 and result.get('status')=='success','Portal authentication was not confirmed'
u=urlsplit(result.get('url',''))
if result.get('url') and u.hostname in (None,'auth.bks4.test','10.1.10.1'):
 request('GET',u.path+('?' + u.query if u.query else ''))
