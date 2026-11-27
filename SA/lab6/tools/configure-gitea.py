#!/usr/bin/env python3
"""На WEB от root: служебный администратор и источник OIDC Keycloak."""
import json
from pathlib import Path
import subprocess

credentials = json.loads(Path('/root/sa6-private/web-credentials.json').read_text())
prefix = ['docker', 'exec', '--user', 'git', 'sa6-gitea', 'gitea',
    '--config', '/data/gitea/conf/app.ini']


def cli(arguments):
    result = subprocess.run(prefix + arguments, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True)
    return result.returncode, result.stdout


status, users = cli(['admin', 'user', 'list'])
if status:
    raise SystemExit('Gitea user list failed')
if 'labadmin' not in users.split():
    status, _ = cli(['admin', 'user', 'create', '--username', 'labadmin',
        '--password', credentials['gitea_admin'], '--email', 'admin@sa6.test',
        '--admin', '--must-change-password=false'])
    if status:
        raise SystemExit('Gitea administrator creation failed')
status, sources = cli(['admin', 'auth', 'list'])
if status:
    raise SystemExit('Gitea authentication source list failed')
if 'Keycloak' not in sources:
    status, _ = cli(['admin', 'auth', 'add-oauth', '--name', 'Keycloak',
        '--provider', 'openidConnect', '--key', 'gitea', '--secret', credentials['gitea_oidc'],
        '--auto-discover-url', 'https://auth.sa6.test/realms/sa6/.well-known/openid-configuration',
        '--scopes', 'openid', '--scopes', 'profile', '--scopes', 'email'])
    if status:
        raise SystemExit('Gitea OIDC source creation failed')
result = subprocess.run(['docker', 'restart', 'sa6-gitea'], stdout=subprocess.DEVNULL)
if result.returncode:
    raise SystemExit('Gitea restart failed')
print('Gitea: administrator and Keycloak OIDC source configured')
