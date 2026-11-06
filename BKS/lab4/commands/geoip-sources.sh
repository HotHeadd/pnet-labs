#!/bin/bash
# WAN-TEST only: emulate country-labelled source prefixes on the isolated WAN.
# Requests go solely to the lab NGFW; this does not claim a real foreign location.
set -u
sudo ip address replace 5.255.255.5/32 dev lo
sudo ip address replace 8.8.8.8/32 dev lo
for src in 5.255.255.5 8.8.8.8; do
 echo "GeoIP test source=$src destination=192.168.100.2:8080"
 curl --noproxy '*' --interface "$src" -sS --max-time 8 -w '\nHTTP=%{http_code}\n' "http://192.168.100.2:8080/allowed.txt?geo=$src" 2>&1
done
