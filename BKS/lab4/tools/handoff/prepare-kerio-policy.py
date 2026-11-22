import copy,json
from pathlib import Path
old=json.loads(Path('/tmp/bks4-policy.json').read_text())['list']
base=copy.deepcopy(old[0]);entity=copy.deepcopy(old[3]['source']['entities'][0]);rules=[]
def host(ip):
 e=copy.deepcopy(entity);e.update(type='TrafficEntityHost',host=ip,addr1='',addr2='');return e
def net(ip,mask):
 e=copy.deepcopy(entity);e.update(type='TrafficEntityNetwork',host='',addr1=ip,addr2=mask);return e
def cond(es=(),fw=False):return dict(type='RuleSelectedEntities',firewall=fw,entities=list(es))
def ports(proto,*ps):return dict(definedService=False,service=dict(id='',name='',isGroup=False,invalid=False),protocol=proto,port=dict(comparator=('Any' if not ps else 'Equal' if len(ps)==1 else 'List'),ports=list(ps)))
anyc=dict(type='RuleAny',firewall=False,entities=[])
wan=copy.deepcopy(entity);wan['interfaceCondition']['type']='InterfaceInternet'
mgmt=cond([net('10.1.99.0','255.255.255.0')]);lan=cond([net('10.1.10.0','255.255.255.0')]);dmz=cond([net('10.1.50.0','255.255.255.192')]);protected=cond(mgmt['entities']+lan['entities'])
fw=cond(fw=True);webhost=cond([host('10.1.50.10')]);wantest=cond([host('192.168.100.1')]);internet=cond([wan])
web=[ports(6,80,443)];dnsntp=[ports(6,53),ports(17,53,123)]
def rule(name,src,dst,services=None,action='Allow',snat=False,dnat=None):
 r=copy.deepcopy(base);r.update(id='',name='BKS4-'+name,description='BKS4 variant 6',source=src,destination=dst,service=dict(type='RuleSelectedEntities',entries=services) if services is not None else dict(type='RuleAny',entries=[]),action=action,logEnabled=[False,True],ipVersion='Ipv4',enableSourceNat=snat,natMode='NatDefault',enableDestinationNat=bool(dnat),inspector='default')
 if dnat:r.update(translatedHost='10.1.50.10',translatedPort=dict(enabled=True,value=dnat))
 rules.append(r)
rule('Management',mgmt,fw,[ports(6,4081,443),ports(17,161),ports(1)])
rule('Deny-Untrusted-Management',cond(lan['entities']+dmz['entities']+[wan]),mgmt,action='Drop')
rule('Deny-DMZ-LAN',dmz,lan,action='Drop')
rule('Admin-DMZ',mgmt,webhost,[ports(6,22,80,443),ports(1)])
rule('LAN-DMZ-Web',lan,webhost,web)
rule('Publish-HTTP',internet,fw,[ports(6,8080)],dnat=80)
rule('Publish-HTTPS',internet,fw,[ports(6,8443)],dnat=443)
rule('Protected-DNS-NTP',protected,wantest,dnsntp,snat=True)
rule('Protected-Web',protected,internet,web,snat=True)
rule('DMZ-DNS-NTP',dmz,wantest,dnsntp,snat=True)
rule('DMZ-Updates',dmz,internet,web,snat=True)
rule('Firewall-DNS-NTP',fw,wantest,dnsntp)
rule('Firewall-Web',fw,internet,web)
rule('Firewall-ICMP',fw,wantest,[ports(1)])
rule('Internal-ICMP-Gateway',protected,fw,[ports(1)])
rule('Syslog',fw,cond([host('10.1.99.10')]),[ports(6,514),ports(17,514,162)])
default=copy.deepcopy(base);default.update(id='',name='Block other communication',source=anyc,destination=anyc,service=dict(type='RuleAny',entries=[]),action='Drop',logEnabled=[False,True],enableSourceNat=False,enableDestinationNat=False,ipVersion='IpAll',inspector='default')
Path('/tmp/bks4-kerio-base-policy.json').write_text(json.dumps(dict(rules=rules,defaultRule=default),indent=2))
print('Prepared',len(rules),'rules plus default deny; no appliance changes yet.')
