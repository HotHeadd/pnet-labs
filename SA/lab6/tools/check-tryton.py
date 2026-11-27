#!/usr/bin/env python3
"""На WORKSTATION от root: отдельная аутентификация и чтение в Tryton."""
import base64
import json
from pathlib import Path
import ssl
import urllib.error
import urllib.request

credentials = json.loads(Path('/root/sa6-private/directory-credentials.json').read_text())
opener = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=ssl.create_default_context()))


def rpc(method, params, session=None):
    headers = {'Content-Type': 'application/json'}
    if session:
        headers['Authorization'] = 'Session ' + base64.b64encode(session.encode()).decode()
    request = urllib.request.Request('https://apps.sa6.test:8000/sa6/',
        data=json.dumps({'id': 1, 'method': method, 'params': params}).encode(),
        headers=headers)
    try:
        with opener.open(request, timeout=20) as response:
            result = json.load(response)
            if result.get('error'):
                raise RuntimeError(method + ': RPC error')
            return response.status, result['result']
    except urllib.error.HTTPError as exc:
        return exc.code, None


status, result = rpc('common.db.login', ['alice', {'password': credentials['alice']}])
print('Tryton login alice: HTTP ' + str(status), flush=True)
assert status == 200 and isinstance(result, list) and len(result) == 2
session = ':'.join(map(str, ['alice'] + result))
try:
    status, ids = rpc('model.party.party.search', [[('name', '=', 'SA6 Project')], 0, 10, None, {}], session)
    assert status == 200 and ids
    status, rows = rpc('model.party.party.read', [ids, ['name'], {}], session)
    assert status == 200 and rows
    print('Alice reads Party: ' + ', '.join(row['name'] for row in rows), flush=True)
finally:
    rpc('common.db.logout', [], session)
status, result = rpc('common.db.login', ['bob', {'password': credentials['bob']}])
print('Tryton login bob: HTTP ' + str(status), flush=True)
assert status == 401
print('HTTPS: system CA and hostname verification succeeded', flush=True)
