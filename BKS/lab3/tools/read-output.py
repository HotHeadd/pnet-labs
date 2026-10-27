#!/usr/bin/env python3
"""Сохранить реальный текст SSH-проверки с узла через хост PNETLab.

Usage: python3 tools/read-output.py NAME LAST_OCTET 'COMMAND'
Требует SSH-ключ текущего пользователя к root хоста; на хосте — ключ к labadmin.
"""
import argparse
from pathlib import Path
import shlex
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('name')
p.add_argument('octet',type=int,choices=range(211,216))
p.add_argument('command')
a=p.parse_args()
remote=['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes','-o','ConnectTimeout=5',
        f'labadmin@192.168.15.{a.octet}',a.command]
r=subprocess.run(['ssh','-o','BatchMode=yes','root@100.100.57.19',shlex.join(remote)],
                 stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(r.stdout,end='')
if a.name!='-':
    if Path(a.name).name!=a.name:
        p.error('NAME must be a filename stem')
    (Path(__file__).resolve().parents[1]/'outputs'/f'{a.name}.txt').write_text(r.stdout)
raise SystemExit(r.returncode)
