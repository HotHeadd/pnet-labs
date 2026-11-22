from pathlib import Path
import hashlib,json,os,time
from c4_lib import ApiConnector
os.umask(0o077)
h=Path.home();a=ApiConnector(ip='10.1.99.1',password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False);a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
name='BKS4-before-restore-20261106';dest=h/'bks4-backups-private';dest.mkdir(exist_ok=True,mode=0o700)
existing=[x for x in a.get_from_endpoint(a._base_url_objects+'/backup').get('data',[]) if x.get('name')==name]
assert not existing,'Backup with this name already exists; inspect it instead of creating another'
assert a.config_lock_user().get('admin') is None
assert a.set_config_lock().get('status')=='ok'
r=a.post_to_endpoint(a._base_url_server+'/backup',{'name':name,'description':'BKS4 variant 6 before controlled restore check','components':['cdc','cgw','monitoring']})
print('Backup task',json.dumps(r),flush=True);assert r.get('status')=='ok' and len(r.get('tasks',[]))==1
(h/'bks4-native-backup-task.json').write_text(json.dumps(r))
for i in range(180):
 try:t=a.get_task(r['tasks'][0])['data'][0]
 except Exception as e:print('Transient task status error',type(e).__name__,flush=True);time.sleep(5);continue
 if i%6==0 or t['status'] not in ['running','staged']:print('Backup',t['status'],t['processed'],t.get('messages'),flush=True)
 if t['status'] not in ['running','staged']:
  assert t['status']=='done' and t['processed']==100;break
 time.sleep(5)
else:raise TimeoutError('Query same backup task; do not resubmit')
a.free_config_lock()
items=[x for x in a.get_from_endpoint(a._base_url_objects+'/backup').get('data',[]) if x.get('name')==name];assert len(items)==1
obj=items[0];filename=obj['filename'];assert filename==Path(filename).name
p=dest/filename
with a.session.get(a._base_url_server+'/download-backup/'+filename,stream=True) as response:
 response.raise_for_status()
 with p.open('wb') as f:
  for chunk in response.iter_content(1024*1024):f.write(chunk)
p.chmod(0o600);meta={'name':name,'uuid':obj['uuid'],'filename':filename,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()};(h/'bks4-native-backup-metadata.json').write_text(json.dumps(meta));print(json.dumps(meta),flush=True)
