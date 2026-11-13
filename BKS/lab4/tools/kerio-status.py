"""Read a public licensing/module summary without exporting license numbers."""
import importlib.util
import json
import os
from datetime import datetime, timezone
from pathlib import Path

os.environ.setdefault('KERIO_URL', 'https://10.1.99.1:4081/admin/api/jsonrpc/')
os.environ.setdefault('KERIO_PASSWORD_FILE', str(Path.home() / '.bks4-kerio-password'))
s = importlib.util.spec_from_file_location('kerio_api', Path(__file__).with_name('kerio-api.py'))
api = importlib.util.module_from_spec(s)
s.loader.exec_module(api)
print('UTC:', datetime.now(timezone.utc).isoformat())
for method in ['ProductInfo.get', 'ProductRegistration.getFullStatus', 'Session.getLoginType',
               'Antivirus.get', 'IntrusionPrevention.get', 'Logs.getLogSet', 'Configuration.exportConfig']:
    k = api.Kerio()
    try:
        k.login()
        params = {'options': {'certificates': True, 'dhcpLeases': True, 'stats': False}} if method == 'Configuration.exportConfig' else {}
        r = k.call(method, params)
        if method == 'ProductInfo.get':
            r = {key: val for key, val in r['productInfo'].items() if key in ['versionString', 'licenseSet', 'passwordSet']}
        elif method == 'ProductRegistration.getFullStatus':
            r = {key: val for key, val in r['status'].items() if key in ['regType', 'users', 'expirations']}
        elif method == 'Antivirus.get':
            av = r.get('config', r)['antivirus']
            r = {'status': av['status'], 'available': av['internal']['available'], 'expired': av['internal']['expired']}
        print(method, json.dumps(r, ensure_ascii=False))
        k.call('Session.logout')
    except Exception as e:
        print(method, 'ERROR', str(e))
