#!/bin/bash
set -euo pipefail
# CA предварительно передаётся из DIRECTORY в /root/sa6-private/ca.crt.
install -m 644 /root/sa6-private/ca.crt /usr/local/share/ca-certificates/sa6-ca.crt
update-ca-certificates
grep -q 'auth.sa6.test' /etc/hosts || printf '10.60.0.30 auth.sa6.test vault.sa6.test git.sa6.test\n' >> /etc/hosts
install -d -m 755 /etc/sssd
cat > /etc/sssd/sssd.conf <<'CONF'
[sssd]
config_file_version = 2
services = nss, pam
domains = sa6.test

[domain/sa6.test]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldaps://directory.sa6.test
ldap_search_base = dc=sa6,dc=test
ldap_user_search_base = ou=People,dc=sa6,dc=test
ldap_group_search_base = ou=Groups,dc=sa6,dc=test
ldap_schema = rfc2307
ldap_tls_reqcert = demand
ldap_tls_cacert = /usr/local/share/ca-certificates/sa6-ca.crt
cache_credentials = true
enumerate = false
fallback_homedir = /home/%u
default_shell = /bin/bash

[pam]
offline_credentials_expiration = 1
CONF
chmod 600 /etc/sssd/sssd.conf
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nsswitch.conf')
lines=p.read_text().splitlines()
for i,line in enumerate(lines):
    if line.split(':',1)[0] in ['passwd','group','shadow'] and 'sss' not in line.split():
        lines[i]=line+' sss'
p.write_text('\n'.join(lines)+'\n')
PY
pam-auth-update --package --enable sss --enable mkhomedir
systemctl enable --now sssd
systemctl restart sssd
install -d -m 755 /mnt/team
grep -q '/mnt/team ' /etc/fstab || printf 'directory.sa6.test:/srv/nfs/team /mnt/team nfs4 rw,sec=sys,_netdev 0 0\n' >> /etc/fstab
mount /mnt/team
getent passwd alice bob
id alice
id bob
findmnt /mnt/team
