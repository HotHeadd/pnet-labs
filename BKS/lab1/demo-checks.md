# Сценарий проверок на сдаче (стенд BKS1)

Перед началом: на VPCS выданы адреса (см. `stand/README.md`). Вывод VPCS читается в консоли.
Статус прогона 2026-10-16: все пункты 1–7 ✅ (`outputs/demo-*`, `ASW-1-mstp-fail.txt`, `HQ-ASW-1-mstp-fail.txt`,
`demo-2-traceroute-same-dsw.txt`). Хост↔хост между VLAN одного DSW работает после `no ip cef` на DSW/HQ-DSW.
Полный регресс после интеграции МЭ (16.10, вечер): пункты 1–9 ✅ — `outputs/regress-fw-20261016.txt`.
МЭ прозрачные — в traceroute их не видно, это нормально.
Вывод VPCS во время отказа MSTP не сохраняется — на сдаче смотреть пинг вживую в консоли браузера.

## 1. Интернет с нужных машин

| Хост | Команда | Ожидание |
|---|---|---|
| PC-ADMIN, PC-DEV1, PC-ACC, PC-SALES, PC-GUEST (филиал) | `ping 8.8.8.8` | есть |
| CAM1 (филиал) | `ping 8.8.8.8` | **нет** (CCTV-IN) |
| PC-HQ-ADMIN, PC-HQ-STAFF, PC-HQ-GUEST | `ping 8.8.8.8` | есть |
| CAM-HQ | `ping 8.8.8.8` | **нет** (HQ-CCTV-IN) |
| SRV-WEB (DMZ) | `ping 8.8.8.8` | есть |

## 2. traceroute

| Откуда → куда | Команда | Ожидание |
|---|---|---|
| PC-DEV1 → PC-DEV2 (один VLAN 20) | `trace 10.2.20.11` | 1 хоп, сразу хост |
| PC-ADMIN → PC-DEV1 (VLAN 10 → 20) | `trace 10.2.20.10` | хоп 1 — шлюз 10.2.10.1/.2, хоп 2 — хост |
| PC-HQ-STAFF → PC-ADMIN (ГО → филиал) | `trace 10.2.10.10` | HQ-DSW → HQ-CORE → HQ-EDGE → 172.16.0.2 (туннель) → BR-CORE → DSW → хост |
| PC-ADMIN → 8.8.8.8 | `trace 8.8.8.8` | через BR-EDGE и ISP-1 |

## 3. MSTP

- HQ-ASW-1: `show spanning-tree mst 1` / `mst 2` — в каждом экземпляре свой Po в Altn BLK.
- Отказ: на PC-HQ-ADMIN `ping 10.1.10.1 -t`, на HQ-ASW-1 `interface port-channel1` → `shutdown` → ping восстанавливается через Po2; `no shutdown`.

## 4. OSPF

- BR-EDGE / HQ-EDGE: `show ip ospf neighbor` (соседи по туннелям и внутри площадки).
- HQ-EDGE: `show ip route ospf` — сети 10.2.x через Tunnel0.
- DSW-1: `show ip route 0.0.0.0` — ECMP через два ядра; отказ ядра (уже снято, `outputs/DSW-1-*corefail*`).

## 5. DMZ

- SRV-WEB: `ping 8.8.8.8` — есть; `ping 10.1.50.10` (SRV-INT) — **нет**; `ping 10.2.10.10` — **нет**.
- HQ-EDGE: `show ip access-lists DMZ-IN` — счётчик deny растёт.
- Публикация: ISP-1 `telnet 203.0.113.2 80 /source-interface Loopback0` → на HQ-EDGE `show ip nat translations` —
  трансляция 203.0.113.2:80 → 10.1.100.10:80 с адресом 8.8.8.8 (трафик идёт через мост HQ-FW-2).
- IPv6: на SRV-WEB `ip auto`; HQ-EDGE `show ipv6 neighbors Ethernet0/3` → `ping <SLAAC-адрес SRV-WEB>`
  (VPCS не отвечает на ping ff02::1 — это не ошибка).

## 6. Изоляция VLAN

- PC-SALES → `ping 10.2.20.42` (файловый сервер) — есть; `ping 10.2.20.10` (PC-DEV1) — **нет** (вариант 5).
- PC-GUEST → `ping 10.2.10.10` — **нет**; PC-HQ-GUEST → `ping 10.1.50.10` — **нет**.
- PC-DEV1 → `ping 10.2.99.11` (управление) — **нет**; PC-ADMIN → `ping 10.2.99.11` — есть.

## 7. IP–MAC–порт

- ASW-1: `show ip dhcp snooping binding` — привязки IP–MAC–порт–VLAN.
- ASW-1: `show port-security`, `show port-security interface e0/2`.
- Подмена IP: PC-GUEST `ip 10.2.60.50/24 10.2.60.1` → `ping 10.2.60.1` — **нет**;
  ASW-3: `show ip arp inspection statistics vlan 60` (DHCP Drops растёт), `show logging | include DAI`.
  Вернуть: `ip dhcp`.

## 8. Межсетевые экраны ГО (HQ-FW-1/2, прозрачный режим)

| Что | Где | Ожидание |
|---|---|---|
| Мосты | консоль МЭ (VNC) → `8` (Shell) → `ifconfig bridge0` (на HQ-FW-2 ещё `bridge1`) | члены vtnet0+vtnet1 (и vtnet2+vtnet3) |
| Трафик идёт через МЭ | HQ-FW-2: `ifconfig bridge1 addr` | MAC SRV-WEB/SRV-MAIL (`00:50:79:…`) и HQ-EDGE |
| Веб-интерфейс | браузер на хосте: `https://192.168.226.20`, `.21` (admin / pfsense) | Dashboard, Interfaces → Bridges |
| Отказ МЭ | `stop_node` HQ-FW-1 (или Stop в веб-морде), ~40 с | HQ-EDGE `show ip ospf neighbor` — нет соседа по e0/1; PC-HQ-STAFF `ping 8.8.8.8` и `ping 10.2.10.10` — есть |
| Возврат | Start HQ-FW-1, ~2 мин | сосед 10.1.254.1 по e0/1 снова FULL |

В консоли pfSense (VNC) не набираются символы с Shift (`|`, `$`, `(`…) — команды без конвейеров.
Отказ HQ-FW-2 отрезает DMZ (DMZ подключена только через него) — это ожидаемо, в отчёте как единичная точка отказа.

## 9. Сервисы ГО: NTP и DNS

- Любой коммутатор/маршрутизатор: `show ntp associations` — `*~10.1.55.10`, `show ntp status` — `Clock is synchronized, stratum 4`.
  Филиал (ASW-1) — время через VPN; DSW: `show ip access-lists MGMT-OUT` — строка 25 (NTP) набирает совпадения.
- HQ-DSW-1: `ping srv-int.hq.local`, `ping hq-infra` — имя разрешается через 10.1.55.10, пинг есть.
- VPCS ГО: `show ip` — DNS 10.1.55.10, DOMAIN NAME hq.local (выданы DHCP).
