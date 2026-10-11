# ЛР1 БКС — проектирование КВС филиала и головного офиса

Лаба в PNETLab: `/BKS labs/BKS1.unl`, 35 нод (филиал id 1–19, ГО id 20–35), у всех `config: 1`.
PNETLab — VM на Windows-хосте (20 ГБ RAM), доступ через Tailscale `100.100.57.19` (узел `pnetlab`).
Вариант доп. задания (п. 1.3.3): **№5** — отдел продаж (VLAN 40) имеет доступ в VLAN разработки только к файловому серверу 10.2.20.42.
Требования преподавателя: нужные хосты выходят в интернет, изоляция VLAN показана проверками; второй провайдер и дублирование ядра.
На сдаче проверяют: traceroute между VLAN (в одном и разных), ping через MSTP (отказ аплинка), OSPF, DMZ (WAN есть, LAN нет), IP–MAC–порт. Сценарий — `demo-checks.md`.
Условие — `preable/Лабораторная работа №1 (БКС).pdf` (25 стр.; стр. 23 — мусор «Где: В раздел 2.3…»; МЭ в ГО — следующие ЛР).
Проект ГО и порты — `hq-plan.md`. Для получателей стенда — `stand/README.md`.

## Состояние на 2026-10-11 (конец сессии)

Сохранено: `write memory` везде + `export_config` всех 35 нод; ключевые строки проверены в выгрузке
(snooping/DAI на HQ-ASW, link-type p2p в филиале, ACL, VPN, IPv6). Пользователь клонирует лабу для других.
Временных изменений на стенде нет (DEV-IN, use-bia, Po1, snooping — всё возвращено).

**Запуск после старта лабы:** IOL поднимаются сами. VPCS — вручную: SRV-FILE `ip 10.2.20.42/24 10.2.20.1`,
SRV-INT `ip 10.1.50.10/26 10.1.50.1`, SRV-WEB `ip 10.1.100.10/28 10.1.100.1` + `ip auto`, SRV-MAIL `ip 10.1.100.11/28 10.1.100.1` + `ip auto`,
остальные `ip dhcp` (отдельной командой; проверять `show ip dhcp binding` на SRV-DHCP/HQ-INFRA, зависшие повторить).
Если порт доступа в нарушении Port Security (VPCS сменил MAC) — `shutdown`/`no shutdown` порта.

## ОТКРЫТЫЕ ПРОБЛЕМЫ (начать следующую сессию отсюда)

1. **[критично для сдачи] Хост↔хост между VLAN, которые маршрутизирует один DSW (HSRP-active для обоих VLAN), не работает.**
   - Филиал, не работает: PC-ADMIN(10)↔PC-ACC(30) и ADMIN→SRV-DHCP(50) — все active на DSW-1; **PC-SALES(40)↔SRV-FILE 10.2.20.42(20) — оба active на DSW-2 = вариант 5!**
   - Работает, когда запрос уходит в VLAN, где этот DSW standby: ADMIN↔SALES, ADMIN→.42, DEV1→ADMIN; ГО↔филиал; интернет.
   - Пинги с самих DSW из любой SVI (`ping X source VlanN`) — работают. ARP/CEF/MAC на DSW верные.
   - Исключено: ACL (снятие DEV-IN не помогло), DAI (выключение на HQ-ASW не помогло — но см. п.2), VPCS (с IOL-хостом SRV-DHCP то же), `standby use-bia` (не помог), link-type p2p (сбой был и до).
   - По счётчикам: запрос SALES→.42 проходит SALES-IN строка 20 на DSW-2, ответа (DEV-IN строка 10) нет; .42→SALES — DEV-IN строка 10 растёт, SALES-IN 20 нет. Т.е. транзитный пакет, выходящий в VLAN, где DSW active, до хоста не доходит/ответ не возвращается.
   - Следующие шаги: (а) сравнить с ГО — HQ-ADMIN(10)→SRV-INT(50) (оба master HQ-DSW-1) и STAFF(20)→CAM-HQ(70) (оба master HQ-DSW-2) теперь, когда HQ-DSW снова работают (в 7c STAFF→CAM работал!); (б) если в ГО работает — сравнить конфиги HQ-DSW (VRRP) и DSW филиала (HSRP v2); (в) проверить по очереди без DHCP Snooping / Port Security на ASW филиала; (г) снять трафик: `show interfaces` счётчики на портах хоста и аплинках ASW до/после.
