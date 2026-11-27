#!/usr/bin/env python3
"""На PNET-хосте: настроить служебные консоли только четырёх узлов SA6."""
from pathlib import Path
import shlex
import subprocess

source = Path('/tmp/sa6-console-access.sh').read_bytes()
for octet, name in [(231, 'directory'), (232, 'apps'), (233, 'web'), (234, 'workstation')]:
    check = 'test "$(hostname)" = ' + shlex.quote(name) + ' && sudo bash -s'
    r = subprocess.run(['ssh', '-i', '/root/.ssh/id_rsa_dy', '-o', 'BatchMode=yes',
        '-o', 'ConnectTimeout=5', 'labadmin@192.168.15.' + str(octet), check], input=source)
    print(name + ': exit=' + str(r.returncode), flush=True)
