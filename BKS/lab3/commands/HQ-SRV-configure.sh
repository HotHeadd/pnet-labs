#!/bin/bash
set -euo pipefail
install -d -m 755 /srv/bks3
printf 'BKS3: protected HQ service\n' > /srv/bks3/index.html
cat > /etc/systemd/system/bks3-web.service <<'EOF'
[Unit]
Description=Internal HQ web service
After=network-online.target
Wants=network-online.target
[Service]
DynamicUser=yes
User=bks3-web
WorkingDirectory=/srv/bks3
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 10.1.50.10
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now bks3-web
