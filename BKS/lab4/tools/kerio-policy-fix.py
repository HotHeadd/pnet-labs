"""Kerio policy changes with the webadmin's confirm sequence: set -> Session.getConfigTimestamp -> Session.confirmConfig(list).
Without the real timestamp list the change stays pending and is rolled back when the session ends."""
import importlib.util,json,os,copy,urllib.request
os.environ['KERIO_URL']='https://10.1.99.1:4081/admin/api/jsonrpc/';os.environ['KERIO_PASSWORD_FILE']=os.path.expanduser('~/.bks4-kerio-password')
s=importlib.util.spec_from_file_location('k','/tmp/kerio-api.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class K(m.Kerio):
 def call(self,method,params=None):
  self.n+=1;headers={'Content-Type':'application/json'}
  if self.token:headers['X-Token']=self.token
  r=json.loads(self.opener.open(urllib.request.Request(self.url,data=json.dumps({'jsonrpc':'2.0','id':self.n,'method':method,'params':params or {}}).encode(),headers=headers),timeout=120).read())
  if 'error' in r:raise RuntimeError(json.dumps(r['error'],ensure_ascii=False))
  return r.get('result',{})
def svc(proto,ports,cmp='Equal'):return {'definedService':False,'service':{'id':'','name':'','isGroup':False,'invalid':False},'protocol':proto,'port':{'comparator':cmp,'ports':ports}}
def sel(entries):return {'type':'RuleSelectedEntities','entries':entries}
k=K();k.login()
rules=k.call('TrafficPolicy.get')['list'];defaultRule=k.call('TrafficPolicy.getDefaultRule')['rule']
want={'BKS4-LAN-DMZ-Web':sel([svc(6,[80]),svc(6,[443])]),'BKS4-Protected-DNS-NTP':sel([svc(17,[53]),svc(6,[53]),svc(17,[123])]),'BKS4-DMZ-DNS-NTP':sel([svc(17,[53]),svc(6,[53]),svc(17,[123])]),'BKS4-Firewall-DNS-NTP':sel([svc(17,[53]),svc(6,[53]),svc(17,[123])])}
for x in rules:
  if x['name'] in want:x['service']=want[x['name']]
  if x['name']=='BKS4-LAN-DMZ-Web':x['description']='BKS4 variant 6: LAN reaches the DMZ web server only on 80/443'
if not any(x['name']=='BKS4-Deny-Admin-Outside-Management' for x in rules):
  new=copy.deepcopy(next(x for x in rules if x['name']=='BKS4-Deny-Untrusted-Management'));new['id']='';new['name']='BKS4-Deny-Admin-Outside-Management';new['description']='BKS4 variant 6: administration ports of the firewall only from Management'
  new['destination']={'type':'RuleSelectedEntities','firewall':True,'entities':[]};new['service']=sel([svc(6,[4080]),svc(6,[4081])]);new['logEnabled']=[False,True]
  rules.insert(1,new)
print('set',json.dumps(k.call('TrafficPolicy.set',{'rules':rules,'defaultRule':defaultRule}))[:300])
ts=k.call('Session.getConfigTimestamp');print('timestamps',json.dumps(ts)[:300])
print('confirm',json.dumps(k.call('Session.confirmConfig',ts)))
print('timestamps after',json.dumps(k.call('Session.getConfigTimestamp'))[:200])
k.call('Session.logout')
k2=K();k2.login();rules=k2.call('TrafficPolicy.get')['list'];print('FRESH SESSION rules',len(rules))
for i,x in enumerate(rules,1):
  srv=x['service'];print(i,x['action'],x['name'],[(e['protocol'],e['port']['ports']) for e in srv['entries']] if srv['type']!='RuleAny' else 'Any')
json.dump({'rules':rules,'defaultRule':k2.call('TrafficPolicy.getDefaultRule')['rule']},open(os.path.expanduser('~/kerio-traffic-policy.json'),'w'),ensure_ascii=False,indent=1)
