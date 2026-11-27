#!/usr/bin/env python3
"""На PNET-хосте: проверить tar, передать .deb в гостя и запустить APT.

Аргументы: NODE SHA256 INSTALL_SCRIPT. Скрипт установки нужен только
для чтения итогового списка пакетов; APT update здесь не выполняется.
"""
import hashlib
from pathlib import Path
import shlex
import subprocess
import sys

node, expected, script = sys.argv[1:]
octet = {'apps': 232, 'web': 233, 'workstation': 234}[node]
bundle = Path('/tmp/sa6-' + node + '-packages.tar')
digest = hashlib.sha256()
with bundle.open('rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        digest.update(chunk)
if digest.hexdigest() != expected:
    raise SystemExit('SHA256 архива не совпал')
ssh = ['ssh', '-i', '/root/.ssh/id_rsa_dy', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=10',
       '-o', 'ServerAliveCountMax=3', 'labadmin@192.168.15.' + str(octet)]
def guest(args, **kwargs):
    return subprocess.run(ssh + [' '.join(shlex.quote(x) for x in args)], **kwargs)
active = guest(['pgrep', '-x', 'apt-get'], stdout=subprocess.PIPE)
if active.returncode != 1:
    raise SystemExit('APT уже работает либо проверка процессов не удалась')
with bundle.open('rb') as f:
    guest(['sudo', 'tar', '--no-same-owner', '-xf', '-', '-C', '/var/cache/apt/archives'], stdin=f, check=True)
line = next(x for x in Path(script).read_text().splitlines() if x.startswith('apt-get install'))
args = shlex.split(line)
unit = 'sa6-install-cached-' + node
log = '/var/log/' + unit + '.log'
guest(['sudo', 'systemd-run', '--no-block', '--unit=' + unit,
       '--property=Type=oneshot', '--property=RemainAfterExit=yes',
       '--property=StandardOutput=append:' + log, '--property=StandardError=append:' + log,
       'env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get', '--no-download',
       '-o', 'DPkg::Lock::Timeout=60', *args[1:]], check=True)
print(node + ': SHA256 OK, архив передан, APT запущен без сетевой загрузки', flush=True)
