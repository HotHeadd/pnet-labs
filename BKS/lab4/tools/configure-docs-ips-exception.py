#!/usr/bin/env python3
"""Narrow trusted-host exception for the lab's legitimate documentation request.

Only ADMIN-LINUX -> published HTTP on this DMZ server bypasses IPS. Firewall,
DNAT and all other sources keep their policy; no signature is globally disabled.
Run on ADMIN-LINUX; this saves the draft, policy installation is a separate step.
"""
from c4_lib import C4Manager, Config
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--apply', action='store_true')
args = p.parse_args()
h = Path.home()
m = C4Manager(Config(c4_ip='10.1.99.1', c4_password=(h / '.bks4-continent-admin-password').read_text().strip(), verbosity=False))
a = m.config_keeper.api
a.session.trust_env = False
original = a.session.request
a.session.request = lambda *x, **k: original(*x, timeout=180, **k)
name = 'BKS4-Admin-Docs-IPS-Exception'
if not args.apply:
    print('Scope: 10.1.99.10 -> 192.168.100.2:8080, IPS bypass only.')
    print('Read-only; --apply saves the rule. Install and verify separately.')
    raise SystemExit(0)
assert a.config_lock_user().get('admin') is None, 'Another editor holds the configuration lock'
assert m.open()
base = a.get_obj_url(m.config_keeper.uuid)
try:
    nets = {x['name']: x for x in a.get_from_endpoint(base + '/netobject')['data']}
    services = {x['name']: x for x in a.get_from_endpoint(base + '/service')['data']}
    source = nets['BKS4_ADMIN_LINUX']
    target = nets['BKS4_WAN_PUBLIC']
    service = services['BKS4_PUBLISHED_HTTP']
    assert source['ip'] == '10.1.99.10' and target['ip'] == '192.168.100.2'
    assert service['proto'] == 6 and service['dst'] == '8080'
    rules = a.get_from_endpoint(base + '/fwrule')['data']
    existing = [x for x in rules if x['name'] == name]
    assert len(existing) <= 1
    body = dict(name=name, type='fwrule', is_enabled=True, src=[source['uuid']],
                dst=[target['uuid']], service=[service['uuid']], applications=[],
                app_profile=None, rule_action='pass', logging=True, passips=False,
                install_on=['2b799461-dece-47a6-b4f4-3debee8560d8'])
    if existing:
        uid = existing[0]['uuid']
        result = a.put_to_endpoint(base + '/fwrule/' + uid, body)
    else:
        result = a.post_to_endpoint(base + '/fwrule', dict(body, rule_position={'last': True}))
        uid = result.get('uuid')
    assert result.get('uuid'), 'Exception validation failed'
    ordered = [x for x in rules if x['name'] != name]
    index = next(i for i, x in enumerate(ordered) if x['name'] == 'BKS4-WAN-Published-Web')
    ordered.insert(index, {'uuid': uid, 'name': name})
    for rule in ordered:
        result = a.put_to_endpoint(base + '/fwrule/' + rule['uuid'], {'rule_position': {'last': True}})
        assert result.get('uuid')
    readback = a.get_from_endpoint(base + '/fwrule')['data']
    assert [x['name'] for x in readback] == [x['name'] for x in ordered]
    assert m.save()
except Exception:
    m.cancel()
    raise
safe = dict(name=name, source='10.1.99.10', destination='192.168.100.2',
            protocol='TCP', destination_port=8080, action='pass', logging=True,
            passips=False, before='BKS4-WAN-Published-Web')
(h / 'bks4-docs-exception-summary.json').write_text(json.dumps(safe, indent=2) + '\n')
print('Saved narrow IPS exception:', json.dumps(safe), flush=True)
