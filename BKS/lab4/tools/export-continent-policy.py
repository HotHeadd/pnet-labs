#!/usr/bin/env python3
"""Read-only public rule summary, not a full configuration backup.

Run on ADMIN-LINUX. Secret-bearing configuration objects are never exported.
Preserve source/destination inversion so a summary cannot reverse a rule's meaning.
"""
from c4_lib import ApiConnector
from pathlib import Path
import json

h = Path.home()
a = ApiConnector(ip='10.1.99.1', password=(h / '.bks4-continent-admin-password').read_text().strip(), verbosity=False)
a.session.trust_env = False
original = a.session.request
a.session.request = lambda *x, **k: original(*x, timeout=120, **k)
base = a.get_obj_url('active')


def names(value):
    if value is None:
        return []
    if not isinstance(value, list):
        value = [value]
    return [(x.get('name') or x.get('uuid')) if isinstance(x, dict) else x for x in value]


for kind in ['fwrule', 'natrule']:
    rows = a.get_from_endpoint(base + '/' + kind + '?view=full')['data']
    safe = []
    for i, row in enumerate(rows):
        result = {k: row[k] for k in [
            'name', 'is_enabled', 'rule_action', 'is_inverse_src', 'is_inverse_dst',
            'logging', 'passips', 'nat_type', 'address_type', 'port_type',
        ] if k in row}
        result['order'] = i + 1
        for key in ['src', 'dst', 'service', 'applications', 'app_profile', 'install_on']:
            if key in row:
                result[key] = names(row[key])
        for key in ['value', 'port_value']:
            if key not in row:
                continue
            value = row[key]
            result[key] = ({k: value[k] for k in ['name', 'ip', 'src', 'dst', 'proto'] if k in value}
                           if isinstance(value, dict) else value)
        safe.append(result)
    path = h / ('bks4-' + kind + '-public.json')
    path.write_text(json.dumps(safe, ensure_ascii=False, indent=2) + '\n')
    print(kind, len(rows), 'public rule summaries saved')
