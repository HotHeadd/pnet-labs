# Команды выполнены на CLIENT. Собственный тестовый HTTP-запрос.
sudo timeout 8 tcpdump -i ens3 -s0 -w /tmp/bks7-own.pcap 'host 192.168.77.20 and tcp port 80' >/tmp/bks7-capture.log 2>&1 &
sleep 1
curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Lab: BKS7-MARKER' http://192.168.77.20/
# После завершения записи
sudo tcpdump -Anr /tmp/bks7-own.pcap 2>/dev/null | grep -E 'GET /|X-Lab:|HTTP/1.1 200'
