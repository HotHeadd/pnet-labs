# ЛР1 БКС — проектирование КВС филиала и головного офиса

Лаба в PNETLab: `/BKS labs/BKS1.unl`, 37 нод (филиал id 1–19, ГО id 20–37) + облако NetManagement (pnet0); у IOL `config: 1`,
у pfSense (36, 37) startup-config не работает (export_config → ошибка 16) — их конфиг в `configs/HQ-FW-*.xml`.
PNETLab — VM на Windows-хосте (20 ГБ RAM), доступ через Tailscale `100.100.57.19` (узел `pnetlab`).
Вариант доп. задания (п. 1.3.3): **№5** — отдел продаж (VLAN 40) имеет доступ в VLAN разработки только к файловому серверу 10.2.20.42.
Требования преподавателя: нужные хосты выходят в интернет, изоляция VLAN показана проверками; второй провайдер и дублирование ядра.
На сдаче проверяют: traceroute между VLAN (в одном и разных), ping через MSTP (отказ аплинка), OSPF, DMZ (WAN есть, LAN нет), IP–MAC–порт. Сценарий — `demo-checks.md` (с 2026-10-17 сокращён по просьбе пользователя до 5 пунктов: trace, MSTP, OSPF, DMZ, IP–MAC–порт; старые «п.1–9» ниже — прежняя нумерация).
Условие — `preamble/Лабораторная работа №1 (БКС).pdf` (25 стр.; стр. 23 — мусор «Где: В раздел 2.3…»). МЭ в ГО: «интеграция»
в ЛР1 (сделано, прозрачный мост), разработка политик — следующие ЛР. Из доп. задач 1.3.3 обязательна только №5.
Проект ГО и порты — `hq-plan.md`. Для получателей стенда — `stand/README.md`.
**Продолжение — `../lab2`** (ЛР2: Ubuntu-МЭ вместо pfSense на DMZ, отдельный стенд с нуля `/BKS labs/BKS2.unl`; этот стенд не трогать).

## Состояние на 2026-10-16 (вечер): стенд готов, МЭ интегрированы

Добавлено вечером: клиенты NTP на всех IOL (+ строка NTP в MGMT-OUT/HQ-MGMT-OUT), проверка DNS (HQ-DSW-1 — клиент DNS),
МЭ HQ-FW-1/2 (pfSense, прозрачный мост EDGE–ядро и EDGE–DMZ, фильтрация выключена). Полный регресс п.1–9 —
`outputs/regress-fw-20261016.txt` ✅ (вкл. отказ HQ-FW-1).
Все проверки `demo-checks.md` пройдены (п.1–9 + п. 2.4), ГО после доработки snooping стабилен.
Сохранено: `write memory` + `export_config` всех IOL; выгрузка — `stand/pnetlab_export-20261016-193000.zip`
(единственная актуальная, старые удалены); `configs/*.txt` извлечены из неё (`../../tools/extract-configs.py`).
`commands/` приведены к итоговому состоянию (sticky, ip source binding, IPSG, *-portable — убраны/слиты).
Временных изменений на стенде нет.

**Запуск после старта лабы:** IOL поднимаются сами. VPCS — вручную: SRV-FILE `ip 10.2.20.42/24 10.2.20.1`,
SRV-INT `ip 10.1.50.10/26 10.1.50.1`, SRV-WEB `ip 10.1.100.10/28 10.1.100.1` + `ip auto`, SRV-MAIL `ip 10.1.100.11/28 10.1.100.1` + `ip auto`,
остальные `ip dhcp` (каждую отдельным `send_console`; ГО — после схождения VRRP, ~2 мин; проверять `show ip dhcp binding` на SRV-DHCP/HQ-INFRA
и `show ip dhcp snooping binding` на ASW).
После старта проверить `get_lab`, что все ноды status 2: **DSW-1 падал через ~2 мин после start_all** (поднять `start_node`).
Здоровье IOL: `show memory statistics | include Proc` — норма ~55 МБ used; сотни МБ = был шторм, ноду перезапустить (stop/start).