2. **HQ-DSW-1 и HQ-DSW-2 упали (status stopped)** примерно когда им отправили `interface range Port-channel1 , Port-channel1x - 1y` + `spanning-tree link-type point-to-point`. Подняты `start_node`, работают из NVRAM без link-type. На HQ-DSW link-type p2p НЕ стоит (на HQ-ASW стоит) → в ГО MSTP-переключение по таймерам (~30 с). Попробовать применить по одному Po и проверить, не падает ли нода. Тесты ГО (STAFF→CAM, HQ-ADMIN→SRV-INT) во время п.1 могли падать из-за этого — перепроверить.
3. Не дошли в прогоне `demo-checks.md`: п.6 (остальная изоляция с хостов), п.7 (демо подмены IP → DAI). MSTP-демо на филиале после p2p не повторялось.

## План (статус)

1. [x] Каркас отчёта (тема, цель, задание, структура, таблицы адресации) — `main.typ`.
2. [x] Резервирование ядра филиала (BR-CORE-2, ECMP). 3. [x] Тесты отказа провайдера и ядра.
4. [x] Безопасность доступа обеих площадок: Port Security (без sticky), DHCP Snooping, DAI (+ ARP ACL DAI-STATIC для статических серверов), неисп. порты VLAN 999; IPSG не используется (ломает DHCP-хостов на IOL).
5. [ ] Листинги сделанного в Desktop (VLAN/MSTP/LACP/HSRP/OSPF/DHCP/NAT/ACL/ISP-2) — из итоговых конфигов.
6. [x] Проект ГО. 7. [x] ГО: ноды, L2, L3 (OSPF, VRRP, NAT), сервисы, DMZ, ACL ГО. 8. [x] GRE over IPsec ×2 + OSPF; SSH-управление филиалом из ГО.
9. [x] IPv6 DMZ + SLAAC. 
10. [~] Верификация п. 2.4 / сценарий сдачи — частично (см. «Открытые проблемы»).
11. [ ] Бумажная часть: логическая схема, расчёт пропускной способности и PoE, выбор оборудования.
12. [ ] Отчёт: оформить по журналу ниже + `commands/`, `outputs/` (режим «сначала стенд» — `main.typ` пока содержит только каркас и разделы до L2 ГО), схемы, заключение, чистка `#todo`.

## Порядок работы

Все команды, введённые на устройствах, — в `commands/<узел>-<что>.txt`, выводы проверок — `outputs/`, факты — в журнал ниже.
Отчёт пока не верстаем (режим «сначала стенд»), оформление — шаг 12. Ревью пользователем — по крупным пунктам.

## Требования методички (чек-лист)

- Филиал: 3 уровня; VLAN разработка/бухгалтерия/гости/CCTV/MGMT; 10.2.0.0/16 VLSM — ✅.
- 1.2.2: расчёт пропускной способности по уровням, PoE+ бюджет, конкретные модели — ❌ (бумажная часть).
- Доступ: Port Security, DAI, IP-MAC binding, ACL, VLAN, MSTP, LACP — ✅ (IP-MAC = DAI+PS; IPSG на IOL не работает — описать как ограничение).
- Распределение/ядро: OSPF, ACL, HSRP — ✅; ядро — дублирование (BR-CORE-2) ✅; в ядре без ACL/NAT ✅.
- 1.3.3 вариант 5 — ⚠️ ACL настроены, «SALES→DEV запрещено» работает, но «SALES→.42 разрешено» НЕ проходит (открытая проблема №1). Второй провайдер — требование преподавателя, ✅.
- ГО — ✅ всё, кроме подбора оборудования (бумажная часть): Core/Dist/Access; DMZ (упомянуть IPS/WAF), MGMT, серверы, отделы; VLAN серверы/сотрудники/гости/CCTV/инфраструктура (NTP/DNS/DHCP)/DMZ; публичный IP + NAT; VPN-шлюз (IPsec или GRE over IPsec) + OSPF поверх; управление оборудованием филиалов; IPv6 DMZ (ULA fd00::/8 или GUA) + SLAAC + ICMPv6; DHCP/DNS/NTP; безопасность как в филиале; подбор оборудования.
- 2.4: ping/traceroute с source; `show ip route`, `show ipv6 route`; `show spanning-tree` с Alternate/Blocking; `show crypto ...`; `show ip nat translations`.

