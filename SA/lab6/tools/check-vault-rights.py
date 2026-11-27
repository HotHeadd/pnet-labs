#!/usr/bin/env python3
"""На WORKSTATION: проверить права из открытого разблокированного vault Bob.

Токен остаётся в памяти браузера ВМ. PUT отправляет прежнее зашифрованное
содержимое демонстрационной записи, чтобы проверить отказ сервера.
"""
import os
import sys
import time

os.environ['SA6_BROWSER_PORT'] = '4445'
sys.path.insert(0, '/opt/sa6-tools')
import browser as b

b.script("""
const original = window.fetch;
window.fetch = async function(request, init) {
  const headers = new Headers(init && init.headers || request.headers);
  const authorization = headers.get('authorization');
  if (authorization) window.__sa6auth = authorization;
  return original.call(this, request, init);
};
""")
b.click('a[href="#/vault"]')
b.click('button:has(dynamic-avatar)')
b.click("//*[@role='menuitem' and contains(.,'Account settings')]", using='xpath')
for _ in range(20):
    if b.script('return Boolean(window.__sa6auth)'):
        break
    time.sleep(0.2)
result = b.script("""
function request(method, path, body) {
  const xhr = new XMLHttpRequest();
  xhr.open(method, '/api/' + path, false);
  xhr.setRequestHeader('Authorization', window.__sa6auth);
  if (body) xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.send(body ? JSON.stringify(body) : null);
  return {status: xhr.status, data: JSON.parse(xhr.responseText)};
}
const sync = request('GET', 'sync');
if (sync.status !== 200) return {syncStatus: sync.status};
const shared = request('GET', 'ciphers/903fa650-4bb0-4844-90d7-2c9750af6e4d');
const privateItem = request('GET', 'ciphers/50077545-1b4e-4d19-a951-aed5388ebb83');
const before = shared.data.revisionDate;
shared.data.encryptedFor = sync.data.profile.id;
const write = request('PUT', 'ciphers/' + shared.data.id, shared.data);
const after = request('GET', 'ciphers/' + shared.data.id);
return {
  email: sync.data.profile.email,
  collections: sync.data.collections.length,
  readOnly: sync.data.collections[0].readOnly,
  manage: sync.data.collections[0].manage,
  sharedStatus: shared.status,
  privateStatus: privateItem.status,
  privateError: privateItem.data.message,
  writeStatus: write.status,
  writeError: write.data.message,
  revisionUnchanged: before === after.data.revisionDate
};
""")
assert result['email'] == 'bob@sa6.test'
assert result['collections'] == 1 and result['readOnly'] and not result['manage']
assert result['sharedStatus'] == 200
assert result['privateStatus'] == 400 and result['privateError'] == 'Cipher is not owned by user'
assert result['writeStatus'] == 400 and result['writeError'] == 'Cipher is not write accessible'
assert result['revisionUnchanged']
print('user=bob@sa6.test; collection=Shared; readOnly=true; manage=false')
print('GET Shared demo account: HTTP 200')
print('GET Private demo account: HTTP 400; ' + result['privateError'])
print('PUT Shared demo account: HTTP 400; ' + result['writeError'])
print('shared_revision_unchanged=true')
