#!/bin/bash
set -euo pipefail
role=$1
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
case "$role" in
wan-test|dmz-web) apt-get install -y -qq nginx openssl curl iperf3 python3;;
lan-client) apt-get install -y -qq curl nmap hping3 iperf3 openssl traceroute;;
admin-linux) apt-get install -y -qq rsyslog tcpdump curl snmptrapd;;
esac
if [[ "$role" == lan-client ]]; then
 # Raw-packet tools also need explicit routes in the main routing table.
 cat > /etc/netplan/60-bks4-data-routes.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ens3:
      routes:
      - to: 10.1.50.0/26
        via: 10.1.10.1
      - to: 192.168.100.0/24
        via: 10.1.10.1
EOF
 chmod 600 /etc/netplan/60-bks4-data-routes.yaml
 netplan apply
fi
if [[ "$role" == wan-test ]]; then
 echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/90-bks4-forward.conf
 sysctl -p /etc/sysctl.d/90-bks4-forward.conf
 cat > /usr/local/sbin/bks4-nat <<'EOF'
#!/bin/sh
iptables -t nat -C POSTROUTING -s 192.168.100.0/24 -o ens4 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o ens4 -j MASQUERADE
EOF
 chmod 755 /usr/local/sbin/bks4-nat
 cat > /etc/systemd/system/bks4-nat.service <<'EOF'
[Unit]
Description=Internet uplink for isolated BKS4 WAN
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/bks4-nat
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
 systemctl daemon-reload
 systemctl enable --now bks4-nat
fi
if [[ "$role" == wan-test || "$role" == dmz-web ]]; then
 printf 'BKS4 %s web service\n' "$role" > /var/www/html/index.html
 systemctl enable --now nginx
fi
if [[ "$role" == admin-linux ]]; then
 cat > /etc/rsyslog.d/20-bks4-listener.conf <<'EOF'
module(load="imudp")
input(type="imudp" address="10.1.99.10" port="514")
module(load="imtcp")
input(type="imtcp" address="10.1.99.10" port="514")
template(name="BKS4Remote" type="string" string="/var/log/bks4/%fromhost-ip%/events.log")
template(name="BKS4Raw" type="string" string="%rawmsg%\n")
if ($fromhost-ip != '127.0.0.1' and $fromhost-ip != '::1') then {
 action(type="omfile" dynaFile="BKS4Remote" template="BKS4Raw" createDirs="on")
 stop
}
EOF
 mkdir -p /var/log/bks4
 chown syslog:adm /var/log/bks4
 systemctl restart rsyslog
fi
hostname
systemctl --failed --no-pager
ip rule show
