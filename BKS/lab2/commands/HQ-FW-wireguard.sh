#!/bin/sh
# HQ-FW: сервер WireGuard (wg0 10.1.200.1/24, udp/51820). Ключи клиента EXT-CLIENT генерируются здесь же,
# клиентский конфиг передаётся на EXT-CLIENT по сети управления и удаляется с МЭ.
umask 077
cd /etc/wireguard
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee ext-client.key | wg pubkey > ext-client.pub
cat > wg0.conf <<EOF
[Interface]
Address = 10.1.200.1/24
ListenPort = 51820
PrivateKey = $(cat server.key)

[Peer]
# EXT-CLIENT
PublicKey = $(cat ext-client.pub)
AllowedIPs = 10.1.200.8/32
EOF
cat > /root/ext-client.conf <<EOF
[Interface]
Address = 10.1.200.8/24
PrivateKey = $(cat ext-client.key)

[Peer]
# HQ-FW
PublicKey = $(cat server.pub)
Endpoint = 203.0.113.10:51820
AllowedIPs = 10.1.200.0/24, 10.1.100.12/32
PersistentKeepalive = 25
EOF
rm -f ext-client.key
systemctl enable --now wg-quick@wg0
wg show
