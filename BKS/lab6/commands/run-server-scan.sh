#!/usr/bin/env bash
set -euo pipefail
phase=${1:?specify initial, reject, drop, udp-reject, udp-drop, udp-cleanup or cleanup}
dir="$HOME/bks6"
cd "$dir"
clear_filter() {
    if sudo -n iptables -C INPUT -s 192.168.106.10 -p udp --dport 5300 -j BKS6SCAN 2>/dev/null; then
        sudo -n iptables -D INPUT -s 192.168.106.10 -p udp --dport 5300 -j BKS6SCAN
    fi
    if sudo -n iptables -C INPUT -s 192.168.106.10 -p tcp --dport 8080 -j BKS6SCAN 2>/dev/null; then
        sudo -n iptables -D INPUT -s 192.168.106.10 -p tcp --dport 8080 -j BKS6SCAN
    fi
    if sudo -n iptables -S BKS6SCAN >/dev/null 2>&1; then
        sudo -n iptables -F BKS6SCAN
        sudo -n iptables -X BKS6SCAN
    fi
}
case "$phase" in
    initial)
        mkdir -p http
        printf 'BKS6 test service\n' > http/index.html
        nohup python3 -m http.server 8080 --bind 192.168.106.20 --directory http >http.log 2>&1 </dev/null &
        echo $! > http.pid
        sudo -n dnsmasq --no-resolv --no-hosts --bind-interfaces --listen-address=192.168.106.20 \
            --address=/lab.test/192.168.106.20 --pid-file="$dir/dns.pid"
        ;;
    reject|drop)
        clear_filter
        sudo -n iptables -N BKS6SCAN
        if [ "$phase" = reject ]; then
            sudo -n iptables -A BKS6SCAN -p tcp -j REJECT --reject-with tcp-reset
        else
            sudo -n iptables -A BKS6SCAN -j DROP
        fi
        sudo -n iptables -I INPUT 1 -s 192.168.106.10 -p tcp --dport 8080 -j BKS6SCAN
        ;;
    udp-reject|udp-drop)
        clear_filter
        sudo -n iptables -N BKS6SCAN
        if [ "$phase" = udp-reject ]; then
            sudo -n iptables -A BKS6SCAN -j REJECT --reject-with icmp-admin-prohibited
        else
            sudo -n iptables -A BKS6SCAN -j DROP
        fi
        sudo -n iptables -I INPUT 1 -s 192.168.106.10 -p udp --dport 5300 -j BKS6SCAN
        ;;
    udp-cleanup)
        clear_filter
        ;;
    cleanup)
        clear_filter
        kill "$(cat http.pid)"
        sudo -n kill "$(cat dns.pid)"
        ;;
    *) exit 2 ;;
esac
sleep .2
ss -lntu | awk 'NR == 1 || $5 ~ /:(21|22|53|8080|8081|5300)$/'
sudo -n iptables -S INPUT
if sudo -n iptables -S BKS6SCAN >/dev/null 2>&1; then
    sudo -n iptables -S BKS6SCAN
fi
