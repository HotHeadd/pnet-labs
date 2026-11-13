"""Summarize actual Kerio syslog records; ports are never treated as DPI labels."""
import argparse
import collections
from datetime import datetime, timezone
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('log')
p.add_argument('--since', required=True, help='UTC ISO timestamp')
p.add_argument('--output', required=True)
p.add_argument('--events', required=True)
p.add_argument('--event-limit', type=int, default=60, help='Maximum representative excerpt lines; counters use all records')
a = p.parse_args()
start = datetime.fromisoformat(a.since.replace('Z', '+00:00'))
by_rule, by_service, by_source, by_user, by_app, actions = (collections.Counter() for _ in range(6))
events = []
for line in Path(a.log).open(errors='replace'):
    m = re.match(r'<\d+>1 (\S+) control (kerio-\S+) - - - (.*)', line)
    if not m:
        continue
    timestamp = datetime.fromisoformat(m[1].replace('Z', '+00:00'))
    if timestamp < start:
        continue
    app, body = m[2], m[3].lstrip('\ufeff ')
    if app not in ['kerio-connection', 'kerio-filter', 'kerio-security']:
        continue
    rule = re.search(r'\[Rule\]\s+(.*?)(?=\s+\[)', body)
    packet = re.match(r'(ALLOW|DROP) "([^"]+)"', body)
    if rule:
        name = rule[1].strip("'\"")
    elif packet:
        name = packet[2]
    elif 'IPS:' in body:
        sid = re.search(r'Rule ID: (\d+:\d+)', body)
        name = 'IPS ' + (sid[1] if sid else 'unknown')
    else:
        continue
    if name in ['BKS4-Syslog', 'BKS4-Temporary-SSH']:
        continue
    if 'IPS:' in body:
        kind = 'ips_drop' if 'IPS: Packet drop' in body else 'ips_alert'
    elif rule and body.startswith(('DENY ', 'ALLOW ')):
        kind = 'content_deny' if body.startswith('DENY ') else 'content_allow'
    elif packet:
        kind = 'firewall_packet_drop' if packet[1] == 'DROP' else 'firewall_packet_allow'
    else:
        kind = 'completed_connection'
    actions[kind] += 1
    by_rule[name] += 1
    user = re.search(r'\[User\] (\S+)', body)
    if user:
        by_user[user[1]] += 1
    dpi = re.search(r'\[Content\]\s*(.*)$', body)
    if dpi and dpi[1].strip():
        by_app[dpi[1].strip()] += 1
    service = re.search(r'\[Service\] (.*?)(?=\s+\[|$)', body)
    pair = re.search(r'((?:\d+\.){3}\d+)\)?:([0-9]+) -> .*?((?:\d+\.){3}\d+)\)?:([0-9]+)', body)
    if pair:
        by_source[pair[1]] += 1
    if service:
        by_service[service[1]] += 1
    elif pair:
        proto = 'UDP' if 'UDP' in body else 'TCP'
        by_service[proto + '/' + pair[4]] += 1
    events.append((kind,name,pair[4] if pair and kind.startswith('content_') else '',line.rstrip()))
result = {'since_utc': start.astimezone(timezone.utc).isoformat(),
          'unit': 'log record; content decisions, packets, IPS events and completed connections are separate event kinds',
          'actions': dict(actions), 'by_rule': dict(by_rule.most_common()),
          'by_network_service': dict(by_service.most_common()),
          'by_source_ipv4': dict(by_source.most_common()),
          'by_user': dict(by_user.most_common()), 'by_detected_content': dict(by_app.most_common())}
Path(a.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
selected=[]
seen=collections.Counter()
for kind,name,port,line in reversed(events):
    key=(kind,name,port)
    if kind=='firewall_packet_allow' or seen[key]>=1:
        continue
    selected.append(line);seen[key]+=1
    if len(selected)>=a.event_limit:
        break
Path(a.events).write_text('\n'.join(reversed(selected)) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
