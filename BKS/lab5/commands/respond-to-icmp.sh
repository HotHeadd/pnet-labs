#!/usr/bin/env bash
set -euo pipefail

# Run as root on SURICATA for the temporary response demonstration.
rule=(-s 192.168.100.10 -d 10.1.50.10 -p icmp --icmp-type echo-request
      -m comment --comment bks5-response -j DROP)
iptables -w -I FORWARD 1 "${rule[@]}"
trap 'iptables -w -D FORWARD "${rule[@]}"' EXIT
trap 'exit 130' INT TERM
echo RESPONSE_READY
sleep 20
iptables -w -nvL FORWARD
