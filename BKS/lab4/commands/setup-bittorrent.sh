#!/bin/bash
# WAN-TEST: real Transmission seeders with static local tracker fixtures.
# DHT/PEX/LPD/uTP/UPnP disabled; peers and control traffic stay inside the stand.
set -euo pipefail
sudo systemctl unmask --runtime transmission-daemon.service
sudo systemctl disable --now transmission-daemon.service
sudo install -d -o debian-transmission -g debian-transmission /var/lib/bks4-torrent/data
sudo python3 - <<'PY'
from pathlib import Path
import json,socket,struct
base=Path('/var/lib/bks4-torrent')
(base/'data/harmless.txt').write_bytes(b'BKS4 isolated file transfer. No executable content.\n'*65536)
for peer,rpc in [(6881,9091),(16881,19091)]:
 p=base/str(peer);(p/'watch').mkdir(parents=True,exist_ok=True)
 config={'bind-address-ipv4':'192.168.100.1','bind-address-ipv6':'::1','dht-enabled':False,'lpd-enabled':False,'pex-enabled':False,'utp-enabled':False,'port-forwarding-enabled':False,'rpc-bind-address':'127.0.0.1','rpc-port':rpc,'rpc-whitelist-enabled':True,'rpc-whitelist':'127.0.0.1','rpc-authentication-required':False,'download-dir':str(base/'data'),'incomplete-dir-enabled':False,'peer-port':peer,'peer-port-random-on-start':False,'watch-dir':str(p/'watch'),'watch-dir-enabled':True,'trash-original-torrent-files':False,'speed-limit-up':512,'speed-limit-up-enabled':True,'ratio-limit-enabled':False,'message-level':1,'scrape-paused-torrents-enabled':False,'start-added-torrents':True,'encryption':0}
 (p/'settings.json').write_text(json.dumps(config,indent=2))
 Path('/var/www/html/bks4-tracker-'+str(peer)).write_bytes(b'd8:intervali3600e5:peers6:'+socket.inet_aton('192.168.100.1')+struct.pack('!H',peer)+b'e')
PY
for port in 6881 16881; do
 sudo transmission-create -p -t "http://192.168.100.1/bks4-tracker-$port" -o "/var/lib/bks4-torrent/harmless-$port.torrent" /var/lib/bks4-torrent/data/harmless.txt
 sudo cp "/var/lib/bks4-torrent/harmless-$port.torrent" "/var/lib/bks4-torrent/$port/watch/harmless.torrent"
done
sudo chown -R debian-transmission:debian-transmission /var/lib/bks4-torrent
sudo tee /etc/systemd/system/bks4-bt-seed@.service >/dev/null <<'EOF'
[Unit]
Description=BKS4 isolated BitTorrent seeder on %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=debian-transmission
Group=debian-transmission
ExecStart=/usr/bin/transmission-daemon -f -g /var/lib/bks4-torrent/%i -O -Y --no-utp -M -i 192.168.100.1 -I ::1 -r 127.0.0.1
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now bks4-bt-seed@6881 bks4-bt-seed@16881
sudo systemctl is-active bks4-bt-seed@6881 bks4-bt-seed@16881
sudo chmod 644 /var/lib/bks4-torrent/harmless-*.torrent
transmission-show /var/lib/bks4-torrent/harmless-6881.torrent
sudo ss -ltnp 'sport = :6881 or sport = :16881 or sport = :9091 or sport = :19091'
