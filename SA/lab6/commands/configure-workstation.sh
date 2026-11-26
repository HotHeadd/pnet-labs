#!/bin/bash
set -euo pipefail
install -d -m 755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-sa6.conf <<'CONF'
[Seat:*]
autologin-user=labadmin
autologin-user-timeout=0
user-session=xfce
CONF
systemctl set-default graphical.target
systemctl enable --now lightdm
sudo -u labadmin mkdir -p /home/labadmin/.ssh
sudo -u labadmin ssh-keygen -q -t ed25519 -N '' -f /home/labadmin/.ssh/sa6-alice
