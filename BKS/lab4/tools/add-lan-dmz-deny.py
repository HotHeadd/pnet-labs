"""Add explicit LAN->DMZ deny for everything except the web rules (blocks at SYN, before guest DPI), set GeoIP rule state, reorder, save, install."""
from pathlib import Path
import sys,json
from c4_lib import C4Manager,Config
geo_enabled=sys.argv[1]=='on';order=[l.strip() for l in Path(sys.argv[2]).read_text().splitlines() if l.strip()]
h=Path.home();m=C4Manager(Config(c4_ip='10.1.99.1',c4_password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False));a=m.config_keeper.api;a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
assert m.open();b=a.get_obj_url(m.config_keeper.uuid)
try:
 rules={x['name']:x for x in a.get_from_endpoint(b+'/fwrule?view=full')['data']}
 if 'BKS4-Deny-LAN-to-DMZ-Other' not in rules:
  lan=next(x for x in rules['BKS4-LAN-HTTP-AV']['src'])['uuid'];dmz=next(x for x in rules['BKS4-Deny-DMZ-to-LAN']['src'])['uuid']
  body={'name':'BKS4-Deny-LAN-to-DMZ-Other','src':[lan],'dst':[dmz],'service':[],'applications':[],'rule_action':'block','logging':True,'is_enabled':True,'install_on':rules['BKS4-Deny-DMZ-to-LAN']['install_on'] if isinstance(rules['BKS4-Deny-DMZ-to-LAN'].get('install_on'),list) and rules['BKS4-Deny-DMZ-to-LAN']['install_on'] and not isinstance(rules['BKS4-Deny-DMZ-to-LAN']['install_on'][0],dict) else [x['uuid'] for x in rules['BKS4-Deny-DMZ-to-LAN']['install_on']],'rule_position':{'last':True},'description':'LAN reaches DMZ only through the web rules above; other services are dropped at SYN and logged, before application control.'}
  r=a.post_to_endpoint(b+'/fwrule',body);assert 'uuid' in r,r;print('created',r['uuid'],flush=True)
  rules={x['name']:x for x in a.get_from_endpoint(b+'/fwrule?view=full')['data']}
 missing=set(rules)-set(order);extra=set(order)-set(rules);assert not missing and not extra,(missing,extra)
 for n in order:
  r=a.put_to_endpoint(b+'/fwrule/'+rules[n]['uuid'],{'rule_position':{'last':True}});assert 'uuid' in r,r
 r=a.put_to_endpoint(b+'/fwrule/'+rules['BKS4-GeoIP-Block-US-to-DMZ']['uuid'],{'is_enabled':geo_enabled});assert 'uuid' in r,r
 print('GeoIP rule enabled =',geo_enabled,flush=True)
 for x in a.get_from_endpoint(b+'/fwrule?view=full')['data']:print(' ',x['is_enabled'],x['rule_action'],x['name'])
 assert m.save();print('Saved',flush=True)
except Exception:m.cancel();raise
