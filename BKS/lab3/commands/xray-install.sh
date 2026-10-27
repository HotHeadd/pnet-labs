#!/bin/bash
set -euo pipefail
name=$1
id xray >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin xray
install -m 755 /tmp/bks3/xray /usr/local/bin/xray
install -d -o root -g xray -m 750 /etc/xray
install -d -o xray -g xray -m 750 /var/log/xray
install -o root -g xray -m 640 /tmp/bks3/configs/$name-xray.json /etc/xray/config.json
install -m 644 /tmp/bks3/configs/xray.service /etc/systemd/system/xray.service
# CA and leaf certificates are provisioned separately, private keys mode 640 root:xray.
chown -R xray:xray /var/log/xray
runuser -u xray -- /usr/local/bin/xray run -test -config /etc/xray/config.json
systemctl daemon-reload
systemctl enable --now xray
systemctl restart xray
