#!/usr/bin/env python3
"""На PNET-хосте: передать CA, серверные ключи и нужные учётные данные.

Секреты остаются в каталогах /root/sa6-private на хосте и гостях.
Их значения не выводятся и не попадают в репозиторий.
"""
import io
import json
from pathlib import Path
import shlex
import subprocess
import tarfile

SSH = ['ssh', '-i', '/root/.ssh/id_rsa_dy', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=10',
       '-o', 'ServerAliveCountMax=3']


def guest(octet, args, **kwargs):
    return subprocess.run([*SSH, f'labadmin@192.168.15.{octet}', ' '.join(shlex.quote(x) for x in args)], check=True, **kwargs)


data = guest(231, ['sudo', 'tar', '-C', '/root/sa6-private', '-cf', '-',
    'ca.crt', 'apps.crt', 'apps.key', 'web.crt', 'web.key', 'credentials.json'], stdout=subprocess.PIPE).stdout
with tarfile.open(fileobj=io.BytesIO(data)) as archive:
    files = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
credentials = json.loads(files['credentials.json'])
for octet, names, keys in [
    (232, ['ca.crt', 'apps.crt', 'apps.key'], ['alice', 'bob', 'tryton_admin']),
    (233, ['ca.crt', 'web.crt', 'web.key'], ['svc_keycloak']),
    (234, ['ca.crt'], ['alice', 'bob'])]:
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w') as archive:
        payloads = {name: files[name] for name in names}
        payloads['directory-credentials.json'] = json.dumps({k: credentials[k] for k in keys}).encode()
        for name, content in payloads.items():
            info = tarfile.TarInfo(name)
            info.size = len(content)
            info.mode = 0o600
            archive.addfile(info, io.BytesIO(content))
    guest(octet, ['sudo', 'install', '-d', '-m', '700', '/root/sa6-private'])
    guest(octet, ['sudo', 'tar', '--no-same-owner', '-xf', '-', '-C', '/root/sa6-private'], input=stream.getvalue())
    print(f'192.168.15.{octet}: CA и необходимые файлы переданы', flush=True)
