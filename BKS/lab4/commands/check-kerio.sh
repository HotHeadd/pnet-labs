#!/bin/bash
# Run inside the named Linux guest; all destinations belong to the lab.
set -u
role=$1
date -Is
bash "$(dirname "$0")/check-base-policy.sh" "$role"
case "$role" in
 lan)
  echo 'LAN -> DMZ HTTPS'
  curl --noproxy '*' --interface 10.1.10.42 -ksS --max-time 6 -o /dev/null -w 'HTTPS=%{http_code}\n' https://10.1.50.10/allowed.txt
  for f in eicar.com eicar.zip; do
   echo "LAN HTTP $f"
   curl --noproxy '*' --interface 10.1.10.42 -sS --max-time 6 -o /dev/null -w 'HTTP=%{http_code} bytes=%{size_download}\n' "http://10.1.50.10/$f"
  done
  echo 'LAN -> Kerio administration (expect denied)'
  curl --noproxy '*' --interface 10.1.10.42 -ksS --max-time 5 -o /dev/null -w 'HTTPS=%{http_code}\n' https://10.1.10.1:4081/admin/login/ 2>&1
  ;;
 wan)
  echo 'WAN -> Kerio administration (expect denied)'
  curl --noproxy '*' --interface 192.168.100.1 -ksS --max-time 5 -o /dev/null -w 'HTTPS=%{http_code}\n' https://192.168.100.2:4081/admin/login/ 2>&1
  echo 'WAN ports (bounded scan)'
  nmap -Pn -n -sT --max-retries 0 --host-timeout 10s -p 22,443,8080,8443 192.168.100.2
  echo 'Nmap User-Agent control: result must be correlated with native IPS events'
  curl --noproxy '*' --interface 192.168.100.1 -sS --max-time 6 -A 'Nmap Scripting Engine' -o /dev/null -w 'HTTP=%{http_code}\n' http://192.168.100.2:8080/allowed.txt
  ;;
 admin)
  echo 'Management -> Kerio administration (expect allowed)'
  curl --noproxy '*' --interface 10.1.99.10 -ksS --max-time 5 -o /dev/null -w 'HTTPS=%{http_code}\n' https://10.1.99.1:4081/admin/login/
  ;;
esac