**2026-10-17: отчёт формализован** (п.11 и п.12): расчёт, оборудование, все разделы, заключение; в тексте только
описания и короткие цитаты команд, листинги настройки — приложения А–В (`fragments/` — фрагменты из итоговых конфигов
для базовой настройки филиала), конфиги — Г, протоколы — Д.
Логические схемы (рис. 2, 3) — `logic.typ`: разметка уровней поверх `img/topology.png` (координаты в px картинки 2144×963;
при новом скриншоте топологии координаты пересчитать). Стенд не трогать без нужды.
2026-10-17: комментарии (`! …`, `# …`, хвосты `  ! …`) вырезает из листингов функция `strip-comments` в `main.typ`,
файлы `commands/`/`fragments/`/`outputs/` не трогаем; пояснения из комментариев перенесены в подписи. Исправлена арифметика табл. 4.
Пользователь убрал из приложений сценарии проверок и конфигурации МЭ; теперь приложения такие: А — филиал, Б — ГО, В — итоговые конфиги. Преподаватель — Басыня Е. А.
Следы рабочего процесса в отчёт не включать (пользователь, 2026-10-17): убраны «по требованию преподавателя»,
раздел про неполную настройку HQ-ASW-2 (+ листинг fix), рассказ про забытую сеть OSPF на BR-EDGE, пояснения «(...)» в выводах.
Базовая настройка филиала вводилась из Claude Desktop, файлов команд нет — в приложении А вместо неё фрагменты итоговых конфигов (`fragments/`).

## Решённые проблемы (2026-10-16)

1. **Хост↔хост между VLAN одного DSW — причина: CEF на IOL L2.** Транзитный кадр, который DSW (CEF) отправляет
   в физический транк к ASW, до хоста не доходит (adjacency верная, счётчик растёт, на хосте 0 echo). Через Po1
   к соседнему DSW (случай «standby») — доходит; собственные пакеты DSW (process switching) — доходят.
   В ГО тот же образ: транзит не создавал ARP (glean) — работал только при уже известном ARP.
   **Решение: `no ip cef` на DSW-1/2 и HQ-DSW-1/2** (`commands/DSW-no-cef.txt`). Вариант 5 работает: SALES→.42 4/4, SALES→DEV1 deny.
2. **link-type p2p на HQ-DSW** — применён по одному Po (Po1/Po11/Po12, Po1/Po21/Po22), ноды не падают. Пачка
   `interface range` по нескольким Po, видимо, роняла IOL.
5. **DHCP-шторм в ГО** (в отчёт НЕ включать — решение пользователя): snooping IOL L2 шлёт DHCP мимо STP-блокировки Po;
   петля, если один VLAN снупят оба HQ-ASW. Решение: HQ-ASW-1 — 10,20,60; HQ-ASW-2 — 50,55,70 (`commands/HQ-ASW-snooping-vlans.txt`).
   Плюс явный приоритет MST0 на HQ-DSW (`commands/HQ-DSW-mst0-priority.txt`). В отчёте — раздел «Доработки ГО» без причины.
3. **HQ-ASW-2 без trust/Port Security/default route** (ввод команд в прошлый раз частично потерялся) → DAI резал ARP
   шлюзов в VLAN 55, хосты ГО без DHCP. Исправлено (`commands/HQ-ASW-2-security-fix.txt`); на HQ-ASW-1 добавлен default route.
4. `demo-checks.md` п.3 (MSTP обе площадки), п.6, п.7 — пройдены (`outputs/ASW-1-mstp-fail.txt`, `HQ-ASW-1-mstp-fail.txt`,
   `demo-6-isolation.txt`, `demo-7-ip-mac-port.txt`); п.2.4 — `HQ-EDGE-ipv6-route.txt`, `DSW-1-ping-hq-source.txt`, `BR-EDGE-traceroute-hq-source.txt`.

## План (статус)

