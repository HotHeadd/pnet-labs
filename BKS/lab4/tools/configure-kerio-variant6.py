"""Configure native groups and application policy for BKS4 variant 6.
Run beside kerio-api.py on ADMIN-LINUX; passwords remain in private files.
"""
import copy
import importlib.util
import json
import os
from pathlib import Path

os.environ.setdefault('KERIO_URL', 'https://10.1.99.1:4081/admin/api/jsonrpc/')
os.environ.setdefault('KERIO_PASSWORD_FILE', str(Path.home()/'.bks4-kerio-password'))
spec = importlib.util.spec_from_file_location('api', Path(__file__).with_name('kerio-api.py'))
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)
k = api.Kerio()
k.login()
query = {'domainId':'local','query':{'start':0,'limit':-1,'orderBy':[], 'conditions':[], 'combining':'And'}}

def confirm():
    assert k.call('Session.confirmConfig',k.call('Session.getConfigTimestamp'))['confirmed']

def checked(method, params):
    result = k.call(method,params)
    assert not result.get('errors'), (method,result)
    print(method, 'errors=[]', flush=True)
    return result

original = k.call('Users.get',query)['list']
admin = next(u for u in original if u['credentials']['userName']=='Admin')
rights = {name:False for name in admin['data']['rights']}
rights['useP2p'] = True  # distinguish the content policy from a user-right denial
existing = {g['name']:g for g in k.call('UserGroups.get',query)['list']}
for name in ['Guests','Administrators']:
    if name not in existing:
        checked('UserGroups.create',{'domainId':'local','groups':[{
            'id':'','name':name,'description':'BKS4 variant 6',
            'rights':rights,'members':[]}]})
confirm()
groups = {g['name']:g for g in k.call('UserGroups.get',query)['list']}

def ref(name):
    return {'id':groups[name]['id'],'name':name,'isGroup':True,'domainName':''}

existing_users = {u['credentials']['userName']:u for u in k.call('Users.get',query)['list']}
for name,group,ip,pwfile in [
    ('labguest','Guests','10.1.10.42','.bks4-labguest-password'),
    ('lab-admin','Administrators','10.1.99.10','.bks4-lab-admin-password')]:
    user = copy.deepcopy(existing_users.get(name, admin))
    user.update(id=existing_users.get(name,{}).get('id',''),externalId='',
                fullName='BKS4 '+group,description='Automatic lab identity for '+ip,
                email='',authType='Internal',localEnabled=True,adEnabled=False,useTemplate=False)
    user['credentials']={'userName':name,'password':(Path.home()/pwfile).read_text().strip(),'passwordChanged':True}
    user['data']['rights']=copy.deepcopy(rights)
    user['autoLogin']={'macAddresses':{'enabled':False,'value':[]},
                       'addresses':{'enabled':True,'value':[ip]},
                       'addressGroup':{'enabled':False,'id':'','name':''}}
    user['groups']=[ref(group)]
    user['totpConfigured']=False
    if name in existing_users:
        checked('Users.set',{'domainId':'local','userIds':[user['id']],'details':user})
    else:
        checked('Users.create',{'domainId':'local','users':[user]})
confirm()

categories=k.call('ContentFilter.getContentApplicationList')['categories']
wanted={'Chat','Instant Messenger','Peer-to-Peer','File Transfer','Text Messaging & SMS'}
ids=sorted({x['id'] for x in categories if x['subGroup'] in wanted})
assert 1000687 in ids and 1000061 in ids
old=k.call('ContentFilter.get')['list']
template=copy.deepcopy(old[0])

