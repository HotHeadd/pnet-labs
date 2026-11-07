#!/usr/bin/env python3
"""Read the latest native per-port DPI events; run with sudo on ADMIN-LINUX.

No time-window filter: preserve each event's own timestamp, including timezone.
Events may belong to different runs; compare their timestamps with client tests.
"""
import argparse
import json
from pathlib import Path
import re

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', choices=['10.1.10.42', '10.1.99.10'])
p.add_argument('user', choices=['labguest', 'lab-admin'])
p.add_argument('action', choices=['blocked', 'allowed'])
args = p.parse_args()
ports = ['6667', '16667', '6881', '16881']
events = {}
with Path('/var/log/bks4/10.1.99.1/events.log').open(errors='replace') as stream:
    for line in stream:
        d = dict(re.findall(r'(\w+)="((?:[^"\\]|\\.)*)"', line))
        if (d.get('src_ip') == args.source and d.get('username') == args.user
                and d.get('action') == args.action and d.get('dest_port') in ports):
            events[d['dest_port']] = d
for port in ports:
    if port not in events:
        print(json.dumps({'dest_port': port, 'result': 'no matching native event'}))
        continue
    d = events[port]
    print(json.dumps({k: d.get(k) for k in [
        'timestamp', 'timestamp_str', 'src_ip', 'dest_ip', 'dest_port',
        'action', 'signature', 'username', 'rule_name',
    ]}, ensure_ascii=False))
