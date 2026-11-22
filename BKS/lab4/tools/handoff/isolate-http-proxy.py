from pathlib import Path
from c4_lib import C4Manager,Config
h=Path.home();m=C4Manager(Config(c4_ip='10.1.99.1',c4_password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False));a=m.config_keeper.api;a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
assert m.open();b=a.get_obj_url(m.config_keeper.uuid)
try:
 x=next(x for x in a.get_from_endpoint(b+'/fwrule?view=full')['data'] if x['name']=='BKS4-LAN-HTTP-AV');assert x['app_profile']['uuid']=='2de1c5e2-b93f-47e0-bbc2-0b3a4b57fbff'
 r=a.put_to_endpoint(b+'/fwrule/'+x['uuid'],{'app_profile':None});assert 'uuid' in r
 y=a.get_from_endpoint(b+'/fwrule/'+x['uuid']+'?view=full')['data'][0];assert not y.get('app_profile')
 assert m.save();print('Diagnostic only: outbound LAN HTTP temporarily without AV proxy; LAN-to-DMZ AV retained. Restore afterward.',flush=True)
except Exception:m.cancel();raise
