#!/usr/bin/env python3
"""Выполнить команду или shell-файл на одном узле SA6 через SSH хоста.

Пример: python3 SA/lab6/tools/run.py directory 'ip -br address'
С --file файл передаётся на stdin sudo bash. --output сохраняет stdout.
"""
import argparse
import hashlib
from pathlib import Path
import shlex
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('node', choices=['directory', 'apps', 'web', 'workstation'])
p.add_argument('command', nargs='?')
p.add_argument('--file', type=Path)
p.add_argument('--background', action='store_true', help='запустить файл отдельным systemd-заданием')
p.add_argument('--output', type=Path)
a = p.parse_args()
if bool(a.file) == bool(a.command):
    p.error('нужна команда или --file')
octet = {'directory': 231, 'apps': 232, 'web': 233, 'workstation': 234}[a.node]
cmd = a.command
if a.file:
    remote = '/tmp/sa6-' + a.file.name
    unit = 'sa6-' + a.file.stem
    log = '/var/log/' + unit + '.log'
    start = shlex.join(['bash', remote])
    if a.background:
        start = shlex.join(['systemd-run', '--no-block', '--unit=' + unit,
            '--property=Type=oneshot', '--property=RemainAfterExit=yes',
            '--property=StandardOutput=append:' + log,
            '--property=StandardError=append:' + log, 'bash', remote])
    digest = hashlib.sha256(a.file.read_bytes()).hexdigest()
    check = 'printf "%s  %s\\n" ' + shlex.quote(digest) + ' ' + shlex.quote(remote) + ' | sha256sum -c -'
    cmd = 'sudo -n bash -c ' + shlex.quote('set -e\ncat > ' + shlex.quote(remote) + '\n' + check + '\n' + start)
inner = ['ssh', '-i', '/root/.ssh/id_rsa_dy', '-o', 'BatchMode=yes',
         '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=10',
         '-o', 'ServerAliveCountMax=3', f'labadmin@192.168.15.{octet}', cmd]
outer = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=30',
         '-o', 'IPQoS=none',
         '-o', 'ServerAliveInterval=30', '-o', 'ServerAliveCountMax=10',
         'root@100.100.57.19', shlex.join(inner)]
if Path('/tmp/pnet-sa6-ssh.sock').exists():
    outer[1:1] = ['-S', '/tmp/pnet-sa6-ssh.sock']
r = subprocess.run(outer, input=a.file.read_bytes() if a.file else b'',
                   stdout=subprocess.PIPE if a.output else None)
if a.output:
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_bytes(r.stdout)
    print(r.stdout.decode(errors='replace'), end='')
raise SystemExit(r.returncode)
