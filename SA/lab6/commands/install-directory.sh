#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
printf 'slapd slapd/no_configuration boolean true\n' | debconf-set-selections
# Настройки загрузки пакетов для канала стенда.
cat > /etc/apt/apt.conf.d/90-sa6-network <<'CONF'
Acquire::ForceIPv4 "true";
Acquire::Languages "none";
Acquire::Retries "2";
Acquire::IndexTargets::deb::CNF::DefaultEnabled "false";
CONF
sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list
apt-get update
apt-get install -y slapd ldap-utils nfs-kernel-server acl openssl
