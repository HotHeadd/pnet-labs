#!/bin/bash
set -euo pipefail
cd /tmp/bks3/configs
install -m 644 BR-GW-ipsec.conf /etc/ipsec.conf
# /etc/ipsec.secrets is provisioned separately, mode 600.
install -m 644 BR-GW-gre.service /etc/systemd/system/bks3-gre.service
install -o frr -g frr -m 640 BR-GW-frr.conf /etc/frr/frr.conf
sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons
install -m 600 BR-GW-rules.v4 /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4
systemctl daemon-reload
systemctl enable --now bks3-gre strongswan-starter frr netfilter-persistent
systemctl restart strongswan-starter frr
