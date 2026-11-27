#!/usr/bin/env python3
"""Добавить только публичный ключ WORKSTATION в SSH-профиль Alice на APPS."""
import shlex
import subprocess

code = r'''
import shlex,subprocess
ssh=['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes','-o','ConnectTimeout=5']
public=subprocess.check_output(ssh+['labadmin@192.168.15.234','cat /home/labadmin/.ssh/sa6-alice.pub']).decode().strip()
assert public.startswith('ssh-ed25519 ')
script="from pathlib import Path; import os; p=Path('/home/alice/.ssh'); p.mkdir(mode=0o700,parents=True,exist_ok=True); f=p/'authorized_keys'; key="+repr(public)+"; old=f.read_text() if f.exists() else ''; f.write_text(old if key in old.splitlines() else old.rstrip()+chr(10)+key+chr(10)); os.chown(p,10001,10000); os.chown(f,10001,10000); p.chmod(0o700); f.chmod(0o600)"
subprocess.run(ssh+['labadmin@192.168.15.232','sudo python3 -c '+shlex.quote(script)],check=True)
print('WORKSTATION public key authorized for Alice on APPS')
'''
raise SystemExit(subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
    'root@100.100.57.19', 'python3 -c ' + shlex.quote(code)]).returncode)
