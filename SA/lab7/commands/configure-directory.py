#!/usr/bin/env python3
"""На IM: каталог lab.local, LDAPS, три тестовых пользователя и reader."""
import base64
import grp
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

os.umask(0o077)
private=Path('/root/sa7-private')
creds=json.loads((private/'secrets.json').read_text())
pwfile=private/'ldap-admin.pw'
pwfile.write_text(creds['ldap_admin_pw']+'\n')
def run(args,data=None,acceptable=(0,)):
    r=subprocess.run(args,input=data,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode not in acceptable:
        raise RuntimeError(args[0]+': '+r.stderr)
    return r
base='dc=lab,dc=local'
admin='cn=admin,'+base
auth=['-x','-H','ldapi:///','-D',admin,'-y',str(pwfile)]
probe=run(['ldapsearch']+auth+['-b',base,'-s','base','dn'],acceptable=(0,32,49))
if probe.returncode:
    choices='\n'.join(['slapd slapd/no_configuration boolean false',
        'slapd slapd/domain string lab.local','slapd shared/organization string SA7 Lab',
        'slapd slapd/password1 password '+creds['ldap_admin_pw'],
        'slapd slapd/password2 password '+creds['ldap_admin_pw'],
        'slapd slapd/backend select MDB','slapd slapd/purge_database boolean false',
        'slapd slapd/move_old_database boolean true'])+'\n'
    run(['debconf-set-selections'],choices)
    env=dict(os.environ,DEBIAN_FRONTEND='noninteractive')
    r=subprocess.run(['dpkg-reconfigure','-f','noninteractive','slapd'],env=env,
        stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    if r.returncode: raise RuntimeError('slapd reconfigure failed')

def ssha(password):
    salt=os.urandom(8)
    return '{SSHA}'+base64.b64encode(hashlib.sha1(password.encode()+salt).digest()+salt).decode()
def add(dn,attributes):
    p=run(['ldapsearch']+auth+['-b',dn,'-s','base','dn'],acceptable=(0,32))
    if p.returncode==0: return
    run(['ldapadd']+auth,'dn: '+dn+'\n'+attributes+'\n')
for ou in ('people','groups','services'):
    add('ou='+ou+','+base,'objectClass: organizationalUnit\nou: '+ou+'\n')
for user in ('alice','bob','charlie'):
    add('uid='+user+',ou=people,'+base,'objectClass: inetOrgPerson\nuid: '+user+
        '\ncn: '+user.capitalize()+' SA7\nsn: SA7\nmail: '+user+'@lab.local\nuserPassword: '+ssha(creds[user])+'\n')
add('cn=reader,ou=services,'+base,'objectClass: organizationalRole\nobjectClass: simpleSecurityObject\ncn: reader\nuserPassword: '+ssha(creds['ldap_bind_pw'])+'\n')
add('cn=employees,ou=groups,'+base,'objectClass: groupOfNames\ncn: employees\n'+
    ''.join('member: uid='+u+',ou=people,'+base+'\n' for u in ('alice','bob','charlie')))

tls=Path('/etc/ldap/sa7')
tls.mkdir(mode=0o755,exist_ok=True)
for name in ('im.crt','im.key','ca.crt'):
    out=tls/name
    shutil.copyfile('/opt/sa7/tls/'+name,out)
    out.chmod(0o640 if name.endswith('.key') else 0o644)
    os.chown(out,0,grp.getgrnam('openldap').gr_gid)
ldif='dn: cn=config\nchangetype: modify\n'
for key,value in [('olcTLSCertificateFile',str(tls/'im.crt')),
                  ('olcTLSCertificateKeyFile',str(tls/'im.key')),
                  ('olcTLSCACertificateFile',str(tls/'ca.crt'))]:
    ldif+='replace: '+key+'\n'+key+': '+value+'\n-\n'
run(['ldapmodify','-Q','-Y','EXTERNAL','-H','ldapi:///'],ldif)
default=Path('/etc/default/slapd')
text=default.read_text()
text=re.sub(r'^SLAPD_SERVICES=.*$', 'SLAPD_SERVICES="ldap://127.0.0.1/ ldaps:/// ldapi:///"',text,flags=re.M)
default.write_text(text)
subprocess.run(['systemctl','restart','slapd'],check=True)
result=run(['ldapsearch','-x','-H','ldaps://directory.sa7.test','-D',admin,'-y',str(pwfile),
    '-b','ou=people,'+base,'(objectClass=inetOrgPerson)','uid','mail'])
print(result.stdout)
print('LDAPS catalog configured and verified; password values omitted')
