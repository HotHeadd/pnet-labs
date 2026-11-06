#!/usr/bin/env python3
"""Генерирует несекретные конфиги лабораторного стенда."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / "configs"
CMD = ROOT / "commands"

def write(path, body):
    path.write_text(body.strip() + "\n")

for name, local, peer, tunnel, lan, rid in [
    ("HQ-GW", "203.0.113.10", "203.0.113.20", "172.16.0.1", "10.1.50.0/26", "10.1.254.254"),
    ("BR-GW", "203.0.113.20", "203.0.113.10", "172.16.0.2", "10.2.20.0/24", "10.2.254.254"),
]:
    write(CFG / f"{name}-ipsec.conf", f"""
config setup
    uniqueids=yes
conn gre-site
    keyexchange=ikev2
    type=transport
    authby=psk
    left={local}
    right={peer}
    leftprotoport=47
    rightprotoport=47
    ike=aes256-sha256-modp2048!
    esp=aes256gcm16-modp2048!
    ikelifetime=3h
    lifetime=1h
    dpddelay=10s
    dpdaction=restart
    keyingtries=%forever
    auto=start
""")
    write(CFG / f"{name}-frr.conf", f"""
frr defaults traditional
hostname {name.lower()}
service integrated-vtysh-config
!
interface tun0
 ip ospf network point-to-point
 ip ospf hello-interval 2
 ip ospf dead-interval 8
!
router ospf
 ospf router-id {rid}
 passive-interface default
 no passive-interface tun0
 network 172.16.0.0/30 area 0.0.0.0
 network {lan} area 0.0.0.0
!
""")
    write(CFG / f"{name}-gre.service", f"""
[Unit]
Description=Persistent GRE tunnel for protected site-to-site traffic
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add tun0 mode gre local {local} remote {peer} ttl 64
ExecStart=/sbin/ip address add {tunnel}/30 dev tun0
ExecStart=/sbin/ip link set tun0 mtu 1400 up
ExecStart=/sbin/sysctl -w net.ipv4.conf.tun0.rp_filter=0
ExecStop=/sbin/ip tunnel del tun0
[Install]
WantedBy=multi-user.target
""")
    rules = f"""*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -i ens3 -p gre -m policy --dir in --pol none -j DROP
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i ens5 -s 192.168.15.128/32 -p tcp --dport 22 -j ACCEPT
-A INPUT -i ens5 -p icmp -j ACCEPT
-A INPUT -i ens3 -s {peer} -p udp -m multiport --dports 500,4500 -j ACCEPT
-A INPUT -i ens3 -s {peer} -p esp -j ACCEPT
-A INPUT -i ens3 -s {peer} -p gre -m policy --dir in --pol ipsec -j ACCEPT
-A INPUT -i tun0 -p ospf -j ACCEPT
-A INPUT -i tun0 -p icmp -j ACCEPT
-A INPUT -i ens4 -p icmp -j ACCEPT
-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A OUTPUT -o ens3 -p gre -m policy --dir out --pol ipsec -j ACCEPT
-A OUTPUT -o ens3 -p gre -j DROP
"""
    if name == "HQ-GW":
        rules += "-A INPUT -i ens3 -s 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT\n"
    else:
        rules += "-A FORWARD -i ens4 -o ens3 -s 10.2.20.42/32 -d 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT\n"
    rules += "COMMIT\n*mangle\n:FORWARD ACCEPT [0:0]\n-A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu\nCOMMIT\n"
    if name == "BR-GW":
        rules += "*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.2.20.42/32 -d 203.0.113.30/32 -o ens3 -p tcp --dport 443 -j SNAT --to-source 203.0.113.20\nCOMMIT\n"
    write(CFG / f"{name}-rules.v4", rules)
    write(CMD / f"{name}-configure.sh", f"""
