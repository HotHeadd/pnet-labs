"""Restore full guest application-control set: IRC, Jabber, BitTorrent + categories Chat, FileSharing; any destination."""
from pathlib import Path
import json
from c4_lib import C4Manager,Config
h=Path.home();m=C4Manager(Config(c4_ip='10.1.99.1',c4_password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False));a=m.config_keeper.api;a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
assert m.open();b=a.get_obj_url(m.config_keeper.uuid)
apps=['bcaf3e0d-b180-4451-83c1-6a1b85280fc8','a0242258-b93e-448c-891e-752334633ef6','b8d486ef-c1ef-44f4-9826-7b34d575122c','2b80c8a8-8030-4fd8-a126-c8b8a2f4cace','141a2c66-51fb-477d-a66a-61386874719a']
try:
 x=next(x for x in a.get_from_endpoint(b+'/fwrule')['data'] if x['name']=='BKS4-Guests-Block-Messengers-P2P')
 r=a.put_to_endpoint(b+'/fwrule/'+x['uuid'],{'applications':apps,'dst':[],'service':[],'is_enabled':True,'logging':True});assert 'uuid' in r,r
 full=a.get_from_endpoint(b+'/fwrule/'+x['uuid']+'?view=full')['data'][0]
 print('applications now:',[y.get('name') for y in full['applications']],'dst',full['dst'],flush=True)
 assert m.save();print('Saved',flush=True)
except Exception:m.cancel();raise
