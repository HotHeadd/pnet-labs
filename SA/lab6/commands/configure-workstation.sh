#!/bin/bash
set -euo pipefail
if [ ! -f /var/swap.sa6 ]; then
    fallocate -l 1G /var/swap.sa6
    chmod 600 /var/swap.sa6
    mkswap /var/swap.sa6
fi
if ! swapon --noheadings --show=NAME | grep -qx /var/swap.sa6; then
    swapon /var/swap.sa6
fi
if ! grep -q '^/var/swap.sa6 ' /etc/fstab; then
    printf '/var/swap.sa6 none swap sw 0 0\n' >> /etc/fstab
fi
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
if [ ! -s /home/labadmin/.ssh/sa6-alice ]; then
    sudo -u labadmin ssh-keygen -q -t ed25519 -N '' -f /home/labadmin/.ssh/sa6-alice
fi