#!/bin/bash
set -euo pipefail
cd /tmp/bks3/configs
install -m 644 {name}-ipsec.conf /etc/ipsec.conf
# /etc/ipsec.secrets is provisioned separately, mode 600.
install -m 644 {name}-gre.service /etc/systemd/system/bks3-gre.service
install -o frr -g frr -m 640 {name}-frr.conf /etc/frr/frr.conf
sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons
install -m 600 {name}-rules.v4 /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4
systemctl daemon-reload
systemctl enable --now bks3-gre strongswan-starter frr netfilter-persistent
systemctl restart strongswan-starter frr
""")

def outbound(address, uid, servername):
    return {"tag":"next","protocol":"vless","settings":{"vnext":[{"address":address,"port":443,"users":[{"id":uid,"encryption":"none"}]}]},
            "streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"serverName":servername,"minVersion":"1.3","certificates":[{"usage":"verify","certificateFile":"/etc/xray/ca.crt"}]}}}

def inbound(address, uid):
    return {"tag":"entry","listen":address,"port":443,"protocol":"vless","settings":{"clients":[{"id":uid}],"decryption":"none"},
            "streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"minVersion":"1.3","certificates":[{"certificateFile":"/etc/xray/server.crt","keyFile":"/etc/xray/server.key"}]}}}

# UUIDs authenticate an isolated educational service, not team/MCP accounts.
u1="8d64fe98-2401-4522-a7ab-8d6f636ac301"
u2="8d64fe98-2401-4522-a7ab-8d6f636ac302"
for name, ins, outs in [
    ("BR-CLIENT",[{"tag":"entry","listen":"127.0.0.1","port":1080,"protocol":"socks","settings":{"auth":"noauth","udp":False}}],[outbound("203.0.113.30",u1,"relay.bks3.test")]),
    ("XRAY-RELAY",[inbound("203.0.113.30",u1)],[outbound("203.0.113.10",u2,"hq.bks3.test")]),
    ("HQ-GW",[inbound("203.0.113.10",u2)],[{"tag":"next","protocol":"freedom","settings":{"finalRules":[{"action":"allow","network":"tcp","ip":["10.1.50.10/32"],"port":"8080"},{"action":"block","blockDelay":"0"}]}}]),
]:
    conf={"log":{"access":"/var/log/xray/access.log","error":"/var/log/xray/error.log","loglevel":"warning"},
          "inbounds":ins,"outbounds":outs+[{"tag":"blocked","protocol":"blackhole","settings":{}}],
          "routing":{"domainStrategy":"AsIs","rules":[{"type":"field","inboundTag":["entry"],"ip":["10.1.50.10/32"],"port":"8080","network":"tcp","outboundTag":"next"},{"type":"field","inboundTag":["entry"],"outboundTag":"blocked"}]}}
    write(CFG / f"{name}-xray.json",json.dumps(conf,indent=2))

write(CFG / "xray.service", """
[Unit]
Description=Xray restricted corporate proxy cascade
Wants=network-online.target
After=network-online.target
[Service]
User=xray
Group=xray
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/xray
PrivateTmp=true
[Install]
WantedBy=multi-user.target
""")
write(CMD / "xray-install.sh", """
#!/bin/bash
set -euo pipefail
name=$1
id xray >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin xray
install -m 755 /tmp/bks3/xray /usr/local/bin/xray
install -d -o root -g xray -m 750 /etc/xray
install -d -o xray -g xray -m 750 /var/log/xray
install -o root -g xray -m 640 /tmp/bks3/configs/$name-xray.json /etc/xray/config.json
install -m 644 /tmp/bks3/configs/xray.service /etc/systemd/system/xray.service
# CA and leaf certificates are provisioned separately, private keys mode 640 root:xray.
chown -R xray:xray /var/log/xray
runuser -u xray -- /usr/local/bin/xray run -test -config /etc/xray/config.json
systemctl daemon-reload
systemctl enable --now xray
systemctl restart xray
""")