1. [x] Каркас отчёта (тема, цель, задание, структура, таблицы адресации) — `main.typ`.
2. [x] Резервирование ядра филиала (BR-CORE-2, ECMP). 3. [x] Тесты отказа провайдера и ядра.
4. [x] Безопасность доступа обеих площадок: Port Security (без sticky), DHCP Snooping, DAI (+ ARP ACL DAI-STATIC для статических серверов), неисп. порты VLAN 999; IPSG не используется (ломает DHCP-хостов на IOL).
5. [~] Листинги сделанного в Desktop — итоговые конфиги всех IOL в приложении А `main.typ` (сырые); при формализации нарезать фрагменты по темам.
6. [x] Проект ГО. 7. [x] ГО: ноды, L2, L3 (OSPF, VRRP, NAT), сервисы, DMZ, ACL ГО. 8. [x] GRE over IPsec ×2 + OSPF; SSH-управление филиалом из ГО.
9. [x] IPv6 DMZ + SLAAC. 
10. [x] Верификация п. 2.4 / сценарий сдачи (2026-10-16).
11. [ ] Бумажная часть: логическая схема, расчёт пропускной способности и PoE, выбор оборудования.
12. [ ] Отчёт: формализовать сырые блоки (`// СЫРОЕ` в `main.typ`) + журнал ниже, схемы, заключение, чистка `#todo`.
    Сборка на Windows: шаблон не установлен — `typst compile --package-path <dir с local/mephi-lab/0.1.0> --font-path ../../mephi-labs/fonts main.typ`.

## Порядок работы

Все команды, введённые на устройствах, — в `commands/<узел>-<что>.txt`, выводы проверок — `outputs/`, факты — в журнал ниже.
С 2026-10-16: новые листинги сразу вставлять в `main.typ` сырыми (см. корневой CLAUDE.md), формализация — шаг 12 в конце. Ревью пользователем — по крупным пунктам.

## Требования методички (чек-лист)

- Филиал: 3 уровня; VLAN разработка/бухгалтерия/гости/CCTV/MGMT; 10.2.0.0/16 VLSM — ✅.
- 1.2.2: расчёт пропускной способности по уровням, PoE+ бюджет, конкретные модели — ❌ (бумажная часть).
- Доступ: Port Security, DAI, IP-MAC binding, ACL, VLAN, MSTP, LACP — ✅ (IP-MAC = DAI+PS; IPSG на IOL не работает — описать как ограничение).
- Распределение/ядро: OSPF, ACL, HSRP — ✅; ядро — дублирование (BR-CORE-2) ✅; в ядре без ACL/NAT ✅.
- 1.3.3 вариант 5 — ✅ (после `no ip cef` на DSW): SALES→.42 разрешено, SALES→DEV запрещено. Второй провайдер — требование преподавателя, ✅.
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

