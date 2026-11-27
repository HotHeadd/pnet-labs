#!/usr/bin/env python3
"""На PNET-хосте: передать гостям только нужные параметры, без вывода значений."""
import json
from pathlib import Path
import shlex
import subprocess

root=Path('/root/sa7-private')
data=json.loads((root/'secrets.json').read_text())
selected={'gw':[], 'im':[x for x in data if x not in ('livekit_key','livekit_secret','flask_secret')],
    'rtc':['livekit_key','livekit_secret','rtc_oidc_client_secret','flask_secret'],
    'workstation':['alice','bob','charlie','kc_admin_pw','of_admin_pw']}
def upload(address,path,content,mode='600'):
    command='sudo -n sh -c '+shlex.quote('umask 077; mkdir -p '+str(Path(path).parent)+
        '; cat > '+path+'; chmod '+mode+' '+path)
    r=subprocess.run(['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes',
        '-o','StrictHostKeyChecking=accept-new','-o','ConnectTimeout=8',
        'labadmin@'+address,command],input=content,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode:
        raise SystemExit('Upload failed: '+address+' '+path)
for node,last in [('gw',241),('im',242),('rtc',243),('workstation',244)]:
    address='192.168.15.'+str(last)
    if selected[node]:
        upload(address,'/root/sa7-private/secrets.json',json.dumps({k:data[k] for k in selected[node]}).encode())
    upload(address,'/usr/local/share/ca-certificates/sa7-ca.crt',(root/'pki/ca.crt').read_bytes(),'644')
    if node in ('gw','im'):
        for suffix in ('crt','key'):
            upload(address,'/opt/sa7/tls/'+node+'.'+suffix,(root/'pki'/(node+'.'+suffix)).read_bytes())
        upload(address,'/opt/sa7/tls/ca.crt',(root/'pki/ca.crt').read_bytes(),'644')
    r=subprocess.run(['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes',
        'labadmin@'+address,'sudo -n update-ca-certificates'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode: raise SystemExit('CA install failed: '+node)
    print(node,'private files and trusted CA delivered',flush=True)
