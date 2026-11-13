"""Apply and confirm the final BKS4 policy using native service objects.

Run beside kerio-api.py on ADMIN-LINUX. Built-in service IDs below were checked
against this appliance's IPServices table. Custom service entries are normalized
by Kerio to one protocol; use native references for mixed protocol selections.
"""
import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path

os.environ.setdefault('KERIO_URL', 'https://10.1.99.1:4081/admin/api/jsonrpc/')
os.environ.setdefault('KERIO_PASSWORD_FILE', str(Path.home() / '.bks4-kerio-password'))
spec = importlib.util.spec_from_file_location('kerio_api', Path(__file__).with_name('kerio-api.py'))
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--keep-temporary-ssh', action='store_true')
args = p.parse_args()
services = {2: 'Any ICMP', 4: 'SSH', 7: 'DNS', 8: 'HTTP', 11: 'HTTPS',
            25: 'NTP', 30: 'SNMP', 50: 'Kerio Control WebAdmin',
            51: 'Kerio Control WebInterface', 72: 'Syslog'}

def refs(*ids):
    return {'type': 'RuleSelectedEntities', 'entries': [
        {'definedService': True,
         'service': {'id': str(i), 'name': services[i], 'isGroup': False, 'invalid': False},
         'protocol': 0, 'port': {'comparator': 'Any', 'ports': []}}
        for i in ids]}

wanted = {
    'BKS4-Management': refs(50, 11, 30),
    'BKS4-Deny-Admin-Outside-Management': refs(50, 51),
    'BKS4-Admin-DMZ': refs(4, 8, 11, 2),
    'BKS4-LAN-DMZ-Web': refs(8, 11),
    'BKS4-Protected-DNS-NTP': refs(7, 25),
    'BKS4-Protected-Web': refs(8, 11),
    'BKS4-DMZ-DNS-NTP': refs(7, 25),
    'BKS4-DMZ-Updates': refs(8, 11),
    'BKS4-Firewall-DNS-NTP': refs(7, 25),
    'BKS4-Firewall-Web': refs(8, 11),
    'BKS4-Firewall-ICMP': refs(2),
    'BKS4-Internal-ICMP-Gateway': refs(2),
    'BKS4-Syslog': refs(72),
}
k = api.Kerio()
k.login()
rules = k.call('TrafficPolicy.get')['list']
default = k.call('TrafficPolicy.getDefaultRule')['rule']
if not args.keep_temporary_ssh:
    rules = [r for r in rules if r['name'] != 'BKS4-Temporary-SSH']
for r in rules:
    if r['name'] in wanted:
        r['service'] = copy.deepcopy(wanted[r['name']])
    r['logEnabled'] = [r['action'] == 'Drop', True]
    if r['name'] == 'BKS4-Syslog':
        r['logEnabled'] = [False, False]  # avoid logging the log transport
    if r['name'] == 'BKS4-LAN-DMZ-Web':
        r['description'] = 'BKS4 variant 6: LAN reaches DMZ web only on HTTP/HTTPS'
default['logEnabled'] = [True, True]
result = k.call('TrafficPolicy.set', {'rules': rules, 'defaultRule': default})
assert not result.get('errors'), result
print('TrafficPolicy.set: errors=[]', flush=True)
assert k.call('Session.confirmConfig', k.call('Session.getConfigTimestamp'))['confirmed']
k.call('Session.logout')
k.login()
actual = k.call('TrafficPolicy.get')['list']
for r in actual:
    if r['name'] in wanted:
        ids = [e['service']['id'] for e in r['service']['entries']]
        expected = [e['service']['id'] for e in wanted[r['name']]['entries']]
        assert sorted(ids) == sorted(expected), (r['name'], ids, expected)
    print(r['name'], r['action'],
          [e['service']['name'] if e['definedService'] else
           str(e['protocol']) + ':' + str(e['port']['ports'])
           for e in r['service']['entries']] if r['service']['type'] != 'RuleAny' else 'Any')
state = {'rules': actual, 'defaultRule': k.call('TrafficPolicy.getDefaultRule')['rule']}
Path.home().joinpath('kerio-traffic-policy.json').write_text(json.dumps(state, ensure_ascii=False, indent=1))
k.call('Session.logout')
print('Confirmed in a fresh session:', len(actual), 'rules')