def content_rule(name,group,action,applications):
    r=copy.deepcopy(template)
    r.update(id='',name=name,description='BKS4 variant 6',enabled=True,
             action=action,logEnabled=True,skipAvScan=False,skipKeywords=False,skipAuthentication=False)
    r['sourceCondition']={'type':'RuleSelectedEntities','entities':[{
        'type':'SourceConditonEntityUsers','ipAddressGroup':{'id':'','name':'','invalid':False},
        'userType':'SelectedUsers','user':ref(group)}]}
    r['contentCondition']={'type':'RuleAny','entities':[]}
    if applications:
        entity={'type':'ContentConditionEntityApplication','applications':[],
                'value':'','urlType':'ContentEntityUrlWildcard','matchSecured':False,
                'urlGroup':{'id':'','name':'','invalid':False}}
        entity['applications']=applications
        r['contentCondition']={'type':'RuleSelectedEntities','entities':[entity]}
    r['denialCondition']['sendEmail']=False
    return r

rules=[content_rule('BKS4-Administrators-Application-Exception','Administrators','Allow',[]),
       content_rule('BKS4-Guests-Deny-Messaging-FileSharing','Guests','Deny',ids)]
rules += [r for r in old if r['name'] in ['Kerio sites','Updates and MS Windows activation']]
checked('ContentFilter.set',{'rules':rules})
urlcfg=k.call('ContentFilter.getUrlFilterConfig')['config']
urlcfg.update(enabled=True,appidEnabled=True)
k.call('ContentFilter.setUrlFilterConfig',{'config':urlcfg})
confirm()

fw=k.call('TrafficPolicy.get')['list']
fw=[r for r in fw if r['name']!='BKS4-Controlled-App-Tests']
ports=[6667,16667,6881,16881]
# Kerio normalizes a custom port list to its first port: keep one native rule per port.
for port in ports:
    name='BKS4-Controlled-App-Test-'+str(port)
    if any(r['name']==name for r in fw):
        continue
    r=copy.deepcopy(next(x for x in fw if x['name']=='BKS4-Protected-Web'))
    r.update(id='',name=name,description='Owned WAN protocol peer; content policy selects the user',logEnabled=[False,True])
    r['destination']=copy.deepcopy(next(x for x in fw if x['name']=='BKS4-Firewall-DNS-NTP')['destination'])
    r['service']=copy.deepcopy(next(x for x in fw if x['name']=='BKS4-Publish-HTTP')['service'])
    r['service']['entries'][0]['port']['ports']=[port]
    fw.insert(next(i for i,x in enumerate(fw) if x['name']=='BKS4-Protected-Web'),r)
if not any(r['name']=='BKS4-Internal-DNS-Gateway' for r in fw):
    r=copy.deepcopy(next(x for x in fw if x['name']=='BKS4-Internal-ICMP-Gateway'))
    r.update(id='',name='BKS4-Internal-DNS-Gateway',
             description='Protected clients use the internal DNS gateway',logEnabled=[False,True])
    dns=next(e for x in fw if x['name']=='BKS4-Protected-DNS-NTP'
             for e in x['service']['entries'] if e.get('definedService') and e['service']['name']=='DNS')
    r['service']={'type':'RuleSelectedEntities','entries':[copy.deepcopy(dns)]}
    fw.insert(next(i for i,x in enumerate(fw) if x['name']=='BKS4-Internal-ICMP-Gateway')+1,r)
checked('TrafficPolicy.set',{'rules':fw,'defaultRule':k.call('TrafficPolicy.getDefaultRule')['rule']})
confirm()
k.call('Session.logout')
k.login()
actual=k.call('ContentFilter.get')['list']
guest=next(r for r in actual if r['name']=='BKS4-Guests-Deny-Messaging-FileSharing')
assert guest['contentCondition']['entities'][0]['type']=='ContentConditionEntityApplication'
assert sorted(guest['contentCondition']['entities'][0]['applications'])==ids
print('Application IDs verified in fresh session:',len(ids))
print('Content rules:',[(r['name'],r['action']) for r in k.call('ContentFilter.get')['list']])
print('Groups:',[(g['name'],len(g['members'])) for g in k.call('UserGroups.get',query)['list']])
print('Traffic rules:',len(k.call('TrafficPolicy.get')['list']))
k.call('Session.logout')
