#!/bin/bash
# WAN-TEST: two ports of the same IRC application, bound to the lab WAN only.
set -euo pipefail
sudo cp -n /etc/inspircd/inspircd.conf /etc/inspircd/inspircd.conf.bks4-original
sudo python3 - <<'PY'
from pathlib import Path
import re
p=Path('/etc/inspircd/inspircd.conf');s=Path(str(p)+'.bks4-original').read_text()
s=s.replace('name="irc.local"','name="irc.bks4.test"').replace('description="Local IRC Server"','description="BKS4 isolated IRC server"').replace('network="Localnet"','network="BKS4"')
s=s.replace('<bind address="127.0.0.1" port="6667" type="clients">','<bind address="192.168.100.1" port="6667" type="clients">\n<bind address="192.168.100.1" port="16667" type="clients">')
s=s.replace('<connect allow="*"','<connect allow="192.168.100.0/24"').replace('localmax="3"','localmax="20"').replace('globalmax="3"','globalmax="20"')
s=re.sub(r'<power\b[^>]*>\s*','',s);s=re.sub(r'<oper\b[^>]*>\s*','',s)
s=s.replace('<dns server="127.0.0.1"','<dns server="192.168.100.1"')
p.write_text(s)
PY
sudo systemctl unmask --runtime inspircd.service
sudo systemctl enable --now inspircd.service
sudo systemctl is-active inspircd
sudo ss -ltnp 'sport = :6667 or sport = :16667'
