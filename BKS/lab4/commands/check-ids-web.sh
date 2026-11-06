#!/bin/bash
# Bounded checks against the lab DMZ only. ROLE is lan or wan.
set -u
role=$1
if [[ "$role" == lan ]]; then src=10.1.10.42;target=10.1.50.10;port=80;ports=22,80,443,445
else src=192.168.100.1;target=192.168.100.2;port=8080;ports=22,443,8080,8443; fi
echo "IDS test $(date -Is) role=$role source=$src target=$target"
echo 'CONTROL: harmless HTTP'
curl --noproxy '*' --interface "$src" -sS --max-time 10 -o /dev/null -w 'HTTP=%{http_code}\n' "http://$target:$port/allowed.txt" 2>&1
echo 'TEST: SYN/version scan (bounded)'
sudo nmap -Pn -n -sS -sV --version-light -S "$src" -e ens3 -p "$ports" --max-retries 0 --host-timeout 35s "$target" 2>&1
echo 'TEST: Nmap HTTP user agent'
curl --noproxy '*' --interface "$src" -sS --max-time 10 -A 'Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org/book/nse.html)' -o /dev/null -w 'HTTP=%{http_code}\n' "http://$target:$port/allowed.txt" 2>&1
echo 'TEST: SQL injection string (nginx static server; no SQL execution)'
curl --noproxy '*' --interface "$src" -sS --max-time 10 -G --data-urlencode "id=-1 UNION SELECT user(),version(),database();--" -o /dev/null -w 'HTTP=%{http_code}\n' "http://$target:$port/index.php" 2>&1
echo 'TEST: directory traversal string'
curl --noproxy '*' --interface "$src" --path-as-is -sS --max-time 10 -o /dev/null -w 'HTTP=%{http_code}\n' "http://$target:$port/../../../../etc/passwd" 2>&1
echo 'TEST: XMAS flags, 12 packets'
sudo hping3 -q -I ens3 -a "$src" -F -P -U -p "$port" -c 12 -i u50000 "$target" 2>&1
echo 'TEST: SYN burst, 120 packets / 1.2 seconds'
sudo hping3 -q -I ens3 -a "$src" -S -p "$port" -c 120 -i u10000 "$target" 2>&1
echo "IDS test finished $(date -Is)"
