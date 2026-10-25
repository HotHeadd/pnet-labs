#!/bin/sh
# HQ-FW: политика межсетевого экрана (iptables + xtables-addons). Сохраняется в /etc/iptables/rules.v4.
WAN=ens3        # 203.0.113.10/29, транзит до HQ-EDGE
DMZ=ens4        # 10.1.100.0/28
MGMT=ens5       # облако управления (DHCP)
VPN=wg0         # 10.1.200.0/24
WIN=10.1.100.12
ADMIN=10.1.10.0/27
IPT=iptables

$IPT -F; $IPT -X; $IPT -t nat -F; $IPT -t nat -X; $IPT -t mangle -F
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# журнал отброшенного (с ограничением частоты)
$IPT -N LOG_DROP
$IPT -A LOG_DROP -m limit --limit 10/min -j LOG --log-prefix "FW-DROP: " --log-level 4
$IPT -A LOG_DROP -j DROP

# сканирование портов: журнал + TARPIT для TCP (окно 0, сканер «зависает»), остальное — DROP
$IPT -N PORTSCAN
$IPT -A PORTSCAN -m limit --limit 10/min -j LOG --log-prefix "FW-PORTSCAN: " --log-level 4
$IPT -A PORTSCAN -p tcp -j TARPIT
$IPT -A PORTSCAN -j DROP

# ---------- INPUT: трафик к самому МЭ ----------
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# защита от сканирования со стороны WAN (xtables-addons)
$IPT -A INPUT -i $WAN -m psd --psd-weight-threshold 21 --psd-delay-threshold 300 \
     --psd-lo-ports-weight 3 --psd-hi-ports-weight 1 -j PORTSCAN
$IPT -A INPUT -i $WAN -p tcp --syn -m recent --name maybe_scan --set
$IPT -A INPUT -i $WAN -p tcp --syn -m recent --name maybe_scan --update --seconds 60 --hitcount 20 -j PORTSCAN
$IPT -A INPUT -i $WAN -p tcp --dport 12345 -j DELUDE
# DELUDE (xtables-addons 3.19, ядро 5.15) шлёт SYN/ACK с TTL=0 — первый маршрутизатор его отбрасывает; исправляем TTL
$IPT -t mangle -A POSTROUTING -o $WAN -m ttl --ttl-eq 0 -j TTL --ttl-set 64
# WireGuard извне
$IPT -A INPUT -i $WAN -p udp --dport 51820 -j ACCEPT
# SSH: только из сети управления и ADMIN ГО, не более 2 сессий с адреса
$IPT -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 2 -j REJECT --reject-with tcp-reset
$IPT -A INPUT -i $MGMT -p tcp --dport 22 -j ACCEPT
$IPT -A INPUT -i $WAN -s $ADMIN -p tcp --dport 22 -j ACCEPT
# DHCP-клиент на интерфейсе управления
$IPT -A INPUT -i $MGMT -p udp --sport 67 --dport 68 -j ACCEPT
# ICMP echo: из DMZ, VPN, управления и ADMIN — без ограничений, из WAN — с ограничением частоты
$IPT -A INPUT -p icmp --icmp-type echo-request -i $DMZ -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request -i $VPN -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request -i $MGMT -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request -i $WAN -m limit --limit 5/s -j ACCEPT
$IPT -A INPUT -j LOG_DROP

# ---------- FORWARD: транзит ----------
$IPT -A FORWARD -m conntrack --ctstate INVALID -j DROP
$IPT -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# DMZ не ходит во внутренние сети ГО (только в интернет)
$IPT -A FORWARD -i $DMZ -d 10.0.0.0/8 -j LOG_DROP
$IPT -A FORWARD -i $DMZ -o $WAN -j ACCEPT
# опубликованный веб-сервер (после DNAT)
$IPT -A FORWARD -i $WAN -o $DMZ -d $WIN -p tcp --dport 80 -m conntrack --ctstate DNAT -j ACCEPT
# VPN-клиенты: только RDP и ping к Windows Server
$IPT -A FORWARD -i $VPN -o $DMZ -d $WIN -p tcp --dport 3389 -j ACCEPT
$IPT -A FORWARD -i $VPN -o $DMZ -d $WIN -p icmp --icmp-type echo-request -j ACCEPT
# ADMIN ГО: ping и веб к DMZ
$IPT -A FORWARD -i $WAN -o $DMZ -s $ADMIN -p icmp --icmp-type echo-request -j ACCEPT
$IPT -A FORWARD -i $WAN -o $DMZ -s $ADMIN -p tcp --dport 80 -j ACCEPT
$IPT -A FORWARD -j LOG_DROP

# ---------- NAT ----------
# DNAT: публикация веб-сервера IIS (WIN-SRV:80) на публичном адресе МЭ, порт 8080
$IPT -t nat -A PREROUTING -i $WAN -d 203.0.113.10 -p tcp --dport 8080 -j DNAT --to-destination $WIN:80
# DNAT: DNS-запросы из DMZ принудительно на корпоративный резолвер 8.8.8.8
$IPT -t nat -A PREROUTING -i $DMZ -p udp --dport 53 -j DNAT --to-destination 8.8.8.8:53
# SNAT: исходящий трафик Windows Server — со своего статического публичного адреса 203.0.113.11
$IPT -t nat -A POSTROUTING -s $WIN -o $WAN -j SNAT --to-source 203.0.113.11
# MASQUERADE: выход остальной DMZ в интернет через адрес интерфейса МЭ
$IPT -t nat -A POSTROUTING -s 10.1.100.0/28 -o $WAN -j MASQUERADE

# ---------- IPv6: по умолчанию закрыт ----------
ip6tables -F
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

netfilter-persistent save
