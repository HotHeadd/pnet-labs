#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Настройки загрузки пакетов для канала стенда.
cat > /etc/apt/apt.conf.d/90-sa6-network <<'CONF'
Acquire::ForceIPv4 "true";
Acquire::Languages "none";
Acquire::Retries "2";
Acquire::IndexTargets::deb::CNF::DefaultEnabled "false";
CONF
sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list
apt-get update
apt-get install -y xpra xterm tryton-client tryton-server tryton-modules-ldap-authentication tryton-modules-party postgresql sssd-ldap libnss-sss libpam-sss ldap-utils nfs-common acl ca-certificates python3-proteus
