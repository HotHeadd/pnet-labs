#!/usr/bin/env python3
"""Забрать PNG-подтверждение с гостя, сохранив исходные байты."""
import argparse
import io
from pathlib import Path
import shlex
import subprocess
from PIL import Image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('node', choices=['directory', 'apps', 'web', 'workstation'])
p.add_argument('remote')
p.add_argument('output', type=Path)
p.add_argument('--tailscale-nc', action='store_true')
a = p.parse_args()
if not a.remote.startswith('/tmp/sa6-') or not a.remote.endswith('.png'):
    p.error('ожидался /tmp/sa6-*.png')
octet = {'directory': 231, 'apps': 232, 'web': 233, 'workstation': 234}[a.node]
inner = ['ssh', '-n', '-i', '/root/.ssh/id_rsa_dy', '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=10', 'labadmin@192.168.15.' + str(octet),
    'sudo cat ' + shlex.quote(a.remote)]
outer = ['ssh', '-n', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10']
if a.tailscale_nc:
    outer += ['-o', 'ProxyCommand=tailscale nc %h %p']
result = subprocess.run(outer + ['root@100.100.57.19', shlex.join(inner)], stdout=subprocess.PIPE,
    stderr=subprocess.PIPE, timeout=45)
if result.returncode:
    raise SystemExit(result.stderr.decode(errors='replace'))
with Image.open(io.BytesIO(result.stdout)) as im:
    if im.format != 'PNG':
        raise SystemExit('Ожидался PNG')
    im.verify()
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_bytes(result.stdout)
print(a.output)
