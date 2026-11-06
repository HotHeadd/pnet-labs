#!/usr/bin/env python3
"""Render selected RFC5424 firewall fields for a readable evidence listing."""
import json,re,sys
from pathlib import Path
for line in Path(sys.argv[1]).read_text(errors='replace').splitlines():
 fields=dict(re.findall(r'(\w+)="((?:[^"\\]|\\.)*)"',line))
 if fields.get('event_type')!='firewall':continue
 if len(sys.argv)>2 and fields.get('rule_name') not in sys.argv[2:]:continue
 print(json.dumps({k:fields[k] for k in ['timestamp','src_ip','src_port','dest_ip','dest_port','proto','action','rule_name','src_country','dest_country','payload'] if k in fields},ensure_ascii=False))
