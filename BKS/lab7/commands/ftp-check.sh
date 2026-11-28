# На CLIENT, после подготовки временной записи на сервере.
sudo timeout 8 tcpdump -i ens3 -s0 \
  -w /tmp/bks7-ftp-ok.pcap \
  'host 192.168.77.20 and tcp port 21' \
  >/tmp/bks7-ftp-ok.log 2>&1 &
sleep 1
curl -v --max-time 5 \
  --user bks7audit:Lab7-Demo-2711 \
  ftp://192.168.77.20/ 2>&1 \
  | grep -E 'USER |PASS |230 |226 '
# После завершения записи
sudo tcpdump -Anr /tmp/bks7-ftp-ok.pcap 2>/dev/null \
  | grep -E 'USER bks7|PASS Lab7|230 Login'