ГО (id 20–37): 36/37 HQ-FW-1/2 (pfSense, консоль VNC, управление https://192.168.226.20/.21 admin/pfsense), 20 HQ-EDGE (L3), 21/22 HQ-CORE-1/2, 23/24 HQ-DSW-1/2, 25/26 HQ-ASW-1/2, 27 HQ-DMZ (L2), 28 HQ-INFRA (L3), 29 SRV-WEB, 30 SRV-MAIL, 31 SRV-INT, 32 PC-HQ-ADMIN, 33 PC-HQ-STAFF, 34 PC-HQ-GUEST, 35 CAM-HQ (VPCS). Порты — `hq-plan.md`. Новые ноды созданы с `config: 1`.

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
- Линки IOL считаются half-duplex (Shr) → для быстрого RSTP/MSTP нужен `spanning-tree link-type point-to-point`; на HQ-DSW — по одному Po.
- **IOL L2 + маршрутизация между SVI: держать `no ip cef`** (CEF теряет транзит в физический транк / не делает glean ARP).
- Ход пинга VPCS во время отказа через MCP не снять (экран очищается) — время переключения STP брать из `debug spanning-tree events` + `logging buffered`.
- Сбой стенда после рестарта может быть из-за недоприменённых раньше команд: сверять `get_node_config` с `commands/`.
- `stand/pnetlab_export-20261011-134345.zip` устарел; актуальная выгрузка — `stand/pnetlab_export-20261016-131734.zip`.

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
- 2026-10-16: см. «Решённые проблемы» выше. Сырые листинги в `main.typ` — раздел «Верификация и траблшутинг» и приложение А.
- 2026-10-16 ~12:40, финальный прогон (`outputs/final-check-20261016.txt`): филиал целиком ок (интернет, CAM1 нет, вариант 5, trace 1/2 хопа, HSRP, OSPF, ECMP, MSTP, snooping/port-security), VPN/OSPF через оба туннеля, IP SLA Up, DMZ ок, ГО→филиал trace 7 хопов, HQ-STAFF интернет, HQ-GUEST→SRV-INT запрещено.
  **ОТКРЫТО: HQ-ASW-2 завис** (`%SYS-2-MALLOCFAIL`, консоль не отвечает) → VLAN 50/55/70 ГО недоступны (SRV-INT, HQ-INFRA, CAM-HQ). Вероятная причина — DHCP-шторм от VPCS CAM-HQ (HQ-CCTV-IN строка 10: 76078 matches, на VPCS «queue is full»/«pipe2 failed»); `ip dhcp snooping limit rate 15` на e1/2 не сработал (≈10 pps, ниже порога). Нужен перезапуск ноды HQ-ASW-2 (+ CAM-HQ, `ip dhcp`); MCP stop_node запрещён правами — делать из веб-морды. Startup-config HQ-ASW-2 полный (сверен `get_node_config`).
  13:04 HQ-ASW-2 и CAM-HQ перезапущены (по разрешению пользователя): Po1/Po2 SU, SRV-INT/HQ-INFRA снова 5/5 с HQ-DSW-1 и с DSW-1 филиала (source Vlan10). CAM-HQ: после старта snooping-привязки нет → DAI режет ARP; `clear ip` + `ip dhcp` → привязка есть, но шлюз всё равно «not reachable».
  13:08:06 **завис HQ-ASW-1** (HQ-DSW-1/2: Po11/Po21 SD, «LACP not enabled on remote»). Перед этим всплеск: HQ-CCTV-IN bootps 76k→227k, Po22 253k пакетов за 4 мин, HQ-ASW-2 e1/2 (CAM-HQ) **output** 80 949 при input 26, EXCESSCOLL; память HQ-ASW-2 932/956 МБ. Поток шёл В порт камеры сверху, не от неё. 13:08:41 на HQ-ASW-2 `interface e1/2 shutdown` (не сохранено!). После — счётчики не растут. HQ-ASW-1 ждёт перезапуска (MCP stop_node отклонён правами). Причина шторма не установлена: подозрение на петлю/шторм в VLAN 70 ГО при перестроении (оба HQ-DSW — relay `ip helper` в Vlan70?).
  **РЕШЕНО ~14:30: причина — DHCP snooping на обоих HQ-ASW** (`outputs/HQ-dhcp-storm.txt`). Шторм запускал каждый `ip dhcp` на VPCS ГО, перезагрузки ни при чём. Один DORA при snooping на обоих HQ-ASW → 22 396 DISCOVER на HQ-INFRA (итого 249k); snooping только на HQ-ASW-1 → 1–4 DISCOVER на клиента; филиал (физ. аплинки) — 2. Гипотеза механизма: IOL L2 snooping шлёт перехваченные DHCP через CPU во все trusted-Po без учёта STP-блокировки → кольцо ASW–DSW–DSW–ASW. Утечка памяти от шторма: HQ-DSW-2 956/956 МБ, HQ-DSW-1 628, HQ-ASW-1 216 (норма ~55). Перезапущены HQ-ASW-1/2, HQ-DSW-1/2.
  Решение (`commands/HQ-ASW-2-no-snooping.txt`, write mem + export_config): на HQ-ASW-2 `no ip dhcp snooping`, `no ip arp inspection vlan 70`; DAI 50/55 по DAI-STATIC остался; HQ-ASW-1 — snooping+DAI как было. Проверено: ADMIN/STAFF/GUEST ГО — привязки, интернет, HQ-INFRA; CAM-HQ → SRV-INT.
  **Не делать на HQ-ASW-2 `ip dhcp snooping`** (вернёт шторм). HQ-ASW-1 после шторма держит 216 МБ (не растёт) — при следующем старте лабы будет чисто.
- 2026-10-16 ~15:15, опыт по просьбе пользователя: `ip dhcp snooping` на HQ-ASW-2 + один `ip dhcp` → 20 856 DISCOVER; на HQ-ASW-2 через **Altn BLK** Po1 (MST2) ушло +62 878 пакетов (23 162 → 86 040), на HQ-ASW-1 через BLK Po1 — +13. Доказано: snooping IOL L2 шлёт DHCP мимо STP-блокировки Po — баг эмулятора, не конфиг. Откат: snooping на HQ-ASW-2 снят, все 4 HQ-коммутатора перезапущены (утечка памяти), хосты ГО — `ip dhcp` (2 DISCOVER на клиента), связность ок.
  Новая настройка: `spanning-tree mst 0 priority` 24576 (HQ-DSW-1) / 28672 (HQ-DSW-2) — корень CIST явно HQ-DSW-1 (`commands/HQ-DSW-mst0-priority.txt`). write mem + export_config.
  **Пользователь: инцидент со штормом и эксперименты в отчёт НЕ включать**; в отчёте только итоговые настройки (раздел «Доработки ГО» в main.typ). `outputs/HQ-dhcp-storm.txt` — только для себя.
- 2026-10-16 ~15:30 **ИТОГ по snooping ГО**: разнесены VLAN — HQ-ASW-1 snooping+DAI 10,20,60; HQ-ASW-2 snooping+DAI 50,55,70 (DAI-STATIC для 50/55), `ip dhcp snooping` на HQ-ASW-2 снова включён. Тесты: STAFF, CAM-HQ, ADMIN+GUEST — по 2 DISCOVER на клиента, привязки на обоих HQ-ASW, DAI VLAN 70 пропускает камеру, память ~55 МБ на всех HQ. Вывод: петля, когда один VLAN снупят оба HQ-ASW. `commands/HQ-ASW-snooping-vlans.txt` (старый HQ-ASW-2-no-snooping удалён). write mem + export_config, startup сверен. **Не добавлять один VLAN в snooping на оба HQ-ASW.**
- 2026-10-16 вечер, **NTP/DNS/МЭ** (в отчёт — сырые разделы «Сервисы ГО», «Интеграция МЭ», «Регресс»):
  NTP-клиентов не было ни на одном IOL (в hq-plan были запланированы) — добавлены, `commands/NTP-clients.txt`.
  DNS: VPCS `ping <имя>` не читается со скриншота — проверено с HQ-DSW-1 (`ip name-server`, `transport preferred none`).
  МЭ: сначала планировался CARP-кластер (HQ-FW-SW, VLAN 102 на ядрах) — откатан, пользователь: «МЭ скорее для вида».
  Итог: прозрачный мост, `disablefilter`; отказ МЭ → OSPF через второе ядро (~40 с, dead-интервал). DMZ — только через HQ-FW-2.
  **pfSense на этом PNETLab:** MCP `add_node` создаёт qemu без опций шаблона (не стартует, оставляет процессы-сироты qemu —
  убивать на сервере) → ноды создавать в веб-морде; консоль только VNC (telnet пустой); через VNC теряется Shift
  (`$ ( ) | _` не набрать) и каждая строка шлёт лишний Enter → в меню отвечать по одному полю с проверкой;
  настройка — через веб-интерфейс по сети управления (облако pnet0 = VMnet8 192.168.226.0/24), скрипты
  `tools/pfsense-gui.py` (backup/restore config.xml, обходит прокси) и `tools/pfsense-config.py` (мосты, MGMT, фильтр off).
  Облако подключать линками из веб-морды (MCP connect_nodes к облаку не умеет — создаёт bridge-сеть).
  **План на ЛР с МЭ** (согласовано с пользователем): два провода HQ-EDGE–HQ-FW-2 — следствие прозрачного режима
  (шлюз/ACL DMZ на HQ-EDGE e0/3). При настройке МЭ: DMZ — маршрутизируемый интерфейс HQ-FW-2 (10.1.100.1, fd00:1:100::1, RA),
  правила DMZ — на pfSense вместо DMZ-IN, транзит EDGE–CORE-2 до /29 (адрес МЭ), маршруты в DMZ на HQ-EDGE через МЭ,
  e0/3 HQ-EDGE и линк к HQ-FW-2 e2 убрать (как на рис. 2 методички).
