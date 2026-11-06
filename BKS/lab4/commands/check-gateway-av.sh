#!/bin/bash
# LAN-CLIENT: test the complete LAN -> NGFW -> web-server path.
set -u
mkdir -p /tmp/bks4-gateway-av
for server in 10.1.50.10 192.168.100.1; do
 for file in allowed.txt eicar.com eicar.zip; do
  echo "HTTP source=10.1.10.42 server=$server file=$file"
  curl --noproxy '*' --interface 10.1.10.42 -sS --max-time 20 -o "/tmp/bks4-gateway-av/$server-$file" -w 'HTTP=%{http_code} bytes=%{size_download}\n' "http://$server/$file" 2>&1
 done
 echo "HTTPS without inspection source=10.1.10.42 server=$server file=eicar.com"
 curl --noproxy '*' --interface 10.1.10.42 -ksS --max-time 15 -o "/tmp/bks4-gateway-av/$server-https-eicar.com" -w 'HTTPS=%{http_code} bytes=%{size_download}\n' "https://$server/eicar.com" 2>&1
 if test -f "/tmp/bks4-gateway-av/$server-https-eicar.com"; then sha256sum "/tmp/bks4-gateway-av/$server-https-eicar.com"; fi
done
openssl s_client -bind 10.1.10.42:0 -connect 10.1.50.10:443 -servername bks4-test.local </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256
