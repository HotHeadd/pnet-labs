#!/usr/bin/env python3
"""Run with sudo on ADMIN-LINUX after changing IPS settings; wait for native Startup."""
import argparse,time
from datetime import datetime
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--since',required=True);p.add_argument('--timeout',type=int,default=120);a=p.parse_args()
since=datetime.fromisoformat(a.since.replace('Z','+00:00'));end=time.monotonic()+a.timeout
while time.monotonic()<end:
 events=[]
 for line in Path('/var/log/bks4/10.1.99.1/events.log').read_text(errors='replace').splitlines():
  if ' kerio-security ' not in line or 'Intrusion Prevention engine:' not in line:continue
  try:stamp=datetime.fromisoformat(line.split()[1])
  except (ValueError,IndexError):continue
  if stamp>=since:events.append((stamp,line))
 if events:
  _,last=max(events,key=lambda x:x[0])
  if last.rstrip().endswith('Startup'):
   print(last);print('Native IPS startup confirmed; tests may start');break
 time.sleep(3)
else:raise SystemExit('No fresh native IPS Startup: do not interpret traffic tests as IPS results')
