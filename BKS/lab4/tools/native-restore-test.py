#!/usr/bin/env python3
"""Controlled CDC backup/restore test on ADMIN-LINUX; no topology/IP edits.

record -> fresh native backup -> mutate description -> restore -> verify.
Private context and backup passwords stay in the administrator's home directory.
Do not resubmit an accepted/uncertain restore request after a connection loss.
"""
from c4_lib import ApiConnector, C4Manager, Config
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('action', choices=['record', 'mutate', 'restore', 'verify'])
p.add_argument('--backup-name', required=True)
p.add_argument('--id-field', choices=['uuid', 'backup', 'backup_uuid', 'filename'], default='uuid')
args = p.parse_args()
os.umask(0o077)
h = Path.home()
context_file = h / 'bks4-restore-test-context.private.json'
cookie_file = h / '.bks4-native-restore-cookies.json'
password = (h / '.bks4-continent-admin-password').read_text().strip()
a = ApiConnector(ip='10.1.99.1', password=password, verbosity=False)
a.session.trust_env = False
if cookie_file.exists():
    a.session.cookies.update(json.loads(cookie_file.read_text()))
request = a.session.request
a.session.request = lambda *x, **k: request(*x, timeout=180, **k)
base = a.get_obj_url('active')
marker = 'BKS4 controlled native restore verification'


def fingerprints(api, url):
    fields = {
        'fwrule': ['uuid', 'name', 'is_enabled', 'src', 'dst', 'service', 'applications',
                   'app_profile', 'rule_action', 'passips', 'logging'],
        'natrule': ['uuid', 'name', 'is_enabled', 'src', 'dst', 'service', 'nat_type',
                    'address_type', 'value', 'port_type', 'port_value'],
        'netobject': ['uuid', 'name', 'ip', 'subtype'],
        'service': ['uuid', 'name', 'src', 'dst', 'proto'],
    }
    def normalize(x):
        if isinstance(x, dict):
            return x['uuid'] if 'uuid' in x else {k: normalize(v) for k, v in x.items()}
        if isinstance(x, list):
            return sorted((normalize(v) for v in x), key=lambda v: json.dumps(v, sort_keys=True))
        return x
    result = {}
    for kind, keys in fields.items():
        rows = api.get_from_endpoint(url + '/' + kind + '?view=full')
        # These base object classes expose full views; fall back to their ordinary
        # view only for classes whose scalar fields do not need link expansion.
        if 'data' not in rows and kind in ['netobject', 'service']:
            rows = api.get_from_endpoint(url + '/' + kind)
        rows = rows['data']
        if kind in ['netobject', 'service']:
            rows = sorted(rows, key=lambda x: x['uuid'])
        selected = [{k: normalize(row.get(k)) for k in keys} for row in rows]
        result[kind] = {'objects': len(rows), 'sha256': hashlib.sha256(
            json.dumps(selected, sort_keys=True, separators=(',', ':')).encode()).hexdigest()}
    return result


if args.action == 'record':
    assert not context_file.exists(), 'Existing restore context: inspect it before starting another test'
    assert a.config_lock_user().get('admin') is None
    obj = next(x for x in a.get_from_endpoint(base + '/netobject')['data'] if x['name'] == 'BKS4_WAN_TEST')
    context = dict(backup_name=args.backup_name, object_uuid=obj['uuid'],
                   original_description=obj.get('description', ''), policy=fingerprints(a, base))
    context_file.write_text(json.dumps(context))
    print('Baseline recorded; only description will be modified. Policy fingerprints:',
          json.dumps(context['policy']), flush=True)
    raise SystemExit(0)

