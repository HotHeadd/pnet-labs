#!/bin/bash
# WAN-TEST: DNS/NTP services for the isolated data network.
set -euo pipefail
sudo tee /etc/dnsmasq.d/bks4.conf >/dev/null <<'EOF'
listen-address=192.168.100.1
bind-interfaces
no-resolv
server=192.168.15.2
address=/dmz.bks4.test/10.1.50.10
address=/wan.bks4.test/192.168.100.1
address=/auth.bks4.test/10.1.10.1
address=/chat.bks4.test/192.168.100.1
address=/files.bks4.test/192.168.100.1
EOF
sudo tee /etc/chrony/conf.d/bks4.conf >/dev/null <<'EOF'
allow 192.168.100.0/24
bindaddress 192.168.100.1
EOF
sudo systemctl restart dnsmasq chrony
sudo systemctl is-active dnsmasq chrony
sudo ss -lunp 'sport = :53 or sport = :123'
chronyc tracking
