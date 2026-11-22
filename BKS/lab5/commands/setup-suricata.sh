#!/usr/bin/env bash
set -euo pipefail

# Run as root on SURICATA after the Ubuntu suricata package is installed.
rules=${1:?Usage: setup-suricata.sh local.rules}
install -d -m 0755 /etc/suricata /var/log/bks5-suricata
install -m 0644 "$rules" /etc/suricata/bks5.rules
sed -E 's|^([[:space:]]+HOME_NET:).*|\1 "[10.1.50.0/24]"|' \
  /etc/suricata/suricata.yaml > /etc/suricata/bks5.yaml
suricata -T -c /etc/suricata/bks5.yaml -S /etc/suricata/bks5.rules -l /var/log/bks5-suricata

systemctl disable --now suricata.service
cat > /etc/systemd/system/bks5-suricata.service <<'EOF'
[Unit]
Description=BKS5 Suricata IDS
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/suricata --af-packet=ens3 -k none -c /etc/suricata/bks5.yaml -S /etc/suricata/bks5.rules -l /var/log/bks5-suricata
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now bks5-suricata.service
systemctl is-active bks5-suricata.service
