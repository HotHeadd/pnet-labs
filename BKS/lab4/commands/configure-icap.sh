#!/bin/bash
# ADMIN-LINUX: signed official ClamAV databases must already be installed.
set -euo pipefail
sudo cp -n /etc/c-icap/c-icap.conf /etc/c-icap/c-icap.conf.bks4-original
sudo python3 - <<'PY'
from pathlib import Path
p=Path('/etc/c-icap/c-icap.conf');s=Path(str(p)+'.bks4-original').read_text()
s=s.replace('Port 1344','Port 10.1.99.10:1344').replace('Service echo srv_echo.so','# Echo disabled: BKS4 antivirus service only')
s+='\n# BKS4: scan the entire object before returning it\nInclude virus_scan.conf\nInclude clamd_mod.conf\nvirus_scan.DefaultEngine clamd\nvirus_scan.SendPercentData 0\nvirus_scan.MaxObjectSize 25M\n'
p.write_text(s)
p=Path('/etc/default/c-icap');s=p.read_text().replace('START=no','START=yes');p.write_text(s)
PY
sudo sed -i 's/^EnableVersionCommand false/EnableVersionCommand true/' /etc/clamav/clamd.conf
sudo systemctl enable clamav-daemon c-icap
sudo systemctl restart clamav-daemon c-icap
sudo systemctl is-active clamav-daemon c-icap
sudo ss -ltnp 'sport = :1344'
c-icap-client -i 10.1.99.10 -s avscan -v
mkdir -p /tmp/bks4-av-test
curl -fsS http://192.168.15.222/allowed.txt -o /tmp/bks4-av-test/allowed.txt
curl -fsS http://192.168.15.222/eicar.com -o /tmp/bks4-av-test/eicar.com
curl -fsS http://192.168.15.222/eicar.zip -o /tmp/bks4-av-test/eicar.zip
for name in allowed.txt eicar.com eicar.zip; do
  echo "=== ICAP RESPMOD: $name ==="
  rm -f /tmp/bks4-av-test/icap-response.html
  c-icap-client -i 10.1.99.10 -s avscan -f "/tmp/bks4-av-test/$name" -resp "http://dmz.bks4.test/$name" -v -o /tmp/bks4-av-test/icap-response.html 2>&1
 done
