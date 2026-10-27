# БКС3 — проверка на защите

Открыть `/BKS labs/BKS3.unl`, **Join к рабочей сессии 8 (`vlad_pc`)**.
Номер сессии проверять перед работой: `tools/pnet-helper.py sessions`.
Служебные IP — `stand/README.md`; SSH с PNETLab-хоста под `labadmin`, sudo без пароля.

1. **Динамическая маршрутизация, BR-GW и HQ-GW:**
   ```sh
   sudo vtysh -c 'show ip ospf neighbor'
   ip route show proto ospf
   sudo ipsec statusall
   ```
   Сосед Full; на BR-GW сеть `10.1.50.0/26` через `172.16.0.1 dev tun0 proto ospf`,
   на HQ-GW сеть `10.2.20.0/24` через `.2`. SA ESTABLISHED / INSTALLED TRANSPORT.

2. **LAN → LAN, BR-CLIENT:**
   ```sh
   ip route get 10.1.50.10
   ping -I 10.2.20.42 -c 4 10.1.50.10
   curl --interface 10.2.20.42 http://10.1.50.10:8080
   traceroute -n -I -m 6 -w 1 10.1.50.10
   ping -M do -s 1372 -c 3 10.1.50.10
   ```
   Ответ `BKS3: protected HQ service`, путь через BR-GW и HQ-GW. Служебная сеть в пути отсутствует.

3. **Шифрование, PNETLab-хост:**
   Найти WAN-мост текущей сессии через `brctl show` (для сессии 8 — `vnet8_1`).
   ```sh
   sudo tcpdump -nn -i vnet8_1 'ip proto 50 or ip proto 47'
   ```
   Повторить ping с клиента: на мосту ESP, открытого GRE нет. Остановить tcpdump Ctrl+C.

4. **Каскад Xray, BR-CLIENT:**
   ```sh
   curl --max-time 8 --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:8080
   curl --max-time 4 --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:22
   ```
   Первый запрос успешен, второй отклонён. На XRAY-RELAY и HQ-GW:
   `sudo tail /var/log/xray/access.log` — `10.1.50.10:8080 [entry -> next]`.
   На клиенте SOCKS только `127.0.0.1:1080`, серверные порты на WAN — TLS/443.

5. **Отказ и восстановление (согласовать с работающими в той же сессии):**
   BR-GW: `sudo systemctl stop strongswan-starter`; ping клиента не проходит,
   через 8–10 с OSPF-маршрут удаляется, открытый GRE на WAN отсутствует.
   **Вернуть:** `sudo systemctl start strongswan-starter`, дождаться Full и повторить ping.
   XRAY-RELAY: `sudo systemctl stop xray`; SOCKS-запрос не проходит.
   **Вернуть:** `sudo systemctl start xray`; запрос снова успешен.

Лабу и чужие сессии не останавливать. После демонстрации все пять узлов и службы должны работать.
