#!/bin/sh
# EXT-CLIENT (Kali): address "in the internet" behind ISP, WireGuard client config, admin SSH key.
nmcli con add type ethernet ifname eth0 con-name WAN ipv4.method manual ipv4.addresses 203.0.113.18/30 \
  ipv4.routes "203.0.113.8/29 203.0.113.17" ipv4.never-default yes ipv6.method ignore connection.autoconnect-priority 10
nmcli con up WAN
# client config generated on HQ-FW, fetched over the management network (eth1)
mkdir -p /etc/wireguard && chmod 700 /etc/wireguard
curl -s http://192.168.15.134:8000/ext-client.conf -o /etc/wireguard/wg0.conf && chmod 600 /etc/wireguard/wg0.conf
# admin key pair for SSH to HQ-FW (public key is published to HQ-FW over MGMT)
ssh-keygen -q -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C admin@ext-client
# tunnel at boot (after EXT-CLIENT-wireguard-build.sh): unit file EXT-CLIENT-wg0.service
systemctl daemon-reload && systemctl enable wg0.service
