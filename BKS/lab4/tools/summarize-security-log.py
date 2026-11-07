#!/usr/bin/env python3
"""Three statistical views of native BKS4 logs; run with sudo on ADMIN-LINUX.

Counts are log records, not sessions, packets or measured bandwidth. Historical
experiments are included; this is not a claim about the current policy's health.
"""
import argparse
from collections import Counter
import datetime
import json
from pathlib import Path
import re

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--log', type=Path, default=Path('/var/log/bks4/10.1.99.1/events.log'))
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()
users, applications, blocked = Counter(), Counter(), Counter()
actions = Counter()
times = []
recognized = {'IRC', 'BitTorrent', 'Jabber', 'HTTP', 'HTTPS', 'SSL', 'TLS'}
with args.log.open(errors='replace') as stream:
    for line in stream:
        d = dict(re.findall(r'(\w+)="((?:[^"\\]|\\.)*)"', line))
        if d.get('action') not in {'allowed', 'blocked'}:
            continue
        rule = d.get('rule_name', '')
        if not rule.startswith('BKS4-'):
            continue
        actions[d['action']] += 1
        users[d.get('username') or '(unauthenticated)'] += 1
        if d.get('signature') in recognized:
            applications[(d['signature'], d['action'])] += 1
        if d['action'] == 'blocked':
            blocked[rule] += 1
        stamp = d.get('timestamp_str') or d.get('timestamp')
        if stamp:
            times.append(stamp)
result = {
    'generated_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'source': str(args.log), 'unit': 'native firewall log records',
    'scope': 'all retained BKS4 rule events; includes historical experiments',
    'first_event': min(times) if times else None,
    'last_event': max(times) if times else None,
    'actions': dict(actions),
    'by_user': [{'user': k, 'records': v} for k, v in users.most_common()],
    'by_recognized_application': [
        {'application': k[0], 'action': k[1], 'records': v}
        for k, v in applications.most_common()],
    'blocked_by_rule': [{'rule': k, 'records': v} for k, v in blocked.most_common()],
}
assert sum(users.values()) == sum(actions.values())
assert sum(blocked.values()) == actions['blocked']
args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