## id нод

| id | Нода | Образ | id | Нода |
|---|---|---|---|---|
| 1 | ISP (ISP-1) | IOL L3 | 10 | PC-ADMIN |
| 2 | BR-EDGE | IOL L3 | 11 | PC-DEV1 |
| 3 | BR-CORE | IOL L2 + ip routing | 12 | PC-DEV2 |
| 4 | DSW-1 | IOL L2 + ip routing | 13 | PC-ACC |
| 5 | DSW-2 | IOL L2 + ip routing | 14 | PC-SALES |
| 6 | ASW-1 | IOL L2 | 15 | PC-GUEST |
| 7 | ASW-2 | IOL L2 | 16 | CAM1 |
| 8 | ASW-3 | IOL L2 | 17 | SRV-FILE (VPCS, 10.2.20.42) |
| 9 | SRV-DHCP | IOL L3, no ip routing | 18 | ISP-2 (IOL L3) |
| | | | 19 | BR-CORE-2 (IOL L2 + ip routing) |

ГО (id 20–35): 20 HQ-EDGE (L3), 21/22 HQ-CORE-1/2, 23/24 HQ-DSW-1/2, 25/26 HQ-ASW-1/2, 27 HQ-DMZ (L2), 28 HQ-INFRA (L3), 29 SRV-WEB, 30 SRV-MAIL, 31 SRV-INT, 32 PC-HQ-ADMIN, 33 PC-HQ-STAFF, 34 PC-HQ-GUEST, 35 CAM-HQ (VPCS). Порты — `hq-plan.md`. Новые ноды созданы с `config: 1`.

## Адресация

| VLAN | Имя | Подсеть | VIP / DSW-1 / DSW-2 | HSRP active |
|---|---|---|---|---|
| 10 | ADMIN | 10.2.10.0/27 | .1 / .2 / .3 | DSW-1 |
| 20 | DEV | 10.2.20.0/24 | .1 / .2 / .3 | DSW-2 |
| 30 | ACC | 10.2.30.0/26 | .1 / .2 / .3 | DSW-1 |
| 40 | SALES | 10.2.40.0/26 | .1 / .2 / .3 | DSW-2 |
| 50 | SERVERS | 10.2.50.0/25 | .1 / .2 / .3 | DSW-1 |
| 60 | GUEST | 10.2.60.0/24 | .1 / .2 / .3 | DSW-2 |
| 70 | CCTV | 10.2.70.0/26 | .1 / .2 / .3 | DSW-1 |
| 99 | MGMT | 10.2.99.0/28 | .1 / .2 / .3; ASW-1/2/3 .11/.12/.13 | DSW-2 |
| 999 | BLACKHOLE | — | native на транках, неиспользуемые порты | — |

| Линк | Подсеть | Адреса |
|---|---|---|
| BR-EDGE e0/1 – BR-CORE e0/0 | 10.2.255.0/30 | .1 / .2 |
| BR-CORE e0/1 – DSW-1 e0/0 | 10.2.255.4/30 | .5 / .6 |
| BR-CORE e0/2 – DSW-2 e0/0 | 10.2.255.8/30 | .9 / .10 |
| BR-EDGE e0/2 – BR-CORE-2 e0/0 | 10.2.255.12/30 | .13 / .14 |
| BR-CORE-2 e0/1 – DSW-1 e1/2 | 10.2.255.16/30 | .17 / .18 |
| BR-CORE-2 e0/2 – DSW-2 e1/2 | 10.2.255.20/30 | .21 / .22 |
| BR-CORE e0/3 – BR-CORE-2 e0/3 | 10.2.255.24/30 | .25 / .26 |
| ISP-1 e0/0 – BR-EDGE e0/0 | 198.51.100.0/30 | .1 / .2 |
| ISP-2 e0/0 – BR-EDGE e0/3 | 192.0.2.0/30 | .1 / .2 |
| ISP-1 e0/1 – ISP-2 e0/1 («интернет») | 203.0.113.248/30 | .249 / .250 |

