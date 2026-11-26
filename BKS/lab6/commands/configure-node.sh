#!/usr/bin/env bash
set -euo pipefail
role=${1:?specify client or server}
case "$role" in
    client) octet=10 ;;
    server) octet=20 ;;
    *) exit 2 ;;
esac
install -d -m 0755 /etc/cloud/cloud.cfg.d
printf 'network: {config: disabled}\n' > /etc/cloud/cloud.cfg.d/99-bks6-network.cfg
cat > /etc/netplan/99-bks6.yaml <<NETPLAN
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: false
      dhcp6: false
      addresses: [192.168.106.${octet}/24]
      optional: true
NETPLAN
chmod 600 /etc/netplan/99-bks6.yaml
hostnamectl set-hostname "bks6-$role"
netplan apply
printf '%s\n' /etc/netplan/*.yaml
ip -br -4 address show dev ens3
ip -4 route
