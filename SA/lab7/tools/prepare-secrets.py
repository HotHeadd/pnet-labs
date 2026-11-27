#!/usr/bin/env python3
"""На PNET-хосте: закрытые параметры и УЦ SA7. Секреты не выводятся."""
import json
import os
from pathlib import Path
import secrets
import subprocess

os.umask(0o077)
root=Path('/root/sa7-private')
root.mkdir(exist_ok=True)
names=['ldap_admin_pw','ldap_bind_pw','alice','bob','charlie','kc_admin_pw',
       'kc_db_pw','synapse_db_pw','openfire_db_pw','of_admin_pw',
       'of_keystore_pw','synapse_registration_secret','synapse_oidc_client_secret',
       'rtc_oidc_client_secret','livekit_secret','flask_secret']
datafile=root/'secrets.json'
if not datafile.exists():
    values={name:secrets.token_urlsafe(24) for name in names}
    values['livekit_key']='sa7key'
    datafile.write_text(json.dumps(values,indent=2)+'\n')
    datafile.chmod(0o600)
pki=root/'pki'
pki.mkdir(exist_ok=True)
def run(args):
    r=subprocess.run(['openssl']+args,cwd=str(pki),stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode:
        raise SystemExit('OpenSSL step failed: '+args[0])
if not (pki/'ca.crt').exists():
    run(['req','-x509','-nodes','-newkey','rsa:3072','-days','365',
        '-keyout','ca.key','-out','ca.crt','-subj','/CN=SA7 Lab CA',
        '-addext','basicConstraints=critical,CA:TRUE',
        '-addext','keyUsage=critical,keyCertSign,cRLSign'])
for node,dns in [('gw',['xmpp.lab.local','xmpp-tcp.lab.local','matrix.lab.local',
                         'rtc.lab.local','sso.lab.local']),
                 ('im',['xmpp.lab.local','xmpp-tcp.lab.local','directory.sa7.test','im.sa7.test'])]:
    if (pki/(node+'.crt')).exists():
        continue
    (pki/(node+'.ext')).write_text('subjectAltName='+','.join('DNS:'+x for x in dns)+'\n'
        'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n'
        'extendedKeyUsage=serverAuth\n')
    run(['req','-nodes','-newkey','rsa:2048','-keyout',node+'.key',
         '-out',node+'.csr','-subj','/CN='+dns[0]])
    run(['x509','-req','-in',node+'.csr','-CA','ca.crt','-CAkey','ca.key',
         '-CAcreateserial','-days','365','-out',node+'.crt','-extfile',node+'.ext'])
print('SA7 private parameters and CA prepared; no secrets printed')
