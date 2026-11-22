"""Add user IDS signatures for SYN flood / SYN scan / XMAS against the protected DMZ and put them in drop for the BKS4 profile."""
import json
from pathlib import Path
from c4_lib import C4Manager,Config
h=Path.home();m=C4Manager(Config(c4_ip='10.1.99.1',c4_password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False));a=m.config_keeper.api;a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
sigs=[
 ('BKS4 TCP SYN flood to DMZ (50 SYN/5s per source)','alert tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"BKS4 TCP SYN flood to DMZ"; flags:S,12; flow:stateless; threshold:type both, track by_src, count 50, seconds 5; classtype:attempted-dos; sid:3900001; rev:1;)','attempted-dos',3900001),
 ('BKS4 TCP SYN port scan to DMZ (10 SYN/60s per source)','alert tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"BKS4 TCP SYN port scan to DMZ"; flags:S,12; flow:stateless; threshold:type both, track by_src, count 10, seconds 60; classtype:network-scan; sid:3900002; rev:1;)','network-scan',3900002),
 ('BKS4 TCP XMAS scan to DMZ','alert tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"BKS4 TCP XMAS scan to DMZ"; flags:FPU,12; flow:stateless; classtype:network-scan; sid:3900003; rev:1;)','network-scan',3900003),
]
assert m.open();b=a.get_obj_url(m.config_keeper.uuid)
try:
 existing={x['name']:x['uuid'] for x in a.get_from_endpoint(b+'/ipssignature')['data'] if x.get('name','').startswith('BKS4 ')}
 new=[]
 for name,sig,ct,sid in sigs:
  body={'name':name,'signature':sig,'action':'alert','vendor':'BKS4','sid':sid,'rev':1,'proto':'tcp','classtype':ct,'is_enabled':True}
  r=a.put_to_endpoint(b+'/ipssignature/'+existing[name],body) if name in existing else a.post_to_endpoint(b+'/ipssignature',body)
  assert isinstance(r,dict) and 'uuid' in r,r;new.append(r['uuid']);print('signature',name,r['uuid'],flush=True)
 prof=next(x for x in a.get_from_endpoint(b+'/ipsprofile?view=full')['data'] if x['name']=='BKS4-IDS-Alert')
 drop=[x['uuid'] if isinstance(x,dict) else x for x in prof['drop']];alert=[x['uuid'] if isinstance(x,dict) else x for x in prof['alert']]
 drop=sorted(set(drop)|set(new));alert=[x for x in alert if x not in new]
 r=a.put_to_endpoint(b+'/ipsprofile/'+prof['uuid'],{'alert':alert,'drop':drop});assert 'uuid' in r,r
 p2=next(x for x in a.get_from_endpoint(b+'/ipsprofile?view=full')['data'] if x['name']=='BKS4-IDS-Alert')
 print('profile alert',len(p2['alert']),'drop',len(p2['drop']),flush=True)
 for x in a.get_from_endpoint(b+'/ipssignature')['data']:
  if x.get('name','').startswith('BKS4 '):print('check',x.get('sid'),x.get('name'),x.get('is_enabled'),x.get('status'),x.get('errors'),flush=True)
 assert m.save();print('Saved',flush=True)
except Exception:m.cancel();raise
