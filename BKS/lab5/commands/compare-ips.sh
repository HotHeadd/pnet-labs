#!/usr/bin/env bash
set -euo pipefail

# Run as root on SURICATA. Send test HTTP requests from CLIENT when READY appears.
log=/var/log/bks5-ips
queue=5
client=192.168.100.10
server=10.1.50.10
rules=$(mktemp /run/bks5-drop.XXXXXX)
pid=
iptables_args=(-p tcp -j NFQUEUE --queue-num "$queue" --queue-bypass)

cleanup() {
  if [[ -n $pid ]]; then
    iptables -w -D FORWARD -s "$client" -d "$server" "${iptables_args[@]}" 2>/dev/null || true
    iptables -w -D FORWARD -s "$server" -d "$client" "${iptables_args[@]}" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    systemctl start bks5-suricata.service
  fi
  rm -f -- "$rules"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

install -d -m 0755 "$log"
sed '/sid:1000503;/s/^alert /drop /' /etc/suricata/bks5.rules > "$rules"
grep -q '^drop .*sid:1000503;' "$rules"
common=(-c /etc/suricata/bks5.yaml -S "$rules" -l "$log" --set stream.inline=yes)
suricata -T "${common[@]}"

systemctl stop bks5-suricata.service
suricata -q "$queue" "${common[@]}" > "$log/console.log" 2>&1 &
pid=$!
for attempt in {1..15}; do
  kill -0 "$pid"
  if grep -q 'engine started' "$log/console.log"; then break; fi
  sleep 1
done
grep -q 'engine started' "$log/console.log"

iptables -w -I FORWARD 1 -s "$client" -d "$server" "${iptables_args[@]}"
iptables -w -I FORWARD 1 -s "$server" -d "$client" "${iptables_args[@]}"
printf 'READY: send test requests from CLIENT in the next 30 seconds\n'
sleep 30
iptables -w -vnL FORWARD
