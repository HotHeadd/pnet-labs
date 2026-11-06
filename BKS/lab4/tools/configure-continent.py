#!/usr/bin/env python3
"""Configure the isolated BKS4 appliance with the vendor's c4_lib.
Run on ADMIN-LINUX. Credentials and session cookies stay outside the repository.
"""
from pathlib import Path
import json,pickle
from c4_lib import ApiConnector
home=Path.home()
a=ApiConnector(ip='10.1.99.1',password=(home/'.bks4-continent-admin-password').read_text().strip(),verbosity=False)
a.session.trust_env=False
cookie=home/'bks4-c4-cookies.private'
if cookie.exists():a.session.cookies.update(pickle.loads(cookie.read_bytes()))
orig=a.session.request
a.session.request=lambda *args,**kw:orig(*args,timeout=120,**kw)
u=(home/'bks4-draft-id').read_text().strip();base=a.get_obj_url(u)
assert a.config_lock_user().get('is_current_session'),'Configuration lock belongs to another session'
node='2b799461-dece-47a6-b4f4-3debee8560d8'
def check(r,label):
 print(label,json.dumps(r,ensure_ascii=False),flush=True)
 if not isinstance(r,dict) or not ('uuid' in r or r.get('status')=='ok'):raise RuntimeError(label+' failed')
 return r.get('uuid')
def put(t,uid,body):return check(a.put_to_endpoint(base+'/'+t+'/'+uid,body),'Update '+t)
def ensure(t,name,body):
 found=next((x for x in a.get_from_endpoint(base+'/'+t).get('data',[]) if x.get('name')==name),None)
 if found:
  put(t,found['uuid'],dict(body,name=name));return found['uuid']
 return check(a.post_to_endpoint(base+'/'+t,dict(body,name=name)),'Create '+t+' '+name)
net={}
for name,ip in {'LAN':'10.1.10.0/24','Guests':'10.1.10.42','DMZ':'10.1.50.0/26','DMZ_WEB':'10.1.50.10','MGMT':'10.1.99.0/24','ADMIN_WIN':'10.1.99.20','ADMIN_LINUX':'10.1.99.10','WAN_TEST':'192.168.100.1','WAN_PUBLIC':'192.168.100.2','ANY_NETWORK':'0.0.0.0/0'}.items():
 net[name]=ensure('netobject','BKS4_'+name,{'ip':ip,'description':'BKS4 variant 6'})
services={}
for name,proto,dst in [('HTTP',6,'80'),('HTTPS',6,'443'),('SSH',6,'22'),('DNS_UDP',17,'53'),('DNS_TCP',6,'53'),('NTP',17,'123'),('ICMP',1,None)]:
 fields={'proto':proto}
 if proto in (6,17):fields.update(src=None,dst=dst)
 services[name]=ensure('service','BKS4_'+name,fields)
# A route destination is a network-object reference in this API.
r=a.put_to_endpoint(base+'/cgw/'+node+'?view=routes',{'routes':[{'dst':net['ANY_NETWORK'],'gateway':'192.168.100.1'}]})
print('Default route draft',json.dumps(r,ensure_ascii=False),flush=True)
# Explicit rules; unlisted traffic is denied and logged at the end.
web=[services['HTTP'],services['HTTPS']]
rules=[
 ('BKS4-Deny-DMZ-to-LAN',['DMZ'],['LAN'],[], 'block'),
 ('BKS4-Admin-to-DMZ',['MGMT'],['DMZ_WEB'],web+[services['SSH'],services['ICMP']],'pass'),
 ('BKS4-LAN-to-DMZ-Web',['LAN'],['DMZ_WEB'],web,'pass'),
 ('BKS4-WAN-Published-Web',[],['DMZ_WEB'],web,'pass'),
 ('BKS4-Admin-Web',['MGMT'],[],web,'pass'),
 ('BKS4-LAN-Web',['LAN'],[],web,'pass'),
 ('BKS4-DNS-NTP',['LAN','DMZ','MGMT'],['WAN_TEST'],[services[x] for x in ['DNS_UDP','DNS_TCP','NTP']],'pass'),
 ('BKS4-DMZ-Updates',['DMZ'],[],web,'pass'),
 ('BKS4-Default-Deny',[],[],[],'block')]
for name,src,dst,srv,action in rules:
 ensure('fwrule',name,{'type':'fwrule','is_enabled':True,'src':[net[x] for x in src],'dst':[net[x] for x in dst],'service':srv,'rule_action':action,'logging':True,'rule_position':{'last':True},'install_on':[node]})
ensure('natrule','BKS4-Publish-DMZ-Web',{'type':'natrule','is_enabled':True,'src':[],'dst':[net['WAN_PUBLIC']],'service':web,'nat_type':'dnat','address_type':'netobject','value':net['DMZ_WEB'],'port_type':None,'port_value':None,'rule_position':{'first':True},'install_on':[node]})
ensure('natrule','BKS4-Source-NAT',{'type':'natrule','is_enabled':True,'src':[net[x] for x in ['LAN','DMZ','MGMT']],'dst':[],'service':[],'nat_type':'masquerade','address_type':None,'value':None,'port_type':None,'port_value':None,'rule_position':{'last':True},'install_on':[node]})
# Save cookie context for the next step; do not install before inspecting the draft.
cookie.write_bytes(pickle.dumps(a.session.cookies));cookie.chmod(0o600)
for tail in ['/cgw/'+node+'?view=routes','/fwrule?view=full','/natrule?view=full']:
 r=a.get_from_endpoint(base+tail);p=home/('bks4-draft-'+tail.split('/')[1]+'.json');p.write_text(json.dumps(r));p.chmod(0o600)
 print('Draft review',tail,json.dumps(r,ensure_ascii=False)[:5000],flush=True)
print('Draft prepared; not committed or installed.')
