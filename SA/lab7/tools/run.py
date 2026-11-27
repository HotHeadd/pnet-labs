#!/usr/bin/env python3
"""Команда или файл на госте SA7 через SSH PNET-хоста. Секреты не копирует."""
import argparse
import hashlib
from pathlib import Path
import shlex
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('node',choices=['gw','im','rtc','workstation'])
p.add_argument('command',nargs='?')
p.add_argument('--file',type=Path)
p.add_argument('--background',action='store_true')
p.add_argument('--output',type=Path)
a=p.parse_args()
if bool(a.file)==bool(a.command):
    p.error('Нужна команда или --file')
octet={'gw':241,'im':242,'rtc':243,'workstation':244}[a.node]
cmd=a.command
if a.file:
    remote='/tmp/sa7-'+a.file.name
    unit='sa7-'+a.file.stem
    log='/var/log/'+unit+'.log'
    interpreter='python3' if a.file.suffix=='.py' else 'bash'
    start=shlex.join([interpreter,remote])
    if a.background:
        start=shlex.join(['systemd-run','--no-block','--unit='+unit,
            '--property=Type=oneshot','--property=RemainAfterExit=yes',
            '--property=StandardOutput=append:'+log,
            '--property=StandardError=append:'+log,interpreter,remote])
    digest=hashlib.sha256(a.file.read_bytes()).hexdigest()
    check='printf "%s  %s\\n" '+shlex.quote(digest)+' '+shlex.quote(remote)+' | sha256sum -c -'
    cmd='sudo -n bash -c '+shlex.quote('set -e\ncat > '+shlex.quote(remote)+'\n'+check+'\n'+start)
inner=['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes',
    '-o','StrictHostKeyChecking=accept-new',
    '-o','ConnectTimeout=8','-o','ServerAliveInterval=10','-o','ServerAliveCountMax=3',
    'labadmin@192.168.15.'+str(octet),cmd]
outer=['ssh','-o','BatchMode=yes','-o','IPQoS=none','-o','ConnectTimeout=15',
    '-o','ServerAliveInterval=15','-o','ServerAliveCountMax=3',
    'root@100.100.57.19',shlex.join(inner)]
r=subprocess.run(outer,input=a.file.read_bytes() if a.file else None,
    stdout=subprocess.PIPE if a.output else None,
    stderr=subprocess.STDOUT if a.output else None)
if a.output:
    print(r.stdout.decode(errors='replace'),end='')
    if r.returncode!=255:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_bytes(r.stdout)
raise SystemExit(r.returncode)
