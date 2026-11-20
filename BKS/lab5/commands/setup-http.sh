#!/usr/bin/env bash
set -euo pipefail

# Run as root on HTTP-SERVER after configuring its BKS5 address.
www=/srv/bks5-http
install -d -m 0755 "$www" "$www/downloads" "$www/wp-admin" "$www/phpmyadmin" "$www/docs/wp-admin"
printf 'BKS5 ordinary page\n' > "$www/index.html"
printf 'BKS5 mock administrative path\n' > "$www/wp-admin/index.html"
printf 'BKS5 mock administrative path\n' > "$www/phpmyadmin/index.html"
printf 'BKS5 ordinary help page\n' > "$www/docs/wp-admin/index.html"
printf 'BKS5 inert download fixture\n' > "$www/downloads/remote-support-demo.exe"
printf 'BKS5 inert download fixture\n' > "$www/downloads/remote-admin-demo.exe"
printf 'BKS5 ordinary download\n' > "$www/downloads/readme.txt"

cat > /etc/systemd/system/bks5-http.service <<'EOF'
[Unit]
Description=BKS5 HTTP test fixtures
Wants=network-online.target
After=network-online.target

[Service]
User=www-data
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 10.1.50.10 --directory /srv/bks5-http
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now bks5-http.service
systemctl is-active bks5-http.service
