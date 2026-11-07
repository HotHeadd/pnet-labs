#!/usr/bin/env python3
"""Restore detached data TAPs in the existing BKS4 pod after bridge recreation.

Run on the PNETLab host. These bindings are specific to lab session 9 and node
sessions 8..12, verified against the live API. Recheck topology before use.
Default is read-only; --apply attaches only unbound TAPs. OOB is untouched.
"""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--apply', action='store_true')
args = p.parse_args()
bindings = [
    ('8', 'LAN-CLIENT', 'vunl8_0', 'vnet9_2'),
    ('9', 'DMZ-WEB', 'vunl9_0', 'vnet9_3'),
    ('10', 'WAN-TEST', 'vunl10_0', 'vnet9_1'),
    ('11', 'ADMIN-LINUX', 'vunl11_0', 'vnet9_4'),
    ('12', 'ADMIN-WIN', 'vunl12_0', 'vnet9_4'),
]
running = set()
for proc in Path('/proc').iterdir():
    if not proc.name.isdigit():
        continue
    try:
        cmd = (proc / 'cmdline').read_bytes().split(b'\0')
        if cmd and b'qemu-system' in cmd[0]:
            running.add(str((proc / 'cwd').resolve()))
    except (FileNotFoundError, PermissionError):
        continue
# Complete preflight before any mutation, refusing to move a bound TAP.
pending = []
for session, name, tap, bridge in bindings:
    assert '/opt/unetlab/tmp/9/' + session in running, 'Expected BKS4 VM not running: ' + name
    device = Path('/sys/class/net') / tap
    target = Path('/sys/class/net') / bridge
    assert device.exists() and (target / 'bridge').is_dir(), 'Missing TAP or bridge: ' + name
    master = device / 'master'
    actual = master.resolve().name if master.exists() else None
    assert actual in [None, bridge], 'TAP belongs to another bridge: ' + tap
    print(name, tap, 'master=' + str(actual), 'expected=' + bridge, flush=True)
    if actual is None:
        pending.append((tap, bridge))
if args.apply:
    for tap, bridge in pending:
        subprocess.check_call(['ip', 'link', 'set', 'dev', tap, 'master', bridge])
        assert (Path('/sys/class/net') / tap / 'master').resolve().name == bridge
        print('Attached', tap, 'to', bridge, flush=True)
else:
    print('Read-only check. Detached TAPs:', len(pending), '; use --apply to repair.')
