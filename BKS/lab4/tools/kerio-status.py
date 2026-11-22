"""Read a public status summary without credentials, license numbers or download tokens."""
import importlib.util
import json
import os
from datetime import datetime, timezone
from pathlib import Path
os.environ.setdefault('KERIO_URL','https://10.1.99.1:4081/admin/api/jsonrpc/')
os.environ.setdefault('KERIO_PASSWORD_FILE',str(Path.home()/'.bks4-kerio-password'))
s=importlib.util.spec_from_file_location('api',Path(__file__).with_name('kerio-api.py'))
api=importlib.util.module_from_spec(s)
s.loader.exec_module(api)
k=api.Kerio()
k.login()
print('UTC:',datetime.now(timezone.utc).isoformat())
methods=['ProductInfo.get','ProductRegistration.getFullStatus','Session.getLoginType',
         'Antivirus.get','Antivirus.getUpdateStatus','IntrusionPrevention.getUpdateStatus',
         'IntrusionPrevention.get','ContentFilter.getUrlFilterConfig','Geoip.get','TrafficPolicy.get']
for method in methods:
    try:
        r=k.call(method)
        if method=='ProductInfo.get':
            r={x:y for x,y in r['productInfo'].items() if x in ['versionString','licenseSet','passwordSet']}
        elif method=='ProductRegistration.getFullStatus':
            r={x:y for x,y in r['status'].items() if x in ['regType','users','expirations']}
        elif method=='Antivirus.get':
            v=r['config']['antivirus']
            r={'status':v['status'],'available':v['internal']['available'],'expired':v['internal']['expired']}
        elif method=='Antivirus.getUpdateStatus':
            v=r['status'];r={x:v[x] for x in ['phase','percentage','databaseVersion','engineVersion']}
        elif method=='IntrusionPrevention.get':
            r={x:r['config'][x] for x in ['enabled','high','medium','low']}
        elif method=='TrafficPolicy.get':
            r={'rules':len(r['list']),'temporary_ssh':any(x['name']=='BKS4-Temporary-SSH' for x in r['list'])}
        print(method,json.dumps(r,ensure_ascii=False))
    except Exception as e:
        try:v=json.loads(str(e));print(method,'ERROR',v.get('code'),v.get('message'))
        except ValueError:print(method,'ERROR',type(e).__name__)
        k.login()
k.call('Session.logout')