context = json.loads(context_file.read_text())
assert context['backup_name'] == args.backup_name
if args.action == 'mutate':
    meta = json.loads((h / 'bks4-native-backup-metadata.json').read_text())
    assert meta['name'] == args.backup_name, 'Fresh backup has not been verified'
    assert a.config_lock_user().get('admin') is None
    m = C4Manager(Config(c4_ip='10.1.99.1', c4_password=password, verbosity=False))
    api = m.config_keeper.api
    api.session.trust_env = False
    assert m.open()
    try:
        r = api.put_to_endpoint(api.get_obj_url(m.config_keeper.uuid) + '/netobject/' +
                                context['object_uuid'], {'description': marker})
        assert r.get('uuid')
        assert m.save()
    except Exception:
        m.cancel()
        raise
    current = a.get_from_endpoint(base + '/netobject/' + context['object_uuid'])['data'][0]
    assert current['description'] == marker
    assert fingerprints(a, base) == context['policy']
    print('Control description changed; addresses, services, FW and NAT unchanged.', flush=True)
elif args.action == 'restore':
    state = context.get('restore_request', {})
    assert state.get('status') not in ['sending', 'accepted', 'uncertain'], 'Inspect previous restore; never resubmit blindly'
    meta = json.loads((h / 'bks4-native-backup-metadata.json').read_text())
    assert meta['name'] == args.backup_name
    archive = h / 'bks4-backups-private' / meta['filename']
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == meta['sha256']
    secret = (h / '.bks4-backup-password').read_text().strip()
    encoded = base64.b64encode(secret.encode()).decode()
    assert a.config_lock_user().get('admin') is None
    assert a.set_config_lock().get('status') == 'ok'
    cookie_file.write_text(json.dumps(a.session.cookies.get_dict()))
    state = dict(status='sending', backup_uuid=meta['uuid'], components=['cdc'], id_field=args.id_field)
    context['restore_request'] = state
    context_file.write_text(json.dumps(context))
    body = {args.id_field: meta['filename'] if args.id_field == 'filename' else meta['uuid'],
            'components': ['cdc'], 'password': encoded}
    try:
        r = a.post_to_endpoint(a._base_url_server + '/restore-backup', body)
        safe = json.dumps(r, ensure_ascii=False).replace(secret, '[redacted]').replace(encoded, '[redacted]')
        print('Native restore response:', safe, flush=True)
        state['status'] = 'accepted' if r.get('status') == 'ok' else 'validation_failed'
        state['tasks'] = r.get('tasks', [])
        context_file.write_text(json.dumps(context))
        assert state['status'] == 'accepted', 'Restore was not accepted; no automatic retry'
    except Exception:
        if state['status'] == 'sending':
            state['status'] = 'uncertain'
            context_file.write_text(json.dumps(context))
        raise
    finally:
        try:
            if state['status'] == 'validation_failed' and a.config_lock_user().get('is_current_session'):
                a.free_config_lock()
        except Exception:
            pass  # Recheck the lock after the controller returns; do not resubmit.
elif args.action == 'verify':
    tasks = context.get('restore_request', {}).get('tasks', [])
    assert len(tasks) == 1, 'Inspect the accepted native restore task'
    task = a.get_task(tasks[0])['data'][0]
    print('Native restore task:', task['uuid'], task['status'], task['processed'], task.get('messages'))
    assert task['status'] == 'done' and task['processed'] == 100
    current = a.get_from_endpoint(base + '/netobject/' + context['object_uuid'])['data'][0]
    restored = current.get('description', '') == context['original_description']
    same_policy = fingerprints(a, base) == context['policy']
    print('Original description restored:', restored)
    print('FW/NAT/address/service fingerprints unchanged:', same_policy)
    print('Native restore request:', json.dumps(context.get('restore_request', {})))
    assert restored and same_policy and context.get('restore_request', {}).get('status') == 'accepted'
    context['verified'] = True
    context['task_result'] = {k: task.get(k) for k in ['uuid', 'status', 'processed', 'messages']}
    context_file.write_text(json.dumps(context))
    lock = a.config_lock_user()
    if lock.get('is_current_session'):
        print('Release own completed-restore lock:', a.free_config_lock().get('status'))
    elif lock.get('admin'):
        print('Different session holds the lock; it was not changed.')
