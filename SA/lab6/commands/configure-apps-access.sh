#!/bin/bash
set -euo pipefail
cat > /etc/ssh/sshd_config.d/00-sa6-ldap.conf <<'CONF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
AllowGroups sudo xpra-users
CONF
sshd -t
systemctl reload ssh
sshd -T | grep -E '^(allowgroups|passwordauthentication|usepam) '
