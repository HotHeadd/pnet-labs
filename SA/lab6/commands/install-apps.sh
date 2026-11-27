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
apt-get install -y --no-install-recommends xpra python3-pil xdotool xvfb xserver-xorg-video-dummy xauth dbus-x11 x11-xserver-utils fonts-dejavu-core xterm tryton-client tryton-server tryton-modules-ldap-authentication tryton-modules-party postgresql python3-psycopg2 sssd-ldap libnss-sss libpam-sss ldap-utils nfs-common acl ca-certificates tryton-proteus
