# Проект КВС головного офиса (согласован 2026-10-10)

Строится в той же лабе `BKS1.unl` — туннель к филиалу идёт через общих ISP.
Структура повторяет филиал (те же решения проще защищать в отчёте), плюс то, что
методичка требует только от ГО: публичный канал, DMZ, VPN-шлюз, DHCP/DNS/NTP, IPv6.

## Узлы (18, id 20–37; всего в лабе 37)

| Узел | Образ | Роль |
|---|---|---|
| HQ-EDGE | IOL L3 | граница: публичный IP, NAT, VPN-шлюз (GRE over IPsec), DMZ, фильтрация ACL |
| HQ-CORE-1, HQ-CORE-2 | IOL L2 + routing | ядро, дублированное, OSPF ECMP; между ядрами — L3 EtherChannel (Po1, LACP, 2 линка) |
| HQ-DSW-1, HQ-DSW-2 | IOL L2 + routing | распределение: SVI, **VRRP**, MSTP, Po1 (LACP), межсегментные ACL, DHCP relay |
| HQ-ASW-1, HQ-ASW-2 | IOL L2 | доступ: Port Security, DHCP Snooping, DAI (IPSG на IOL не используется); аплинки — LACP по 2 линка к каждому DSW |
| HQ-FW-1, HQ-FW-2 | pfSense 2.7.2 (qemu) | МЭ в прозрачном режиме (L2-мост, фильтрация выключена): FW-1 — в разрыве HQ-EDGE–HQ-CORE-1, FW-2 — HQ-EDGE–HQ-CORE-2 и HQ-EDGE–HQ-DMZ; управление — 192.168.226.20/.21 (облако NetManagement) |
| HQ-DMZ | IOL L2 | коммутатор DMZ (VLAN 100), подключён к HQ-EDGE через HQ-FW-2 |
| HQ-INFRA | IOL L3 (no ip routing) | DHCP + DNS + NTP-сервер (средствами IOS) |
| SRV-WEB, SRV-MAIL | VPCS | публичные серверы в DMZ (IPv4 + IPv6 SLAAC) |
| SRV-INT | VPCS | внутренний сервер |
| PC-HQ-ADMIN, PC-HQ-STAFF, PC-HQ-GUEST, CAM-HQ | VPCS | пользователи по сегментам |

МЭ: методичка требует «интеграцию МЭ, разработка которого — в следующих ЛР». В ЛР1 два pfSense встроены
в разрыв каналов EDGE–ядро (по одному на каждое ядро, отказ МЭ обрабатывает OSPF) и EDGE–DMZ (HQ-FW-2)
в прозрачном режиме: адресация и маршрутизация не меняются, фильтрации нет. DMZ пока защищает ACL DMZ-IN
на HQ-EDGE; в отчёте указать, что далее DMZ закрывается МЭ + IPS/WAF. Отказ HQ-FW-2 отрезает DMZ.

## Отличия от филиала (обязательно, согласовано)

1. **VRRP вместо HSRP** на HQ-DSW (стандарт IEEE/RFC 5798 вместо проприетарного Cisco) —
   в отчёте сравнение HSRP/VRRP. Проверено: `vrrp` есть на образе IOL L2.
2. **L3 EtherChannel между ядрами** (Po1, 2 линка, LACP) — канал между ядрами не теряется
   при обрыве одного линка, ёмкость ×2.
3. **LACP на аплинках доступа** — по 2 линка от каждого HQ-ASW к каждому HQ-DSW
   (Po к DSW-1 и Po к DSW-2) — доп. задача №2 методички (пропускная способность ≥ ×1,5).

## Порты

