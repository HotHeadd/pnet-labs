# Сценарий проверок на сдаче (стенд BKS1)

Перед началом: на VPCS выданы адреса (см. `stand/README.md`). Вывод VPCS читается в консоли.
Статус прогона 2026-10-16: все пункты 1–7 ✅ (`outputs/demo-*`, `ASW-1-mstp-fail.txt`, `HQ-ASW-1-mstp-fail.txt`,
`demo-2-traceroute-same-dsw.txt`). Хост↔хост между VLAN одного DSW работает после `no ip cef` на DSW/HQ-DSW.
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
- Публикация: ISP-1 `telnet 203.0.113.2 80` → на HQ-EDGE `show ip nat translations` — статическая трансляция на 10.1.100.10:80.

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
