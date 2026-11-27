#!/usr/bin/env python3
"""На WEB: проверить федерацию, OIDC-клиентов и общий сеанс SSO Alice."""
import datetime
import json
from pathlib import Path
import urllib.parse
import urllib.request

credentials = json.loads(Path('/root/sa6-private/web-credentials.json').read_text())
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
body = urllib.parse.urlencode({'grant_type': 'password', 'client_id': 'admin-cli',
    'username': 'labadmin', 'password': credentials['kc_admin']}).encode()
base = 'http://127.0.0.1:8080'
with opener.open(urllib.request.Request(base + '/realms/master/protocol/openid-connect/token',
        data=body), timeout=20) as response:
    token = json.load(response)['access_token']


def get(path):
    request = urllib.request.Request(base + '/admin/realms/sa6' + path,
        headers={'Authorization': 'Bearer ' + token})
    with opener.open(request, timeout=20) as response:
        return json.load(response)


provider, = get('/components?name=sa6-ldap')
config = provider['config']
print('LDAP: ' + config['connectionUrl'][0])
print('editMode=' + config['editMode'][0] + '; usernameAttribute=' + config['usernameLDAPAttribute'][0])
for name in ['alice', 'bob']:
    user, = get('/users?username=' + name + '&exact=true')
    assert user['federationLink'] == provider['id']
    print(name + ': federated LDAP identity')
    if name == 'alice':
        alice = user
for name in ['gitea', 'vaultwarden']:
    client, = get('/clients?clientId=' + name)
    assert client['standardFlowEnabled'] and not client['publicClient']
    print(name + ': confidential; Authorization Code flow')
    print('redirect_uri=' + client['redirectUris'][0])
events = get('/events?type=LOGIN&user=' + alice['id'] + '&max=100')
sessions = {}
for event in events:
    if event.get('sessionId') and event.get('clientId') in ['gitea', 'vaultwarden']:
        sessions.setdefault(event['sessionId'], {})[event['clientId']] = event
pairs = [items for items in sessions.values() if set(items) == {'gitea', 'vaultwarden'}]
if not pairs:
    raise SystemExit('No shared SSO session found for both clients yet')
pair = max(pairs, key=lambda items: max(event['time'] for event in items.values()))
for event in sorted(pair.values(), key=lambda item: item['time']):
    when = datetime.datetime.fromtimestamp(event['time'] / 1000, datetime.timezone.utc).isoformat()
    print('LOGIN alice client=' + event['clientId'] + ' time=' + when)
print('same_keycloak_session=true')
