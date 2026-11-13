#!/usr/bin/env python3
"""Run on ADMIN-LINUX; store a native backup containing secrets outside the repository."""
import importlib.util,os,json,hashlib,urllib.request,urllib.parse,io,tarfile
from pathlib import Path
from datetime import datetime,timezone
os.environ.setdefault('KERIO_URL','https://10.1.99.1:4081/admin/api/jsonrpc/')
os.environ.setdefault('KERIO_PASSWORD_FILE',str(Path.home()/'.bks4-kerio-password'))
spec=importlib.util.spec_from_file_location('api',Path.home()/'bks4-kerio-tools/kerio-api.py')
api=importlib.util.module_from_spec(spec);spec.loader.exec_module(api);k=api.Kerio();k.login()
try:
 info=k.call('Configuration.exportConfig',{'options':{'certificates':True,'dhcpLeases':True,'stats':False}})['fileDownload']
 url=urllib.parse.urljoin(k.url,info['url']);assert urllib.parse.urlparse(url).netloc==urllib.parse.urlparse(k.url).netloc
 data=k.opener.open(urllib.request.Request(url,headers={'X-Token':k.token}),timeout=30).read()
 assert len(data)==info['length']
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:assert archive.getmembers()
 directory=Path.home()/'bks4-backups-private';directory.mkdir(mode=0o700,exist_ok=True)
 path=directory/('kerio-native-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')+'.tar.gz')
 fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'wb') as stream:stream.write(data)
 print(json.dumps({'path':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}))
finally:k.call('Session.logout')
