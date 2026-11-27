#!/usr/bin/env python3
"""На WEB от root: LDAP-федерация и два OIDC-клиента, без вывода секретов."""
import json
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

private = Path('/root/sa6-private')
web = json.loads((private / 'web-credentials.json').read_text())
directory = json.loads((private / 'directory-credentials.json').read_text())
base = 'http://127.0.0.1:8080'
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
body = urllib.parse.urlencode({'grant_type': 'password', 'client_id': 'admin-cli',
    'username': 'labadmin', 'password': web['kc_admin']}).encode()
with opener.open(urllib.request.Request(base + '/realms/master/protocol/openid-connect/token',
        data=body), timeout=20) as response:
    token = json.load(response)['access_token']


def api(method, path, value=None):
    request = urllib.request.Request(base + '/admin/realms' + path, method=method,
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'},
        data=json.dumps(value).encode() if value is not None else None)
    try:
        with opener.open(request, timeout=30) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as exc:
        raise RuntimeError('Keycloak API: ' + method + ' ' + path + ' HTTP ' + str(exc.code)) from None


if not any(realm['realm'] == 'sa6' for realm in api('GET', '')):
    api('POST', '', {'realm': 'sa6', 'enabled': True, 'sslRequired': 'external',
        'registrationAllowed': False, 'verifyEmail': False, 'loginWithEmailAllowed': True})
realm = api('GET', '/sa6')
api('PUT', '/sa6', {'eventsEnabled': True, 'eventsExpiration': 86400, 'accessTokenLifespan': 900,
    'enabledEventTypes': ['LOGIN', 'LOGIN_ERROR', 'CODE_TO_TOKEN']})
config = {key: [value] for key, value in {
    'enabled': 'true', 'priority': '0', 'vendor': 'other', 'editMode': 'READ_ONLY',
    'importEnabled': 'true', 'syncRegistrations': 'false', 'cachePolicy': 'DEFAULT',
    'usernameLDAPAttribute': 'uid', 'rdnLDAPAttribute': 'uid',
    'uuidLDAPAttribute': 'entryUUID', 'userObjectClasses': 'inetOrgPerson',
    'connectionUrl': 'ldaps://directory.sa6.test:636',
    'usersDn': 'ou=People,dc=sa6,dc=test', 'authType': 'simple',
    'bindDn': 'uid=svc-keycloak,ou=Services,dc=sa6,dc=test',
    'bindCredential': directory['svc_keycloak'], 'searchScope': '2',
    'useTruststoreSpi': 'always', 'connectionPooling': 'true', 'pagination': 'true',
    'fullSyncPeriod': '-1', 'changedSyncPeriod': '-1', 'batchSizeForSync': '1000'
}.items()}
provider = {'name': 'sa6-ldap', 'providerId': 'ldap',
    'providerType': 'org.keycloak.storage.UserStorageProvider',
    'parentId': realm['id'], 'config': config}
components = api('GET', '/sa6/components?name=sa6-ldap')
if components:
    provider['id'] = components[0]['id']
    api('PUT', '/sa6/components/' + provider['id'], provider)
else:
    api('POST', '/sa6/components', provider)
provider_id = api('GET', '/sa6/components?name=sa6-ldap')[0]['id']
sync = api('POST', '/sa6/user-storage/' + provider_id + '/sync?action=triggerFullSync')
assert sync.get('failed', 0) == 0, 'LDAP sync failed'
print('LDAP full sync: added=' + str(sync.get('added')) + ' updated=' + str(sync.get('updated')))
for name in ['alice', 'bob']:
    users = api('GET', '/sa6/users?username=' + name + '&exact=true')
    assert len(users) == 1 and users[0].get('federationLink') == provider_id
    api('PUT', '/sa6/users/' + users[0]['id'], {'emailVerified': True})
    print(name + ': imported from LDAP')

for name, secret, callback, origin in [
    ('vaultwarden', web['vault_oidc'], 'https://vault.sa6.test/identity/connect/oidc-signin', 'https://vault.sa6.test'),
    ('gitea', web['gitea_oidc'], 'https://git.sa6.test/user/oauth2/Keycloak/callback', 'https://git.sa6.test')]:
    client = {'clientId': name, 'name': name, 'enabled': True, 'protocol': 'openid-connect',
        'publicClient': False, 'secret': secret, 'standardFlowEnabled': True,
        'directAccessGrantsEnabled': False, 'serviceAccountsEnabled': False,
        'redirectUris': [callback], 'webOrigins': [origin],
        'defaultClientScopes': ['profile', 'email', 'roles', 'web-origins'],
        'optionalClientScopes': ['offline_access']}
    clients = api('GET', '/sa6/clients?clientId=' + name)
    if clients:
        client['id'] = clients[0]['id']
        api('PUT', '/sa6/clients/' + client['id'], client)
    else:
        api('POST', '/sa6/clients', client)
    if name == 'gitea':
        client_id = api('GET', '/sa6/clients?clientId=gitea')[0]['id']
        path = '/sa6/clients/' + client_id + '/protocol-mappers/models'
        if not any(mapper['name'] == 'sa6-nickname' for mapper in api('GET', path)):
            api('POST', path, {'name': 'sa6-nickname', 'protocol': 'openid-connect',
                'protocolMapper': 'oidc-usermodel-property-mapper', 'config': {
                    'user.attribute': 'username', 'claim.name': 'nickname',
                    'jsonType.label': 'String', 'id.token.claim': 'true',
                    'access.token.claim': 'true', 'userinfo.token.claim': 'true'}})
    print('OIDC client ready: ' + name)