Router-id OSPF: BR-CORE 10.2.254.1, DSW-1 .2, DSW-2 .3, BR-CORE-2 .4, BR-EDGE .254.
«Интернет»: 8.8.8.8 (lo0 ISP-1), 1.1.1.1 (lo0 ISP-2). DHCP — SRV-DHCP 10.2.50.10 (relay с SVI), пулы для VLAN 10/20/30/40/60/70.

## Заметки по консоли

- `traceroute ... source` на IOL L2 не поддерживается — для проверки связности с SVI использовать `ping 8.8.8.8 source Vlan10 repeat 10` (вывод читается со скриншота).
- `list_running_labs` возвращает «No labs are currently running», хотя ноды работают — ориентироваться на `get_node_status`.
- Новые IOL L3 (образ L3-...) при первом старте висят в initial configuration dialog и молча съедают команды — сначала `read_console`, ответить `no`. IOL L2 стартуют сразу в `Switch>`.
- Генерация файлов команд в zsh: `set -- $var` не разбивает строку на слова — проверять сгенерированные файлы.

- **Консоль IOL через ~10 мин простоя выходит в user-режим (`>`): `configure terminal` молча не проходит, и вся пачка команд теряется.** Всегда начинать блок с `""`, `enable`; после изменений проверять `show run | include ...`.
- Вывод VPCS: пустые строки после команды иногда обрывают `ping`/`ip dhcp`; при переподключении консоли экран очищается — надёжнее проверять по IOL (счётчики ACL, NAT, `show ip dhcp binding`, ping с IOL).
- VPCS после долгой работы иногда пишет `pipe2 failed` в консоль и перестаёт работать — помогает `stop_node`/`start_node` + заново IP.
- IOL L2 с HSRP/VRRP: `ip default-gateway` игнорируется (ip routing по умолчанию) — для управления ASW нужен `ip route 0.0.0.0 0.0.0.0 <VIP>`.
- Линки IOL считаются half-duplex (Shr) → для быстрого RSTP/MSTP нужен `spanning-tree link-type point-to-point` (на HQ-DSW применение повалило ноды — см. проблему №2).
- `stand/pnetlab_export-20261011-134345.zip` устарел (до p2p и последних правок); актуальна сама лаба в PNETLab.

## Журнал для отчёта (сырые факты, оформить на шаге 12)

