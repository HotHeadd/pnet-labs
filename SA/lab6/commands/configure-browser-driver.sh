#!/bin/bash
# На WORKSTATION: драйвер для проверок браузерного SSO, слушает только loopback.
set -euo pipefail
cat > /etc/systemd/system/sa6-webdriver.service <<'UNIT'
[Unit]
Description=SA6 local browser test driver
After=lightdm.service

[Service]
User=labadmin
Environment=HOME=/home/labadmin
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/labadmin/.Xauthority
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
ExecStart=/usr/bin/WebKitWebDriver --host=local --port=4444
Restart=on-failure
UNIT
sed 's/--port=4444/--port=4445/' /etc/systemd/system/sa6-webdriver.service > /etc/systemd/system/sa6-webdriver-bob.service
systemctl daemon-reload
systemctl start sa6-webdriver sa6-webdriver-bob
systemctl is-active sa6-webdriver sa6-webdriver-bob
