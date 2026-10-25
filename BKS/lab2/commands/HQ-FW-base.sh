#!/bin/sh
# HQ-FW: базовая настройка ОС
timedatectl set-timezone Europe/Moscow
cat > /etc/sysctl.d/90-hq-fw.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.forwarding = 0
EOF
sysctl --system > /dev/null
# netplan: итоговый 01-hq-fw.yaml (WAN/DMZ/MGMT), cloud-init отключён (/etc/cloud/cloud-init.disabled)
netplan apply
