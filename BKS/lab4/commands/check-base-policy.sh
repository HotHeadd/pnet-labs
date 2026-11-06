#!/bin/bash
# Run on each Linux guest with its role. Bind the data address explicitly.
set -u
case "$1" in
 lan)
  src=10.1.10.42
  echo 'LAN -> DMZ HTTP';curl --noproxy '*' --interface "$src" -sS --max-time 8 -w '\nHTTP=%{http_code}\n' http://10.1.50.10/allowed.txt
  echo 'LAN -> DMZ SSH (expect denied)';timeout 5 nc -s "$src" -vz 10.1.50.10 22 2>&1;echo "rc=$?"
  echo 'LAN -> WAN HTTP';curl --noproxy '*' --interface "$src" -sS --max-time 8 -w '\nHTTP=%{http_code}\n' http://192.168.100.1/allowed.txt
  ;;
 wan)
  echo 'WAN -> published HTTPS';curl --noproxy '*' --interface 192.168.100.1 -ksS --max-time 8 -w '\nHTTPS=%{http_code}\n' https://192.168.100.2:8443/allowed.txt
  echo 'WAN -> published HTTP';curl --noproxy '*' --interface 192.168.100.1 -sS --max-time 8 -w '\nHTTP=%{http_code}\n' http://192.168.100.2:8080/allowed.txt
  ;;
 admin)
  echo 'Management -> DMZ HTTP';curl --noproxy '*' --interface 10.1.99.10 -sS --max-time 8 -w '\nHTTP=%{http_code}\n' http://10.1.50.10/allowed.txt
  echo 'Management -> DMZ SSH';timeout 5 nc -s 10.1.99.10 -vz 10.1.50.10 22 2>&1;echo "rc=$?"
  ;;
 dmz)
  echo 'DMZ -> LAN SSH (expect denied)';timeout 5 nc -s 10.1.50.10 -vz 10.1.10.42 22 2>&1;echo "rc=$?"
  ;;
esac
