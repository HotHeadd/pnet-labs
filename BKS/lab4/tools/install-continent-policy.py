#!/usr/bin/env python3
"""Install the saved BKS4 policy once and wait for its terminal task status."""
from pathlib import Path
import json,time
from c4_lib import ApiConnector
h=Path.home();a=ApiConnector(ip='10.1.99.1',password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False);a.session.trust_env=False;orig=a.session.request;a.session.request=lambda *x,**k:orig(*x,timeout=180,**k)
r=a.install_policy_cgw(['1000']);print('Install',r,flush=True);assert r.get('status')=='ok' and len(r.get('tasks',[]))==1
(h/'bks4-last-policy-task.json').write_text(json.dumps(r))
for i in range(180):
 try:t=a.get_task(r['tasks'][0])['data'][0]
 except Exception as e:
  print('Task status read interrupted:',type(e).__name__,'; polling the same task again',flush=True)
  time.sleep(5);continue
 if i%6==0 or t['status'] not in ['running','staged']:print('Task',t['uuid'],t['status'],t['processed'],t.get('messages'),flush=True)
 if t['status'] not in ['running','staged']:
  assert t['status']=='done' and t['processed']==100;break
 time.sleep(5)
else:raise TimeoutError('Poll ended; query same task, do not resubmit')
