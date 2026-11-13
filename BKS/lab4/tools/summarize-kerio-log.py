"""Summarize actual forwarded Kerio records; never infer DPI from a port name."""
import argparse
import collections
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('log')
p.add_argument('--since', required=True, help='UTC ISO prefix, e.g. 2026-11-13T12:45:00Z')
p.add_argument('--output', required=True)
p.add_argument('--events', required=True)
a = p.parse_args()
by_rule, by_service, by_source = (collections.Counter() for _ in range(3))
actions = collections.Counter()
events = []
for line in Path(a.log).open(errors='replace'):
    m = re.match(r'<\d+>1 (\S+) control (kerio-\S+) - - - (.*)', line)
    if not m or m[1] < a.since:
        continue
    body = m[3]
    if m[2] not in ['kerio-connection', 'kerio-filter']:
        continue
    rule = re.search(r'\[Rule\] (.*?) \[Service\]', body)
    drop = re.search(r'\bDROP "([^"]+)"', body)
    if not rule and not drop:
        continue
    name = rule[1] if rule else drop[1]
    if name in ['BKS4-Syslog', 'BKS4-Temporary-SSH']:
        continue
    by_rule[name] += 1
    actions['blocked_packet' if drop else 'completed_connection'] += 1
    service = re.search(r'\[Service\] (.*?) \[Connection\]', body)
    if service:
        by_service[service[1]] += 1
    pair = re.search(r'((?:\d+\.){3}\d+)\)?:\d+ -> .*?((?:\d+\.){3}\d+)\)?:\d+', body)
    if pair:
        by_source[pair[1]] += 1
    events.append(line.rstrip())
result = {'since_utc': a.since, 'unit': 'log record; packets and completed connections counted separately',
          'actions': dict(actions), 'by_rule': dict(by_rule.most_common()),
          'by_network_service': dict(by_service.most_common()),
          'by_source_ipv4': dict(by_source.most_common())}
Path(a.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
Path(a.events).write_text('\n'.join(events) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
