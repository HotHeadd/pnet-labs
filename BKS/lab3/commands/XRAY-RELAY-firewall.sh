#!/bin/bash
set -euo pipefail
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i ens4 -s 192.168.15.128 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i ens4 -p icmp -j ACCEPT
iptables -A INPUT -i ens3 -s 203.0.113.20 -p tcp --dport 443 -j ACCEPT
# Persist without adding another package installation to the minimal relay.
iptables-save > /etc/bks3-firewall.v4
cat > /etc/systemd/system/bks3-firewall.service <<'EOF'
[Unit]
Description=Restore restricted relay firewall
Before=xray.service
After=network-pre.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c '/sbin/iptables-restore < /etc/bks3-firewall.v4'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable bks3-firewall
