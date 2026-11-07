#!/usr/bin/env python3
"""Compact view of native NGFW events from the syslog archive. Run with sudo on ADMIN-LINUX.
usage: evsel.py <timestamp_str prefix, e.g. 2026-11-07T13:1> [key=value filter ...]
"""
import re,sys
from pathlib import Path
prefix=sys.argv[1];filters=dict(x.split('=',1) for x in sys.argv[2:])
keys=['timestamp_str','event_type','action','src_ip','src_port','dest_ip','dest_port','signature_id','signature','rule_name','username','payload']
n=0
for line in Path('/var/log/bks4/10.1.99.1/events.log').open(errors='replace'):
    d=dict(re.findall(r'(\w+)="((?:[^"\\]|\\.)*)"',line))
    if not d.get('timestamp_str','').startswith(prefix):continue
    if any(d.get(k)!=v for k,v in filters.items()):continue
    app=re.search(r'\s(suricata|c4fw|\S+?)\[?\d*\]?:?\s+\[',line)
    print(' '.join(f"{k}={d.get(k,'')}" for k in keys if d.get(k) not in (None,''))[:330]);n+=1
print('total',n)