| Узел (слотов) | Порт → куда |
|---|---|
| HQ-EDGE (1 → 4 порта) | e0/0 → ISP-1 e0/2; e0/1 → HQ-FW-1 e0 (→ HQ-CORE-1 e0/0); e0/2 → HQ-FW-2 e0 (→ HQ-CORE-2 e0/0); e0/3 → HQ-FW-2 e2 (→ HQ-DMZ e0/0) |
| HQ-FW-1 (5) | e0 (vtnet0) → HQ-EDGE e0/1; e1 (vtnet1) → HQ-CORE-1 e0/0; bridge0 = e0+e1; e4 (vtnet4) → NetManagement |
| HQ-FW-2 (5) | e0 → HQ-EDGE e0/2; e1 → HQ-CORE-2 e0/0 (bridge0); e2 → HQ-EDGE e0/3; e3 → HQ-DMZ e0/0 (bridge1); e4 → NetManagement |
| HQ-CORE-1 (2) | e0/0 → HQ-EDGE e0/1 (через HQ-FW-1); e0/1 → HQ-DSW-1 e0/0; e0/2 → HQ-DSW-2 e0/0; e0/3, e1/0 → HQ-CORE-2 e0/3, e1/0 (Po1) |
| HQ-CORE-2 (2) | e0/0 → HQ-EDGE e0/2 (через HQ-FW-2); e0/1 → HQ-DSW-1 e0/1; e0/2 → HQ-DSW-2 e0/1; e0/3, e1/0 → HQ-CORE-1 (Po1) |
| HQ-DSW-1 (3) | e0/0 → CORE-1; e0/1 → CORE-2; e0/2–3 → HQ-DSW-2 e0/2–3 (Po1); e1/0–1 → HQ-ASW-1 e0/0–1 (Po11); e1/2–3 → HQ-ASW-2 e0/0–1 (Po12) |
| HQ-DSW-2 (3) | e0/0 → CORE-1; e0/1 → CORE-2; e0/2–3 → HQ-DSW-1 (Po1); e1/0–1 → HQ-ASW-1 e0/2–3 (Po21); e1/2–3 → HQ-ASW-2 e0/2–3 (Po22) |
| HQ-ASW-1 (2) | e0/0–1 → DSW-1 (Po1); e0/2–3 → DSW-2 (Po2); e1/0 → PC-HQ-ADMIN; e1/1 → PC-HQ-STAFF; e1/2 → PC-HQ-GUEST |
| HQ-ASW-2 (2) | e0/0–1 → DSW-1 (Po1); e0/2–3 → DSW-2 (Po2); e1/0 → SRV-INT; e1/1 → HQ-INFRA e0/0; e1/2 → CAM-HQ |
| HQ-DMZ (1) | e0/0 → HQ-EDGE e0/3 (через HQ-FW-2); e0/1 → SRV-WEB; e0/2 → SRV-MAIL |

## Схема подключений

```
            ISP-1 e0/2 ─── e0/0 HQ-EDGE e0/3 ─── HQ-DMZ ─┬─ SRV-WEB
                                │e0/1   │e0/2              └─ SRV-MAIL
                            HQ-CORE-1 ─ HQ-CORE-2   (e0/3 между ядрами)
                             │     ╲   ╱     │      (ядра — L3 Po1, 2 линка)
                          HQ-DSW-1 ═Po1═ HQ-DSW-2   (VRRP)
                             ║  ╲╲     ╱╱  ║        (═ — LACP по 2 линка)
                         HQ-ASW-1        HQ-ASW-2
            PC-HQ-ADMIN, PC-HQ-STAFF,    SRV-INT, HQ-INFRA,
            PC-HQ-GUEST                  CAM-HQ
```

Каждое ядро связано с обоими DSW; каждый ASW — с обоими DSW, по 2 линка в LACP.

## Адресация — 10.1.0.0/16 (VLSM)

| VLAN | Назначение | Подсеть | VIP / DSW-1 / DSW-2 | VRRP master |
|---|---|---|---|---|
| 10 | ADMIN (администраторы) | 10.1.10.0/27 | .1 / .2 / .3 | DSW-1 |
| 20 | STAFF (сотрудники) | 10.1.20.0/24 | .1 / .2 / .3 | DSW-2 |
| 50 | SERVERS (внутренние серверы) | 10.1.50.0/26 | .1 / .2 / .3 | DSW-1 |
| 55 | INFRA (DHCP/DNS/NTP) | 10.1.55.0/28 | .1 / .2 / .3; HQ-INFRA .10 | DSW-1 |
| 60 | GUEST | 10.1.60.0/24 | .1 / .2 / .3 | DSW-2 |
| 70 | CCTV | 10.1.70.0/26 | .1 / .2 / .3 | DSW-2 |
| 99 | MGMT | 10.1.99.0/28 | .1 / .2 / .3; ASW .11/.12 | DSW-2 |
| 100 | DMZ (на HQ-EDGE, не в ядре) | 10.1.100.0/28 + fd00:1:100::/64 (ULA) | HQ-EDGE .1 / fd00:1:100::1 | — |
| 999 | BLACKHOLE | — | — | — |

