#!/bin/bash
set -u
src=$1
date -Is
for site in wan chat files; do
 echo "SOURCE=$src URL=http://$site.bks4.test/allowed.txt"
 curl --noproxy '*' --interface "$src" --resolve "$site.bks4.test:80:192.168.100.1" -sS --max-time 10 -o /dev/null -w 'HTTP=%{http_code}\n' "http://$site.bks4.test/allowed.txt" 2>&1
done
