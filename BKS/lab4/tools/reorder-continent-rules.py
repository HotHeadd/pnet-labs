"""Reorder active FW rules: every name listed gets rule_position last, in order; unlisted rules keep relative order before them? No - list ALL rules."""
from pathlib import Path
import sys
from c4_lib import C4Manager,Config
order=[l.strip() for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
h=Path.home();m=C4Manager(Config(c4_ip='10.1.99.1',c4_password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False));a=m.config_keeper.api;a.session.trust_env=False;o=a.session.request;a.session.request=lambda *x,**k:o(*x,timeout=180,**k)
assert m.open();b=a.get_obj_url(m.config_keeper.uuid)
try:
 rules={x['name']:x for x in a.get_from_endpoint(b+'/fwrule?view=full')['data']}
 missing=set(rules)-set(order); extra=set(order)-set(rules); assert not missing and not extra,(missing,extra)
 for n in order:
  r=a.put_to_endpoint(b+'/fwrule/'+rules[n]['uuid'],{'rule_position':{'last':True}});assert 'uuid' in r,r
 assert m.save();print('Saved order:',*order,sep='\n ',flush=True)
except Exception:m.cancel();raise