Транзит 10.1.255.0/24 по /30: HQ-EDGE–CORE-1 .0, HQ-EDGE–CORE-2 .4, CORE-1–DSW-1 .8,
CORE-1–DSW-2 .12, CORE-2–DSW-1 .16, CORE-2–DSW-2 .20, CORE-1–CORE-2 (Po1) .24.
Router-id 10.1.254.x. OSPF area 0 внутри ГО.

## WAN и связь с филиалом

- Публичный канал: ISP-1 e0/2 – HQ-EDGE e0/0, **203.0.113.0/30** (.1 / .2). На ISP-2 —
  статический маршрут на эту сеть через ISP-1.
- NAT overload на HQ-EDGE e0/0 для внутренних сетей; статический NAT/port-forward
  на SRV-WEB (публикация сервера из DMZ).
- **Tunnel0** BR-EDGE (198.51.100.2) ↔ HQ-EDGE (203.0.113.2): GRE over IPsec
  (IKEv1, AES-256/SHA-256, DH 14, PSK, transport mode), адреса 172.16.0.0/30.
- **Tunnel1** (резерв) BR-EDGE через ISP-2 (192.0.2.2) ↔ HQ-EDGE: 172.16.0.4/30,
  увеличенная стоимость OSPF — переключение при отказе ISP-1 филиала.
- OSPF area 0 поверх туннелей — филиал и ГО обмениваются маршрутами 10.1/16 и 10.2/16.
- Трафик 10.0.0.0/8 → 10.0.0.0/8 исключается из NAT на обоих EDGE.
- Централизованное управление: из ADMIN ГО (10.1.10.0/27) разрешён доступ к MGMT
  филиала (10.2.99.0/28) по SSH — правка ACL MGMT-OUT на DSW филиала + SSH на
  коммутаторах филиала.

## DMZ

- VLAN 100 на HQ-DMZ, шлюз — HQ-EDGE e0/3. ACL на HQ-EDGE: из интернета в DMZ —
  только HTTP/HTTPS/SMTP к своим серверам; из DMZ во внутреннюю сеть — запрещено;
  из внутренней сети в DMZ — разрешено.
- IPv6 Dual-Stack: `ipv6 unicast-routing`, fd00:1:100::1/64 на e0/3, SLAAC (RA) —
  SRV-WEB/SRV-MAIL получают адрес автоматически (`ip auto` на VPCS), проверка ping6.

## Сервисы (HQ-INFRA, 10.1.55.10)

- DHCP: пулы для VLAN 10/20/60/70 ГО (relay с SVI DSW).
- DNS: `ip dns server` + записи hq-edge, srv-web, srv-int и т. п.; клиентам выдаётся в DHCP.
- NTP: `ntp master` на HQ-INFRA; все устройства ГО и филиала — `ntp server 10.1.55.10`
  (филиал — через туннель).

## Безопасность (как в филиале)

Port Security, DHCP Snooping, DAI на HQ-ASW; ACL между сегментами на HQ-DSW
(гости — только интернет, CCTV — только к серверам, MGMT — только из ADMIN).

## Порядок реализации

7a. Создать ноды и линки, базовая настройка (hostname, VLAN, транки, MSTP, LACP).
7b. L3: SVI, HSRP, OSPF, ядро, HQ-EDGE + ISP-1, NAT → хосты ГО в интернете.
7c. HQ-INFRA (DHCP/DNS/NTP), DMZ, ACL, безопасность доступа.
8.  Туннели GRE over IPsec + OSPF, исключение из NAT, управление филиалом из ГО.
9.  IPv6 в DMZ.
10. Верификация п. 2.4.
