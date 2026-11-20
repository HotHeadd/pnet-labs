#!/usr/bin/env bash
set -euo pipefail

# Run as root on the corresponding BKS5 guest from its PNETLab console.
role=${1:?Usage: setup-network.sh client|sensor|server [first-interface] [second-interface]}
first=${2:-ens3}
second=${3:-ens4}
check_interface() {
  [[ $1 =~ ^[a-zA-Z0-9]+$ && -d /sys/class/net/$1 ]] || {
    printf 'Interface %s is unavailable\n' "$1" >&2
    exit 1
  }
}
check_interface "$first"

case "$role" in
  client) hostname=bks5-client; address=192.168.100.10/24; via=192.168.100.2; destination=10.1.50.0/24 ;;
  server) hostname=bks5-http; address=10.1.50.10/24; via=10.1.50.1; destination=192.168.100.0/24 ;;
  sensor) hostname=bks5-suricata; address=192.168.100.2/24; check_interface "$second"; [[ $first != "$second" ]] ;;
  *) printf 'Unknown BKS5 role: %s\n' "$role" >&2; exit 2 ;;
esac

install -d -m 0700 /root/bks5-netplan-backup
for config in /etc/netplan/*.yaml; do
  [[ -e $config && $config != /etc/netplan/90-bks5.yaml ]] || continue
  mv -n -- "$config" /root/bks5-netplan-backup/
done
printf 'network: {config: disabled}\n' > /etc/cloud/cloud.cfg.d/99-bks5-disable-network.cfg

umask 077
path=/etc/netplan/90-bks5.yaml
cat > "$path" <<EOF
network:
  version: 2
  ethernets:
    $first:
      addresses: [$address]
EOF
if [[ $role == sensor ]]; then
  cat >> "$path" <<EOF
    $second:
      addresses: [10.1.50.1/24]
EOF
  printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/90-bks5-forward.conf
  sysctl -p /etc/sysctl.d/90-bks5-forward.conf
else
  cat >> "$path" <<EOF
      routes:
        - to: $destination
          via: $via
EOF
fi

netplan generate
netplan apply
hostnamectl set-hostname "$hostname"
ip -br addr
ip route
