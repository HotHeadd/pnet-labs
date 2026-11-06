from pathlib import Path
import json
from c4_lib import ApiConnector
h=Path.home();a=ApiConnector(ip='10.1.99.1',password=(h/'.bks4-continent-admin-password').read_text().strip(),verbosity=False);a.session.trust_env=False;b=a.get_obj_url('active')
print('advancedcomponent',json.dumps(a.get_from_endpoint(b+'/advancedcomponent'),ensure_ascii=False))
node=a.get_from_endpoint(b+'/cgw/2b799461-dece-47a6-b4f4-3debee8560d8?view=full')['data'][0];print('Node advanced_component',json.dumps(node.get('advanced_component'),ensure_ascii=False))