- 7a: L2 ГО — в отчёте уже есть (раздел 3.2).
- 7b: HQ-EDGE — 2 соседа OSPF, ping 8.8.8.8 ок (`outputs/HQ-EDGE-7b-check.txt`). HQ-DSW-1: VRRP master 10/50/55, backup 20/60/70/99; OSPF 3 соседа (ядра + DSW-2 через Vlan99); default ECMP через оба ядра; ping 8.8.8.8 source Vlan10 5/5 (`outputs/HQ-DSW-1-7b-check.txt`).
- 7c: DHCP выдал ADMIN 10.1.10.10, STAFF 10.1.20.10, CAM 10.1.70.10; NTP master stratum 3; STAFF → 8.8.8.8 и 203.0.113.1 ок; DMZ: SRV-WEB → интернет через 203.0.113.2, SRV-WEB → SRV-INT заблокирован (DMZ-IN deny 3 matches); static NAT 80/443 → SRV-WEB, 25 → SRV-MAIL.
- 7c траблшутинг: (1) `save` сразу после `ip dhcp` на VPCS обрывал DHCP — отправлять отдельно; (2) на HQ-INFRA `no ip domain-lookup` → DNS-сервер IOS не отвечает, вернул `ip domain-lookup`.
- ОТКРЫТО: PC-HQ-GUEST (VLAN 60) не получает DHCP — OFFER есть, REQUEST от VPCS нет; L2 в порядке (порт VLAN 60, MAC изучен, FWD). DNS по имени с VPCS не проверен (вывод не читается).
- 8: туннели подняты, ISAKMP QM_IDLE ×3, ESP encaps/decaps в обе стороны, OSPF FULL по Tunnel0/1; маршруты 10.2/16 на HQ-EDGE через Tunnel0 (`outputs/BR-EDGE-vpn-check.txt`, `HQ-EDGE-routes-branch.txt`); DSW-1 филиала → HQ-INFRA и PC-HQ-STAFF 100% (`outputs/DSW-1-ping-hq.txt`). NAT на BR-EDGE не трогали: route-map матчит egress e0/0/e0/3, туннельный трафик уходит в Tunnel и не NAT-ится; на HQ-EDGE deny 10/8→10/8 в NAT-HQ.
- 2026-10-11 перезагрузка хоста: лаба остановилась; пользователь включил startup-cfg (Set Nodes Startup-cfg To Exported) у 1–17; после start_all IOL из NVRAM целы (вкл. VPN), VPCS — без адресов, выданы заново. Потери пинга филиал→хосты ГО больше не воспроизводятся. PC-HQ-GUEST DHCP получил.
- Безопасность доступа филиала (2026-10-11): Port Security (sticky, restrict; польз. max 2, серверы/камера max 1), DHCP Snooping (trust аплинки + SRV-DHCP порт, `no ip dhcp snooping information option`), DAI (validate src-mac dst-mac ip, trust аплинки, статические `ip source binding` для SRV-FILE/SRV-DHCP), неиспользуемые порты → VLAN 999 shutdown. Привязки: 7 динамических после `ip dhcp` на VPCS. DAI проверен: Forwarded 15 / DHCP Permits 1 на VLAN 10.
- **IPSG на IOL L2 не работает** для DHCP-привязок: с `ip verify source` PC-ADMIN не отвечает (таблица IPSG верная), без — 3/3. Снят со всех портов; IP–MAC обеспечивают DAI + Port Security. Для отчёта — как ограничение эмулятора.
- Консоль: глобальные команды после `interface range` в одном блоке теряются — отправлять глобальные отдельным блоком.
- Безопасность доступа ГО (2026-10-11): HQ-ASW-1/2 — Port Security, DHCP Snooping (trust Po1-2 + порт HQ-INFRA), DAI (trust Po1-2; static bindings SRV-INT 0050.7966.6832, HQ-INFRA aabb.cc00.1400), без IPSG. `commands/HQ-ASW-*-security.txt`. Проверено: ADMIN 10.1.10.10, INFRA, CAM отвечают; DAI drops 0.
- ПРОБЛЕМА ПЛАТФОРМЫ: PC-HQ-STAFF выдал `pipe2 failed` и перестал отвечать; после stop/start не стартует (status 0). PC-HQ-GUEST после рестарта получает OFFER, но не ACK (и без snooping). Линк HQ-DSW-1 e1/2 моргнул без причины. Похоже на нехватку ресурсов (fd/RAM) на сервере PNETLab при 35 нодах — спросить пользователя про ресурсы сервера.
- 2026-10-11: VM PNETLab на Windows-хосте (Tailscale 100.100.57.19, узел `pnetlab`), RAM увеличена до 20 ГБ после `pipe2 failed`/падения VPCS. После рестарта VM Guacamole поднимается ~2 мин (до этого read_console → 1008 policy violation).
- **VPCS меняют MAC при пересоздании pod** (было 0050.7966.6843 → стало .680a): sticky Port Security и `ip source binding` с MAC ломаются (и сломаются при импорте у других). Переделано переносимо: Port Security без sticky (лимит/restrict остались), статические серверы в DAI — `arp access-list DAI-STATIC permit ip host X mac any` + `ip arp inspection filter DAI-STATIC vlan N` (`commands/*-portable.txt`). Старые secure-MAC снимаются только shut/no shut порта (`clear port-security all` не помог). Проверено: все хосты обеих площадок отвечают, SRV-FILE/SRV-INT/SRV-DHCP/HQ-INFRA через ARP ACL.
- ACL ГО (`commands/HQ-DSW-acl.txt`, на обоих HQ-DSW): Vlan60 in HQ-GUEST-IN (DHCP/DNS к INFRA, deny RFC1918, permit any), Vlan70 in HQ-CCTV-IN (DHCP, VRRP, NTP, → серверы VLAN50, echo-reply; deny any), Vlan99 out HQ-MGMT-OUT (только ADMIN ГО/филиала и сам MGMT). Счётчики: гость→SRV-INT deny, гость→8.8.8.8 permit, CAM→интернет deny, STAFF→10.1.99.11 deny (`outputs/HQ-DSW-2-acl-check.txt`).
- IPv6 DMZ (`commands/HQ-EDGE-ipv6.txt`): `ipv6 unicast-routing`, e0/3 fd00:1:100::1/64 (RA по умолчанию) → SLAAC на VPCS (`ip auto`). SRV-WEB получил fd00:1:100:0:2050:79ff:fe66:681d/64, ping6 до шлюза ок (`outputs/SRV-WEB-ipv6.txt`). VPCS `ip auto` после каждого старта.
- SSH-управление филиалом из ГО (`commands/BR-SSH-mgmt.txt`): на DSW-1/2 и ASW-1/2/3 филиала — domain branch.local, user `netadmin`/`BKS1-admin` priv 15, RSA 2048, SSH v2, VTY только ssh + access-class VTY-MGMT (ADMIN ГО 10.1.10.0/27 и ADMIN филиала 10.2.10.0/27); MGMT-OUT на DSW филиала + `15 permit ip 10.1.10.0 0.0.0.31 any`; на HQ-DSW-1 `ip ssh source-interface Vlan10`. Проверено: HQ-DSW-1 → `ssh -l netadmin 10.2.99.11` → ASW-1, `show users` netadmin from 10.1.10.2 (`outputs/HQ-DSW-1-ssh-branch.txt`).
- **Найдена старая ошибка**: на IOL L2 `ip routing` включён по умолчанию → `ip default-gateway` на ASW игнорируется, управление ASW из других подсетей не работало с самого начала. Исправлено `ip route 0.0.0.0 0.0.0.0 <VIP VLAN99>` на всех 5 ASW (`commands/ASW-mgmt-default-route.txt`).
- Пункты «следующие 4» сделаны 2026-10-11: безопасность доступа (обе площадки), ACL ГО, IPv6 DMZ, SSH-управление. Осталось: проверки п. 2.4, бумажная часть, отчёт.
- Прогон проверок для сдачи (`demo-checks.md`, `outputs/demo-*`): интернет (NAT-трансляции со всех нужных, CAM1/CAM-HQ нет), traceroute (1 хоп в VLAN, через шлюз между VLAN, 7 хопов ГО→филиал через Tunnel0).
- **MSTP-переключение было ~30 с**: IOL считает линки shared (Shr), RSTP proposal/agreement не работает → `spanning-tree link-type point-to-point` на всех межкоммутаторных каналах обеих площадок (`commands/STP-link-type-p2p.txt`); после — быстрое переключение.
- **ОТКРЫТО (2026-10-11, критично для сдачи): хост↔хост между VLAN филиала не работает, если транзитный пакет уходит в VLAN, где маршрутизирующий DSW — HSRP Active.** Не работает: ADMIN(10, act DSW-1)↔ACC(30, act DSW-1), SALES(40, act DSW-2)↔SRV-FILE .42 (20, act DSW-2) — вариант 5! Работает: ADMIN↔SALES, ADMIN→.42, DEV1→ADMIN (запрос уходит в VLAN, где DSW standby). Пинги с самих DSW из любой SVI — ок. ACL ни при чём (снятие DEV-IN не помогло), DAI drops 0, CEF/ARP/MAC на DSW верные; счётчики: запрос проходит входной ACL (SALES-IN 20 растёт), ответа нет. Гипотезы: особенность IOL L2 при маршрутизации в HSRP-active SVI (src MAC/vMAC), проверить `standby use-bia`, `no ip redirects`, сравнить с ГО (VRRP) — там HQ-INFRA/STAFF/… проверить хост↔хост в VLAN одного мастера.
- Прогон проверок: DMZ ок (`outputs/demo-5-dmz.txt`), вариант 5 «SALES→DEV1 запрещено» ок, «SALES→.42 разрешено» — НЕ работает (см. выше).
