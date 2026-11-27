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
apt-get install -y --no-install-recommends xfce4 xfce4-terminal lightdm dbus-x11 xpra python3-pil python3-gi-cairo xdotool xterm epiphany-browser webkit2gtk-driver sssd-ldap libnss-sss libpam-sss ldap-utils nfs-common acl ca-certificates sshpass python3-pip
