#!/usr/bin/env python3
"""На WORKSTATION от root: LDAP bind и SSH/PAM, без вывода паролей."""
import json
import os
from pathlib import Path
import subprocess

os.umask(0o077)
private = Path('/root/sa6-private')
credentials = json.loads((private / 'directory-credentials.json').read_text())
for user in ['alice', 'bob']:
    password = private / (user + '-password')
    password.write_text(credentials[user])
    password.chmod(0o600)
    ldap = subprocess.run(['ldapwhoami', '-x', '-H', 'ldaps://directory.sa6.test',
        '-D', 'uid=' + user + ',ou=People,dc=sa6,dc=test', '-y', str(password)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=20)
    print('LDAP ' + user + ': exit=' + str(ldap.returncode), flush=True)
    print(ldap.stdout.strip(), flush=True)
    ssh = subprocess.run(['sshpass', '-f', str(password), 'ssh',
        '-o', 'StrictHostKeyChecking=accept-new', '-o', 'PubkeyAuthentication=no',
        '-o', 'PreferredAuthentications=password', '-o', 'NumberOfPasswordPrompts=1',
        '-o', 'ConnectTimeout=5', user + '@apps.sa6.test', 'id'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=20)
    print('SSH ' + user + ': exit=' + str(ssh.returncode), flush=True)
    print(ssh.stdout.strip(), flush=True)
