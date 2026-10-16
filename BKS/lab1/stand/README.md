# Стенд BKS1 — филиал + головной офис (база для следующих ЛР по БКС)

Файл: `pnetlab_export-20261016-193000.zip` (экспорт PNETLab, лаба `BKS1.unl`, 37 нод + облако NetManagement; итоговое состояние на 16.10.2026).
Образы: Cisco IOL L3 `L3-ADVENTERPRISEK9-M-15.4-2T.bin`, IOL L2 `L2-ADVENTERPRISEK9-M-15.2-IRON-20151103.bin`, VPCS,
pfSense `pfsense-2.7.2` (qemu, нужен KVM).

## Как поднять

1. PNETLab → Import → загрузить zip.
2. Start all. IOL грузятся с готовыми конфигами (startup-config включён у всех нод).
3. **VPCS адреса не сохраняют** — после каждого старта задать вручную в консоли:
   - статические: SRV-FILE `ip 10.2.20.42/24 10.2.20.1`, SRV-INT `ip 10.1.50.10/26 10.1.50.1`,
     SRV-WEB `ip 10.1.100.10/28 10.1.100.1` + `ip auto` (IPv6 SLAAC), SRV-MAIL `ip 10.1.100.11/28 10.1.100.1` + `ip auto`;
   - остальные: `ip dhcp` (отдельной командой, ничего не нажимать 5–10 с; если в `show ip` 0.0.0.0 — повторить).
4. Если хост не отвечает после старта — на коммутаторе доступа `show port-security`: если на порту есть нарушения, сделать `shutdown`/`no shutdown` порта (VPCS меняют MAC между запусками).
5. **МЭ HQ-FW-1/2 (pfSense)**: диски qemu в выгрузку не входят — после импорта pfSense стартует с заводским конфигом.
   Восстановить: консоль (VNC) → `1` → WAN `vtnet4`, LAN — нет → `8` → `pfctl -d`; веб-интерфейс по адресу из DHCP
   (сеть VMware) → Diagnostics → Backup & Restore → `../configs/HQ-FW-1.xml` / `HQ-FW-2.xml`
   (или `python ../tools/pfsense-gui.py restore <адрес> <файл>`). Логин admin / pfsense. Пока МЭ не настроены,
   трафик через них не идёт — ГО без связи с ядром и DMZ. Консоль нод — VNC (в telnet pfSense ничего не выводит).
6. Консоль без паролей (`enable` без пароля). SSH (только коммутаторы филиала, только из ADMIN ГО/филиала): `netadmin` / `BKS1-admin`; пример с HQ-DSW-1: `ssh -l netadmin 10.2.99.11`.

## Что где

| Площадка | Блок | Узлы |
|---|---|---|
| Филиал | 10.2.0.0/16 | BR-EDGE (NAT, 2 провайдера: ISP-1 основной, ISP-2 резерв по IP SLA), BR-CORE + BR-CORE-2, DSW-1/2 (HSRP, ACL), ASW-1/2/3, SRV-DHCP 10.2.50.10 |
| ГО | 10.1.0.0/16 | HQ-EDGE (публичный 203.0.113.2, NAT, DMZ, VPN), HQ-FW-1/2 (pfSense, прозрачный мост EDGE–ядро и EDGE–DMZ), HQ-CORE-1/2 (L3 Po), HQ-DSW-1/2 (VRRP), HQ-ASW-1/2 (LACP), HQ-INFRA 10.1.55.10 (DHCP/DNS hq.local/NTP), HQ-DMZ |
| Управление | 192.168.226.0/24 | облако NetManagement (pnet0): HQ-FW-1 .20, HQ-FW-2 .21 — веб-интерфейс pfSense с хоста |
| «Интернет» | — | ISP-1 (lo 8.8.8.8), ISP-2 (lo 1.1.1.1) |

VLAN ГО: 10 ADMIN, 20 STAFF, 50 SERVERS, 55 INFRA, 60 GUEST, 70 CCTV, 99 MGMT, 100 DMZ (на HQ-EDGE), 999 BLACKHOLE.
VLAN филиала: 10 ADMIN, 20 DEV, 30 ACC, 40 SALES, 50 SERVERS, 60 GUEST, 70 CCTV, 99 MGMT, 999 BLACKHOLE.
Везде шлюз — `.1` (виртуальный адрес HSRP/VRRP), коммутаторы распределения — `.2`/`.3`.

- Маршрутизация: OSPF area 0 на обеих площадках, связаны через VPN. OSPF HQ-EDGE ↔ ядра идёт сквозь прозрачные МЭ.
- NTP: все IOL берут время с HQ-INFRA 10.1.55.10 (филиал — через VPN).
- VPN: GRE over IPsec BR-EDGE ↔ HQ-EDGE (IKEv1, AES-256/SHA-256, DH14, PSK `BKS1-vpn-psk`),
  Tunnel0 172.16.0.0/30 через ISP-1 (основной), Tunnel1 172.16.0.4/30 через ISP-2 (резерв, OSPF cost 100).
- ACL ГО (HQ-DSW): гости — только интернет, CCTV — только к серверам VLAN 50, VLAN 99 — только из ADMIN.
- IPv6: DMZ dual-stack, fd00:1:100::/64, SLAAC с HQ-EDGE.
- DMZ: SRV-WEB/SRV-MAIL; из DMZ во внутреннюю сеть запрещено (ACL DMZ-IN на HQ-EDGE e0/3);
  опубликованы 203.0.113.2:80/443 → SRV-WEB, :25 → SRV-MAIL.

## Чего на стенде пока нет

- Политик МЭ: HQ-FW-1/2 встроены в топологию, но фильтрация выключена (`disablefilter`) — разработка МЭ в следующих ЛР;
  DMZ сейчас защищает ACL DMZ-IN на HQ-EDGE.
- IP Source Guard не используется (на IOL ломает DHCP-хостов). Port Security (без sticky) — на всех коммутаторах доступа. DHCP Snooping и DAI — на всех; в ГО каждый HQ-ASW снупит только VLAN своих хостов (HQ-ASW-1: 10,20,60; HQ-ASW-2: 50,55,70) — **не добавлять один VLAN на оба HQ-ASW**: на IOL L2 с Port-channel это даёт DHCP-шторм.

Подробная адресация и порты — `../hq-plan.md`, все введённые команды — `../commands/`.

## Особенности эмулятора (учтены в конфигурации)

- На DSW/HQ-DSW (IOL L2 с маршрутизацией между SVI) выключен CEF (`no ip cef`): с CEF транзитный трафик между VLAN
  одного коммутатора распределения до хостов не доходит.
- DHCP Snooping в ГО: каждый HQ-ASW проверяет только VLAN своих хостов (см. выше). Если один VLAN включить на обоих —
  DHCP-пакеты начинают ходить по кругу, у коммутаторов ГО кончается память, они зависают.
- IOL-ноды иногда падают (status stopped) — запустить заново (DSW-1 любит упасть через пару минут после Start all).
- VPCS может перестать отвечать (`pipe2 failed`, `queue is full`) — перезапустить ноду и задать IP заново.
- После перезапуска коммутатора доступа привязки DHCP Snooping теряются, и DAI режет ARP его хостов — на этих хостах
  повторить `ip dhcp`.
