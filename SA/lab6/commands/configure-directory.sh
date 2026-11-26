#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
umask 077
install -d -m 700 /root/sa6-private
python3 - <<'PY'
from pathlib import Path
import json, secrets, subprocess
p = Path('/root/sa6-private/credentials.json')
if not p.exists():
    p.write_text(json.dumps({n: secrets.token_urlsafe(18) for n in
        ['ldap_admin', 'alice', 'bob', 'svc_keycloak', 'tryton_admin']}, indent=2))
    p.chmod(0o600)
s = json.loads(p.read_text())
values = ('slapd slapd/no_configuration boolean false\n'
          'slapd slapd/domain string sa6.test\n'
          'slapd shared/organization string SA6 Lab\n'
          'slapd slapd/backend select MDB\n'
          'slapd slapd/purge_database boolean false\n'
          'slapd slapd/move_old_database boolean true\n'
          f'slapd slapd/password1 password {s["ldap_admin"]}\n'
          f'slapd slapd/password2 password {s["ldap_admin"]}\n')
subprocess.run(['debconf-set-selections'], input=values.encode(), check=True)
Path('/root/sa6-private/ldap-admin-password').write_text(s['ldap_admin'])
PY
dpkg-reconfigure -f noninteractive slapd

# Собственный CA и отдельные сертификаты серверов.
cd /root/sa6-private
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -sha256 -subj '/CN=SA6 Lab CA' -keyout ca.key -out ca.crt 2>/dev/null
for server in directory apps web; do
    case "$server" in
        directory) san='DNS:directory.sa6.test,IP:10.60.0.10';;
        apps) san='DNS:apps.sa6.test,IP:10.60.0.20';;
        web) san='DNS:auth.sa6.test,DNS:vault.sa6.test,DNS:git.sa6.test,IP:10.60.0.30';;
    esac
    openssl req -newkey rsa:2048 -nodes -sha256 -subj "/CN=$server.sa6.test" -keyout "$server.key" -out "$server.csr" 2>/dev/null
    printf 'subjectAltName=%s\nextendedKeyUsage=serverAuth\n' "$san" > "$server.ext"
    openssl x509 -req -in "$server.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -sha256 -extfile "$server.ext" -out "$server.crt" 2>/dev/null
done
install -m 644 ca.crt /usr/local/share/ca-certificates/sa6-ca.crt
update-ca-certificates
install -d -m 750 -o root -g openldap /etc/ldap/tls
install -m 644 ca.crt directory.crt /etc/ldap/tls/
install -m 640 -o root -g openldap directory.key /etc/ldap/tls/
cat > /root/sa6-private/ldap-tls.ldif <<'LDIF'
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/tls/ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/directory.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/directory.key
LDIF
ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/sa6-private/ldap-tls.ldif
sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap://10.60.0.10/ ldaps://10.60.0.10/ ldapi:///"|' /etc/default/slapd
systemctl restart slapd

# Каталог содержит POSIX-идентичности пользователей и отдельную группу Xpra.
python3 - <<'PY'
from pathlib import Path
import base64, hashlib, json, secrets
s = json.loads(Path('/root/sa6-private/credentials.json').read_text())
def hashed(p):
    salt=secrets.token_bytes(8)
    return '{SSHA}'+base64.b64encode(hashlib.sha1(p.encode()+salt).digest()+salt).decode()
entries=[]
for ou in ['People','Groups','Services']:
    entries.append(f'dn: ou={ou},dc=sa6,dc=test\nobjectClass: organizationalUnit\nou: {ou}\n')
for name, uid, gid, cn, sn in [('alice',10001,10000,'Alice Lab','Lab'),('bob',10002,10001,'Bob Lab','Lab')]:
    entries.append(f'''dn: uid={name},ou=People,dc=sa6,dc=test
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: {name}
cn: {cn}
sn: {sn}
givenName: {cn.split()[0]}
mail: {name}@sa6.test
uidNumber: {uid}
gidNumber: {gid}
homeDirectory: /home/{name}
loginShell: /bin/bash
userPassword: {hashed(s[name])}
''')
for name,gid,members in [('staff',10000,['alice']),('guests',10001,['bob']),('xpra-users',10010,['alice'])]:
    entries.append(f'dn: cn={name},ou=Groups,dc=sa6,dc=test\nobjectClass: posixGroup\ncn: {name}\ngidNumber: {gid}\n'+''.join(f'memberUid: {u}\n' for u in members))
entries.append(f'''dn: uid=svc-keycloak,ou=Services,dc=sa6,dc=test
objectClass: inetOrgPerson
uid: svc-keycloak
cn: Keycloak Directory Reader
sn: Reader
userPassword: {hashed(s['svc_keycloak'])}
''')
Path('/root/sa6-private/users.ldif').write_text('\n'.join(entries))
PY
ldapadd -x -H ldaps://directory.sa6.test -D cn=admin,dc=sa6,dc=test -y /root/sa6-private/ldap-admin-password -f /root/sa6-private/users.ldif

# Общий каталог доступен staff. NFS AUTH_SYS доверяет UID/GID клиентов.
install -d -m 2770 -o 10001 -g 10000 /srv/nfs/team
setfacl -m d:u::rwx,d:g::rwx,d:o::--- /srv/nfs/team
printf 'Shared SA6 document\n' > /srv/nfs/team/project.txt
chown 10001:10000 /srv/nfs/team/project.txt
chmod 660 /srv/nfs/team/project.txt
printf '/srv/nfs/team 10.60.0.20(rw,sync,no_subtree_check,root_squash) 10.60.0.100(rw,sync,no_subtree_check,root_squash)\n' > /etc/exports
exportfs -ra
systemctl enable --now nfs-kernel-server
printf '10.60.0.30 auth.sa6.test vault.sa6.test git.sa6.test\n' >> /etc/hosts
ldapsearch -x -H ldaps://directory.sa6.test -b ou=People,dc=sa6,dc=test '(uid=*)' uid uidNumber gidNumber
exportfs -v
