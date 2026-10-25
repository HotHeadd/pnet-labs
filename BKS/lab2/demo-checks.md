# Сценарий проверок на сдаче (стенд BKS2, вариант 6)

Рабочая сессия — №4 (`vlad_pc`), остальные присоединяются к ней (Join). С 2026-10-23 HQ-FW, WIN-SRV и EXT-CLIENT
опубликованы в образы `*-bks2-*-v1`, так что и новая сессия BKS2 открывается настроенной. Логины — `stand/README.md`.

Перед началом:
- `ping 203.0.113.10` с HQ-EDGE и `wg show` на HQ-FW (должен быть `latest handshake`). Если HQ-EDGE не пингует МЭ — линки
  qemu ↔ IOL отвалились после перезапуска Linux/Windows-узлов: перезапустить ISP, HQ-EDGE, HQ-DMZ (Stop → Start);
- не ошибаться паролем SSH больше двух раз: fail2ban на третьей ошибке за 10 минут банит адрес Kali на час;
- PC-HQ-ADMIN: `ip 10.1.10.10/27 10.1.10.1`;
- EXT-CLIENT (Kali, VNC, root/toor): `wg-quick up wg0`;
- HQ-FW (telnet, root): `wg show` — должен быть peer, после пинга с Kali — `latest handshake`.

## 1. Windows выходит в интернет через МЭ (NAT)

```
WIN-SRV> tracert -d -h 4 8.8.8.8      # 10.1.100.1 → 203.0.113.9 → 8.8.8.8
HQ-FW#   iptables -t nat -L POSTROUTING -n -v   # растёт счётчик SNAT to:203.0.113.11
```

## 2. DMZ изолирована от сети ГО, ГО в DMZ ходит

```
WIN-SRV>  ping -n 2 10.1.10.10                  # Request timed out
HQ-FW#    journalctl -k | grep FW-DROP | tail -2 # IN=ens4 ... DST=10.1.10.10
PC-HQ-ADMIN> ping 10.1.100.12                    # ответы есть
```

## 3. VPN и RDP с NLA через туннель

```
EXT-CLIENT# ping -c2 10.1.100.12                 # через wg0
EXT-CLIENT# xfreerdp /v:10.1.100.12 /u:rdpuser /p:'Lab2-Vpn-Win#7' /cert-ignore /sec:nla   # открывается рабочий стол
WIN-SRV>    quser; netstat -n | findstr :3389    # сеанс rdpuser с 10.1.200.8
```

## 4. Без NLA и без туннеля — нельзя

```
EXT-CLIENT# xfreerdp /v:10.1.100.12 /u:rdpuser /p:x /cert-ignore /sec:rdp   # Protocol Security Negotiation Failure
EXT-CLIENT# nmap -Pn -p 3389 --script rdp-enum-encryption 10.1.100.12        # только CredSSP (NLA), RDSTLS
EXT-CLIENT# wg-quick down wg0
EXT-CLIENT# timeout 15 xfreerdp /v:203.0.113.10 /u:rdpuser /p:x /cert-ignore   # не подключается: RDP не опубликован
EXT-CLIENT# curl -s http://203.0.113.10:8080/    # а веб-сервер опубликован (DNAT): <h1>WIN-SRV ...
EXT-CLIENT# wg-quick up wg0
```

## 5. Сканирование портов: до и после

Показать сохранённый `outputs/EXT-CLIENT-nmap-before.txt` (виден только 22/tcp), затем вживую:

```
EXT-CLIENT# nmap -Pn -sS -T4 -p 1-1024 203.0.113.10       # все порты open — TARPIT
HQ-FW#      iptables -L PORTSCAN -n -v                     # растёт счётчик TARPIT
HQ-FW#      journalctl -k | grep -c FW-PORTSCAN
```

## 6. DELUDE (порт-ловушка)

Через минуту после п. 5 (чтобы источник выпал из `recent`):

```
EXT-CLIENT# nmap -Pn -sS -p 22,80,12345 203.0.113.10        # 22, 80 filtered; 12345 open (netbus)
HQ-FW#      iptables -L INPUT -n -v | grep DELUDE           # счётчик растёт
HQ-FW#      iptables -t mangle -L POSTROUTING -n -v         # счётчик TTL-исправления растёт
```

Сохранённый вывод — `outputs/EXT-CLIENT-nmap-delude.txt`, `outputs/HQ-FW-delude-counters.txt`.

## 7. SSH к МЭ — только по ключу

```
EXT-CLIENT# ssh fwadmin@192.168.15.134 hostname                       # hq-fw (по ключу)
EXT-CLIENT# ssh -o PubkeyAuthentication=no fwadmin@192.168.15.134 true # Permission denied (publickey)
EXT-CLIENT# ssh root@192.168.15.134 true                               # Permission denied (publickey)
HQ-FW#      fail2ban-client status sshd
```

## 8. Устойчивость: перезагрузка МЭ

```
HQ-FW# reboot
HQ-FW# iptables -S | wc -l; wg show wg0 | head -3; systemctl is-active fail2ban auditd netfilter-persistent
```
