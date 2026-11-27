#!/bin/bash
# На APPS от root, после завершения установки пакетов.
set -euo pipefail
umask 077
dpkg-query -W -f='${db:Status-Status}\n' tryton-server tryton-modules-party tryton-modules-ldap-authentication postgresql
python3 -c 'import psycopg2'
test -s /root/sa6-private/apps.key
getent passwd alice >/dev/null
systemctl stop tryton-server
systemctl enable --now postgresql
if ! runuser -u postgres -- psql -Atqc "SELECT 1 FROM pg_roles WHERE rolname='tryton'" | grep -qx 1; then
    runuser -u postgres -- createuser tryton
fi
if ! runuser -u postgres -- psql -Atqc "SELECT 1 FROM pg_database WHERE datname='sa6'" | grep -qx 1; then
    runuser -u postgres -- createdb -O tryton -E UTF8 -T template0 sa6
fi
install -d -m 750 -o tryton -g tryton /etc/tryton/tls /var/lib/tryton
install -m 640 -o tryton -g tryton /root/sa6-private/apps.crt /etc/tryton/tls/server.crt
install -m 640 -o tryton -g tryton /root/sa6-private/apps.key /etc/tryton/tls/server.key
cat > /etc/tryton/trytond.conf <<'CONF'
[web]
listen = 10.60.0.20:8000
hostname = apps.sa6.test

[database]
uri = postgresql://tryton@/
path = /var/lib/tryton
list = True
language = en

[ssl]
certificate = /etc/tryton/tls/server.crt
privatekey = /etc/tryton/tls/server.key

[session]
authentications = ldap,password

[ldap_authentication]
uri = ldaps://directory.sa6.test/ou=People,dc=sa6,dc=test?uid?subtree
uid = uid
create_user = False
CONF
chown root:tryton /etc/tryton/trytond.conf
chmod 640 /etc/tryton/trytond.conf
# Временный файл пароля доступен только служебному пользователю Tryton.
python3 - <<'PY'
import json, os, pwd
from pathlib import Path
p = Path('/var/lib/tryton/.sa6-admin-password')
p.write_text(json.loads(Path('/root/sa6-private/directory-credentials.json').read_text())['tryton_admin'] + '\n')
p.chmod(0o600)
u = pwd.getpwnam('tryton')
os.chown(p, u.pw_uid, u.pw_gid)
PY
trap 'rm -f /var/lib/tryton/.sa6-admin-password' EXIT
runuser -u tryton -- env TRYTONPASSFILE=/var/lib/tryton/.sa6-admin-password \
    trytond-admin -c /etc/tryton/trytond.conf -d sa6 --all --email admin@sa6.test
runuser -u tryton -- trytond-admin -c /etc/tryton/trytond.conf -d sa6 --update-modules-list
runuser -u tryton -- trytond-admin -c /etc/tryton/trytond.conf -d sa6 \
    -u ldap_authentication party --activate-dependencies
runuser -u tryton -- python3 - <<'PY'
from trytond.config import config
config.update_etc('/etc/tryton/trytond.conf')
from trytond.pool import Pool
from trytond.transaction import Transaction
pool = Pool('sa6')
pool.init()
with Transaction().start('sa6', 0) as transaction:
    User = pool.get('res.user')
    Data = pool.get('ir.model.data')
    Party = pool.get('party.party')
    group_id = Data.get_id('party', 'group_party_admin')
    users = User.search([('login', '=', 'alice')])
    if not users:
        users = User.create([{'name': 'Alice SA6', 'login': 'alice',
            'email': 'alice@sa6.test', 'groups': [('add', [group_id])]}])
    if not Party.search([('name', '=', 'SA6 Project')]):
        Party.create([{'name': 'SA6 Project'}])
    assert not User.search([('login', '=', 'bob')]), 'Bob already has an application account; review access'
    transaction.commit()
    print('Tryton: Alice provisioned; Bob has no application account')
PY
systemctl enable --now tryton-server
systemctl is-active tryton-server
