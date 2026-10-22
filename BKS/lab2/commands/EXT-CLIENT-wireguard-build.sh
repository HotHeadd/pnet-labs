#!/bin/sh
# EXT-CLIENT (Kali 2019.3, ядро 5.3 без модуля WireGuard): userspace wireguard-go + wg/wg-quick из исходников.
# Интернет на время сборки — через облако (eth1).
set -e
cd /opt
curl -sSLO https://go.dev/dl/go1.22.12.linux-amd64.tar.gz
tar xzf go1.22.12.linux-amd64.tar.gz
export PATH=$PATH:/opt/go/bin
git clone https://github.com/WireGuard/wireguard-go
cd wireguard-go && git checkout 0.0.20230223 && make && install -m 755 wireguard-go /usr/local/bin/
cd /opt && git clone https://github.com/WireGuard/wireguard-tools
make -C wireguard-tools/src
make -C wireguard-tools/src install WITH_WGQUICK=yes WITH_BASHCOMPLETION=no WITH_SYSTEMDUNITS=no
wg --version
echo BUILD-DONE
