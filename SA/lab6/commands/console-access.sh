#!/bin/bash
set -euo pipefail
# Консоль доступна через авторизованную сессию PNETLab.
# Не прерывать уже открытый локальный сеанс человека.
if who | awk '$2 == "tty1" {found=1} END {exit !found}'; then
    printf 'tty1 уже занят: настройка консоли отменена\n' >&2
    exit 1
fi
id labadmin >/dev/null
install -d -m 755 /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/sa6.conf <<'CONF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin labadmin --noclear %I linux
CONF
systemctl daemon-reload
systemctl restart getty@tty1
