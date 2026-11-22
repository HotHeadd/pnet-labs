#!/usr/bin/env python3
"""Correlate monitor records with payloads actually recorded by snmptrapd.

Run with sudo on ADMIN-LINUX. Never reads SNMP community files.
"""
import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import textwrap

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--since', required=True, help='UTC ISO timestamp before test start')
p.add_argument('--component', choices=['AV', 'IPS'], required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--origin', choices=['continent', 'kerio'], default='continent')
args = p.parse_args()
since = datetime.fromisoformat(args.since.replace('Z', '+00:00'))
received = {}
sender = None
for line in Path('/var/log/bks4/snmp-traps.log').read_text(errors='replace').splitlines():
    match = re.search(r'\[UDP: \[([^]]+)\]:\d+->\[10\.1\.99\.10\]:162\]', line)
    if match:
        sender = match.group(1)
    if 'iso.3.6.1.3.9999.4.1.0 = STRING: ' not in line:
        continue
    try:
        body = line.split('iso.3.6.1.3.9999.4.1.0 = STRING: ', 1)[1]
        event = json.loads(json.loads(body))
        received[(event['monitor_utc'], event['component'])] = (sender, event)
    except (ValueError, KeyError, TypeError):
        continue
verified = []
for line in Path('/var/log/bks4/security-alerts.jsonl').read_text().splitlines():
    event = json.loads(line)
    if event['component'] != args.component or datetime.fromisoformat(event['monitor_utc']) < since:
        continue
    if args.component == 'AV' and args.origin == 'kerio':
        if event.get('syslog_app') != 'kerio-alert':
            continue
        assert event.get('origin') == 'Kerio native syslog'
    elif args.component == 'AV' and event.get('origin') != 'ICAP engine log':
        continue
    if args.component == 'IPS':
        expected_app = 'kerio-security' if args.origin == 'kerio' else 'suricata'
        if event.get('syslog_app') != expected_app:
            continue
        if args.origin == 'kerio':
            assert event.get('origin') == 'Kerio native syslog', 'Not a native Kerio detection'
    actual = received.get((event['monitor_utc'], event['component']))
    assert actual and actual[0] == '10.1.99.10' and actual[1] == event, 'Missing or different SNMP payload'
    verified.append(event)
assert verified, 'No fresh events for requested component'
lines = ['External monitor SNMP delivery: verified', 'Component: ' + args.component,
         'Sender/receiver: 10.1.99.10 -> 10.1.99.10:162',
         'Notification OID: 1.3.6.1.3.9999.4.0.1', 'Matched events: ' + str(len(verified))]
for event in verified:
    lines += ['', 'Monitor UTC: ' + event['monitor_utc'], 'Origin: ' + event['origin']]
    if event['component'] == 'AV' and args.origin == 'kerio':
        for key in ['syslog_app', 'src_ip', 'user', 'url', 'threat', 'action']:
            lines.extend(textwrap.wrap(key + ': ' + str(event.get(key)), width=88))
    elif event['component'] == 'AV':
        detail = event['detail']
        threat = re.search(r'VIRUS DETECTED:\s*([^,]+)', detail)
        url = re.search(r'http url:\s*(\S+)', detail)
        lines += ['Threat: ' + (threat.group(1).strip() if threat else 'not parsed'),
                  'Object: ' + (url.group(1) if url else 'not parsed')]
    else:
        for key in ['syslog_app', 'timestamp_str', 'src_ip', 'dest_ip', 'signature_id', 'signature', 'action']:
            if event.get(key) is not None:
                lines.extend(textwrap.wrap(key + ': ' + str(event[key]), width=88))
    lines.append('Exact payload found in snmptrapd log: yes')
text = '\n'.join(lines) + '\n'
args.output.write_text(text)
print(text, end='')
