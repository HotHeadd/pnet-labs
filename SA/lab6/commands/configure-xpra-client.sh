#!/bin/bash
# На WORKSTATION. Публичный ключ sa6-alice уже добавлен на APPS.
set -euo pipefail
test -s /home/labadmin/.ssh/sa6-alice
cat > /usr/local/bin/sa6-xpra-attach <<'SH'
#!/bin/sh
exec xpra attach ssh://alice@apps.sa6.test/100 \
    --ssh='ssh -i /home/labadmin/.ssh/sa6-alice -o StrictHostKeyChecking=accept-new' \
    --speaker=off --microphone=off --opengl=no
SH
chmod 755 /usr/local/bin/sa6-xpra-attach
install -d -m 755 -o labadmin -g labadmin /home/labadmin/Desktop
cat > /home/labadmin/Desktop/sa6-tryton.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=SA6 Tryton
Exec=/usr/local/bin/sa6-xpra-attach
Icon=applications-office
Terminal=false
CONF
chown labadmin:labadmin /home/labadmin/Desktop/sa6-tryton.desktop
chmod 755 /home/labadmin/Desktop/sa6-tryton.desktop
cat > /etc/systemd/system/sa6-xpra-client.service <<'UNIT'
[Unit]
Description=SA6 seamless client on WORKSTATION
After=lightdm.service

[Service]
User=labadmin
Environment=HOME=/home/labadmin
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/labadmin/.Xauthority
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
ExecStart=/usr/local/bin/sa6-xpra-attach
UNIT
systemctl daemon-reload
runuser -u labadmin -- ssh -i /home/labadmin/.ssh/sa6-alice \
    -o StrictHostKeyChecking=accept-new -o BatchMode=yes alice@apps.sa6.test id
