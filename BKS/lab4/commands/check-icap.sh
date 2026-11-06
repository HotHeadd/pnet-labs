#!/bin/bash
set -euo pipefail
mkdir -p /tmp/bks4-av-test
curl -fsS http://192.168.15.222/allowed.txt -o /tmp/bks4-av-test/allowed.txt
curl -fsS http://192.168.15.222/eicar.com -o /tmp/bks4-av-test/eicar.com
curl -fsS http://192.168.15.222/eicar.zip -o /tmp/bks4-av-test/eicar.zip
for name in allowed.txt eicar.com eicar.zip; do
  echo "=== ICAP RESPMOD: $name ==="
  rm -f /tmp/bks4-av-test/icap-response.html
  c-icap-client -i 10.1.99.10 -s avscan -f "/tmp/bks4-av-test/$name" -resp "http://dmz.bks4.test/$name" -v -o /tmp/bks4-av-test/icap-response.html 2>&1
 done
