#!/bin/bash
# На APPS от root. Публикуется только окно Tryton, доступ через SSH.
set -euo pipefail
systemctl is-active --quiet tryton-server
getent passwd alice >/dev/null
install -d -m 750 -o alice -g employees /home/alice
install -d -m 700 -o alice -g employees /home/alice/.xpra /home/alice/.config/tryton/6.0
printf 'start = /bin/true\n' > /home/alice/.xpra/xpra.conf
chown alice:employees /home/alice/.xpra/xpra.conf
chmod 600 /home/alice/.xpra/xpra.conf
cat > /home/alice/.config/tryton/6.0/tryton.conf <<'CONF'
[login]
profile = SA6
host = apps.sa6.test:8000
db = sa6
login = alice
expanded = True
CONF
cat > /home/alice/.config/tryton/6.0/profiles.cfg <<'CONF'
[SA6]
host = apps.sa6.test:8000
database = sa6
username = alice
CONF
chown alice:employees /home/alice/.config/tryton/6.0/tryton.conf /home/alice/.config/tryton/6.0/profiles.cfg
chmod 600 /home/alice/.config/tryton/6.0/tryton.conf /home/alice/.config/tryton/6.0/profiles.cfg
cat > /usr/local/bin/sa6-tryton-client <<'SH'
#!/bin/sh
exec /usr/bin/tryton -c /home/alice/.config/tryton/6.0/tryton.conf
SH
chmod 755 /usr/local/bin/sa6-tryton-client
cat > /etc/systemd/system/sa6-xpra.service <<'UNIT'
[Unit]
Description=SA6 Tryton seamless session for Alice
After=network-online.target sssd.service tryton-server.service
Wants=network-online.target
Requires=tryton-server.service

[Service]
User=alice
Group=employees
Environment=HOME=/home/alice
Environment=XDG_RUNTIME_DIR=/run/sa6-xpra
RuntimeDirectory=sa6-xpra
RuntimeDirectoryMode=0700
ExecStart=/usr/bin/xpra start :100 --daemon=no --systemd-run=no --start-via-proxy=no --socket-dir=/home/alice/.xpra --start-child=/usr/local/bin/sa6-tryton-client --exit-with-client=no --exit-with-children=no --pulseaudio=no --webcam=no --printing=no
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now sa6-xpra
systemctl restart sa6-xpra
systemctl is-active sa6-xpra
runuser -u alice -- env HOME=/home/alice xpra list --socket-dir=/home/alice/.xpra
