#import "@local/mephi-lab:0.1.0": lab-report, appendixes, device-config, cli-output

#show: lab-report.with(
  lab-number: 1,
  topic: "Проектирование корпоративной вычислительной сети филиала и головного офиса",
  discipline: "Безопасность компьютерных сетей",
  student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."),
  group: "Б23-505",
)

#show table: set par(justify: false)

// Команды, введённые на устройстве (файлы в commands/<узел>-<что>.txt).
#let commands(name, what, body) = figure(
  {
    show raw: set text(size: 9pt)
    raw(body.trim(), block: true)
  },
  caption: [Команды #what на #name],
  kind: raw,
)

// Фрагмент консоли с несколькими командами (приглашения уже в тексте).
#let console(name, what, body) = figure(
  {
    show raw: set text(size: 9pt)
    raw(body.trim(), block: true)
  },
  caption: [#what на #name],
  kind: raw,
)

// Пометка о недописанном разделе — перед сдачей их не должно остаться.
#let todo(body) = text(fill: red)[[TODO: #body]]

= Цель работы

Спроектировать корпоративную вычислительную сеть (КВС) предприятия с распределённой
структурой — филиала и головного офиса, — обосновать архитектурные решения, подобрать
сетевое оборудование, разработать схемы IP-адресации и VLAN, реализовать меры защиты
информации и разграничения доступа, а также проверить предлагаемые решения на рабочем
прототипе сети в среде эмуляции.

= Задание

Проектирование КВС филиала (расчётное число рабочих станций — 100):

+ спроектировать иерархическую модель сети с уровнями доступа, распределения и ядра;
+ разработать схему IPv4-адресации из блока 10.2.0.0/16 с применением VLSM и разбиение на
  VLAN (отделы разработки и бухгалтерии, гостевой доступ, видеонаблюдение, управление);
+ рассчитать пропускную способность оборудования по уровням иерархии и бюджет PoE,
  подобрать модели коммутаторов, точек доступа и иного оборудования;
+ реализовать на коммутаторах доступа функции безопасности: Port Security, DHCP Snooping,
  Dynamic ARP Inspection, привязку IP–MAC, ACL, VLAN, MSTP, агрегирование каналов (LACP);
+ на уровнях распределения и ядра реализовать маршрутизацию OSPF, межсегментную фильтрацию
  ACL и резервирование шлюза по умолчанию (HSRP), в ядре — резервирование оборудования;
+ развернуть прототип сети филиала в среде эмуляции и проверить работоспособность всех
  функций;
+ дополнительное задание, вариант 5: сотрудникам отдела продаж разрешить доступ во VLAN
  отдела разработки только к файловому серверу 10.2.20.42, остальные узлы этих VLAN
  взаимодействовать не должны;
+ по требованию преподавателя: подключить филиал ко второму провайдеру с автоматическим
  переключением и продублировать коммутатор ядра.

Проектирование КВС головного офиса:

+ спроектировать отказоустойчивую иерархическую сеть с сегментами DMZ, управления,
  внутренних серверов и пользовательскими сегментами по отделам, разработать IP-адресацию
  и разбиение на VLAN;
+ обеспечить канал с публичным IP-адресом и трансляцию адресов (NAT);
+ организовать Site-to-Site VPN (GRE over IPsec) между филиалом и головным офисом с
  динамической маршрутизацией OSPF поверх туннеля и централизованное управление
  оборудованием филиала;
+ реализовать Dual-Stack (IPv4/IPv6) в сегменте DMZ с автоконфигурацией SLAAC;
+ развернуть сервисы DHCP, DNS и NTP, настроить функции безопасности, аналогичные филиалу;
+ подобрать сетевое оборудование для всей иерархии сети;
+ выполнить верификацию: проверку связности с указанием source-интерфейса, анализ таблиц
  маршрутизации, состояния MSTP, туннелей и трансляций NAT.

= Ход работы

== Проектирование КВС филиала

=== Логическая структура сети

#todo[описание уровней доступа, распределения и ядра; роли устройств]

Схема сети филиала приведена на рисунке @fig-topology.

#figure(
  rect(width: 100%, height: 5cm)[Здесь будет #raw("img/topology.png")],
  // image("img/topology.png", width: 100%),
  caption: [Топология сети филиала],
  kind: image,
) <fig-topology>

=== IP-адресация и VLAN

Для филиала выделен блок 10.2.0.0/16. Размеры подсетей пользовательских VLAN выбраны по
числу узлов в сегменте (VLSM), адрес .1 в каждой подсети — виртуальный шлюз HSRP, .2 и .3 —
адреса коммутаторов распределения DSW-1 и DSW-2. Распределение VLAN приведено в
таблице @tbl-vlan, адресация транзитных каналов — в таблице @tbl-links.

#figure(
  table(
    columns: 5,
    align: (center, left, left, left, center),
    table.header[*VLAN*][*Назначение*][*Подсеть*][*Шлюз / DSW-1 / DSW-2*][*HSRP active*],
    [10], [Администраторы (ADMIN)], [10.2.10.0/27], [.1 / .2 / .3], [DSW-1],
    [20], [Отдел разработки (DEV)], [10.2.20.0/24], [.1 / .2 / .3], [DSW-2],
    [30], [Бухгалтерия (ACC)], [10.2.30.0/26], [.1 / .2 / .3], [DSW-1],
    [40], [Отдел продаж (SALES)], [10.2.40.0/26], [.1 / .2 / .3], [DSW-2],
    [50], [Серверы (SERVERS)], [10.2.50.0/25], [.1 / .2 / .3], [DSW-1],
    [60], [Гостевой доступ (GUEST)], [10.2.60.0/24], [.1 / .2 / .3], [DSW-2],
    [70], [Видеонаблюдение (CCTV)], [10.2.70.0/26], [.1 / .2 / .3], [DSW-1],
    [99], [Управление (MGMT)], [10.2.99.0/28], [.1 / .2 / .3; ASW-1/2/3 — .11/.12/.13], [DSW-2],
    [999], [BLACKHOLE (native, неиспользуемые порты)], [—], [—], [—],
  ),
  caption: [Распределение VLAN и адресация филиала],
) <tbl-vlan>

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    table.header[*Канал*][*Подсеть*][*Адреса*],
    [BR-EDGE e0/1 — BR-CORE e0/0], [10.2.255.0/30], [.1 / .2],
    [BR-CORE e0/1 — DSW-1 e0/0], [10.2.255.4/30], [.5 / .6],
    [BR-CORE e0/2 — DSW-2 e0/0], [10.2.255.8/30], [.9 / .10],
    [BR-EDGE e0/2 — BR-CORE-2 e0/0], [10.2.255.12/30], [.13 / .14],
    [BR-CORE-2 e0/1 — DSW-1 e1/2], [10.2.255.16/30], [.17 / .18],
    [BR-CORE-2 e0/2 — DSW-2 e1/2], [10.2.255.20/30], [.21 / .22],
    [BR-CORE e0/3 — BR-CORE-2 e0/3], [10.2.255.24/30], [.25 / .26],
    [ISP-1 e0/0 — BR-EDGE e0/0], [198.51.100.0/30], [.1 / .2],
    [ISP-2 e0/0 — BR-EDGE e0/3], [192.0.2.0/30], [.1 / .2],
  ),
  caption: [Адресация транзитных каналов филиала],
) <tbl-links>

Идентификаторы маршрутизаторов OSPF: BR-EDGE — 10.2.254.254, BR-CORE — 10.2.254.1,
DSW-1 — 10.2.254.2, DSW-2 — 10.2.254.3, BR-CORE-2 — 10.2.254.4. DHCP-сервер SRV-DHCP
(10.2.50.10) обслуживает VLAN 10, 20, 30, 40, 60 и 70 через DHCP relay на SVI
коммутаторов распределения.

=== Требования и выбор оборудования

#todo[расчёт пропускной способности по уровням, бюджет PoE+, модели оборудования]

=== Прототип сети филиала

#todo[VLAN, транки и MSTP; LACP между DSW; SVI, HSRP и OSPF; DHCP relay; NAT]

// СЫРОЕ (2026-10-16): итоговые конфиги всех устройств — в приложении А
// (листинги @lst-cfg-DSW-1, @lst-cfg-DSW-2, @lst-cfg-ASW-1, @lst-cfg-BR-EDGE, @lst-cfg-SRV-DHCP, @lst-cfg-ISP-2).
// При формализации — вырезать из них фрагменты по темам в этот раздел.
// На DSW (IOL L2) — `no ip cef`, см. раздел траблшутинга.

==== Резервирование провайдера

#todo[IP SLA + track, плавающий маршрут, NAT через route-map]

==== Резервирование ядра

Согласно иерархической модели, уровень ядра должен строиться с резервированием
оборудования и многопутевой маршрутизацией. Для этого в сеть добавлен второй коммутатор
ядра BR-CORE-2. Он подключён к граничному маршрутизатору BR-EDGE, к обоим коммутаторам
распределения и к BR-CORE. Все его порты переведены в режим L3 (`no switchport`), адресация
каналов приведена в таблице @tbl-links. Маршрутизация — OSPF в области 0, как на остальных
L3-устройствах филиала; ACL и NAT на уровне ядра не применяются.

Настройка BR-CORE-2 приведена в листинге @lst-cmd-brcore2. На IOL-образе коммутатора
маршрутизация включена по умолчанию, поэтому команда `ip routing` в итоговой
конфигурации не отображается.

#commands("BR-CORE-2", [настройки интерфейсов и OSPF], read("commands/BR-CORE-2-core.txt")) <lst-cmd-brcore2>

На BR-CORE поднят канал к BR-CORE-2 (листинг @lst-cmd-brcore-e03). Сеть 10.2.255.24/30
попадает в уже настроенный на BR-CORE оператор `network 10.2.255.0 0.0.0.255 area 0`,
поэтому изменять OSPF не потребовалось.

#commands("BR-CORE", [настройки канала к BR-CORE-2], read("commands/BR-CORE-core2.txt")) <lst-cmd-brcore-e03>

На коммутаторах распределения OSPF настроен с `passive-interface default`, поэтому для
нового канала пассивный режим отключён явно (листинги @lst-cmd-dsw1-e12 и @lst-cmd-dsw2-e12).

#commands("DSW-1", [настройки канала к BR-CORE-2], read("commands/DSW-1-core2.txt")) <lst-cmd-dsw1-e12>

#commands("DSW-2", [настройки канала к BR-CORE-2], read("commands/DSW-2-core2.txt")) <lst-cmd-dsw2-e12>

После настройки BR-CORE-2 установил соседство с BR-CORE, DSW-1 и DSW-2, но не с BR-EDGE.
Проверка конфигурации BR-EDGE показала, что OSPF на нём анонсирует только сеть
10.2.255.0/30 (канал к BR-CORE), а интерфейс e0/2 в процесс OSPF не включён
(листинг @lst-out-bredge-before). Сеть
10.2.255.12/30 добавлена в OSPF (листинг @lst-cmd-bredge-ospf), после чего соседство
перешло в состояние FULL.

#console("BR-EDGE", [Конфигурация e0/2 и OSPF до исправления], read("outputs/BR-EDGE-before-ospf.txt")) <lst-out-bredge-before>

#commands("BR-EDGE", [настройки OSPF для канала к BR-CORE-2], read("commands/BR-EDGE-core2.txt")) <lst-cmd-bredge-ospf>

Результат: BR-CORE-2 имеет четыре соседа OSPF в состоянии FULL (листинг @lst-out-brcore2-nbr)
и получает маршрут по умолчанию от BR-EDGE напрямую (листинг @lst-out-brcore2-def).
Коммутатор распределения DSW-1 видит соседей через оба ядра (листинг @lst-out-dsw1-nbr),
а маршрут по умолчанию имеет два равноценных next-hop — 10.2.255.5 (BR-CORE) и
10.2.255.17 (BR-CORE-2), то есть трафик балансируется по двум ядрам (ECMP), а при отказе
одного из них остаётся второй путь (листинг @lst-out-dsw1-def).

#cli-output("BR-CORE-2", "show ip ospf neighbor", read("outputs/BR-CORE-2-ospf-neighbor.txt")) <lst-out-brcore2-nbr>

#cli-output("BR-CORE-2", "show ip route 0.0.0.0", read("outputs/BR-CORE-2-route-default.txt")) <lst-out-brcore2-def>

#cli-output("DSW-1", "show ip ospf neighbor", read("outputs/DSW-1-ospf-neighbor.txt")) <lst-out-dsw1-nbr>

#cli-output("DSW-1", "show ip route 0.0.0.0", read("outputs/DSW-1-route-default.txt")) <lst-out-dsw1-def>

==== Безопасность уровня доступа

#todo[Port Security, DHCP Snooping, DAI, IP Source Guard, неиспользуемые порты]

==== Разграничение доступа (вариант 5)

#todo[ACL SALES-IN, DEV-IN, GUEST-IN, CCTV-IN, MGMT-OUT]

=== Проверка работоспособности филиала

#todo[выводы show (VLAN, STP, HSRP, DHCP, ACL), траблшутинг OSPF через VLAN 99]

==== Тест отказа провайдера

Чтобы проверить именно механизм IP SLA, отказ имитировался на стороне провайдера:
на ISP-1 выключен интерфейс к филиалу (листинг @lst-cmd-isp1-fail). Канал BR-EDGE e0/0
при этом остаётся в состоянии up, и пропадание связи обнаруживается только по
отсутствию ответов на ICMP-зонд `ip sla 1`. Перед тестом на BR-EDGE очищалась таблица
трансляций (листинг @lst-cmd-clear-nat), а трафик в интернет генерировался с PC-ADMIN
(10.2.10.10) командой из листинга @lst-cmd-pc-ping.

#commands("ISP-1", [имитации отказа], read("commands/ISP-1-fail.txt")) <lst-cmd-isp1-fail>

#commands("BR-EDGE", [очистки трансляций NAT], read("commands/BR-EDGE-clear-nat.txt")) <lst-cmd-clear-nat>

#commands("PC-ADMIN", [генерации трафика], read("commands/PC-ADMIN-ping.txt")) <lst-cmd-pc-ping>

До отказа объект отслеживания находится в состоянии Up, маршрут по умолчанию ведёт к
ISP-1 (листинги @lst-out-track-before и @lst-out-route-before).

#cli-output("BR-EDGE", "show track brief", read("outputs/BR-EDGE-track-before.txt"), size: 8pt) <lst-out-track-before>

#cli-output("BR-EDGE", "show ip route 0.0.0.0", read("outputs/BR-EDGE-route-default-before.txt")) <lst-out-route-before>

После отключения ISP-1 объект `track 1` переходит в состояние Down, статический маршрут
через 198.51.100.1 снимается, и в таблицу маршрутизации устанавливается плавающий
маршрут через ISP-2 (192.0.2.1, административное расстояние 10). Трансляции PC-ADMIN
создаются с внешним адресом 192.0.2.2 — интерфейса e0/3 к ISP-2 (листинги
@lst-out-track-fail — @lst-out-nat-fail).

#cli-output("BR-EDGE", "show track brief", read("outputs/BR-EDGE-track-fail.txt"), size: 8pt) <lst-out-track-fail>

#cli-output("BR-EDGE", "show ip route 0.0.0.0", read("outputs/BR-EDGE-route-default-fail.txt")) <lst-out-route-fail>

#cli-output("BR-EDGE", "show ip nat translations", read("outputs/BR-EDGE-nat-fail.txt"), size: 8pt) <lst-out-nat-fail>

Затем интерфейс ISP-1 был включён обратно (листинг @lst-cmd-isp1-restore). Объект
отслеживания вернулся в Up, маршрут по умолчанию — на ISP-1 (листинги
@lst-out-track-restore и @lst-out-route-restore). Трансляции, созданные во время
отказа, продолжали использовать 192.0.2.2 до очистки таблицы; новые трансляции
создаются уже с адресом 198.51.100.2 (листинг @lst-out-nat-restore).

#commands("ISP-1", [восстановления канала], read("commands/ISP-1-restore.txt")) <lst-cmd-isp1-restore>

#cli-output("BR-EDGE", "show track brief", read("outputs/BR-EDGE-track-restore.txt"), size: 8pt) <lst-out-track-restore>

#cli-output("BR-EDGE", "show ip route 0.0.0.0", read("outputs/BR-EDGE-route-default-restore.txt")) <lst-out-route-restore>

#cli-output("BR-EDGE", "show ip nat translations", read("outputs/BR-EDGE-nat-restore.txt"), size: 8pt) <lst-out-nat-restore>

==== Тест отказа коммутатора ядра

Отказ BR-CORE имитировался отключением всех его интерфейсов (листинг @lst-cmd-brcore-fail).
По истечении dead-интервала DSW-1 разорвал соседство с BR-CORE
(листинг @lst-out-dsw1-log-fail); у DSW-1 остались соседи BR-CORE-2 и DSW-2, а маршрут
по умолчанию — единственный, через BR-CORE-2 (листинги @lst-out-dsw1-nbr-fail и
@lst-out-dsw1-def-fail). BR-EDGE также видит только BR-CORE-2 (листинг @lst-out-bredge-fail).

#commands("BR-CORE", [имитации отказа], read("commands/BR-CORE-fail.txt")) <lst-cmd-brcore-fail>

#console("DSW-1", [Сообщение о потере соседа OSPF], read("outputs/DSW-1-log-corefail.txt")) <lst-out-dsw1-log-fail>

#cli-output("DSW-1", "show ip ospf neighbor", read("outputs/DSW-1-ospf-neighbor-corefail.txt")) <lst-out-dsw1-nbr-fail>

#cli-output("DSW-1", "show ip route 0.0.0.0", read("outputs/DSW-1-route-default-corefail.txt")) <lst-out-dsw1-def-fail>

Доступ в интернет при этом сохраняется: пинг 8.8.8.8 с адреса шлюза VLAN 10 на DSW-1
проходит без потерь (листинг @lst-out-dsw1-ping-fail), а трафик PC-ADMIN транслируется на
BR-EDGE через ISP-1 (листинг @lst-out-bredge-fail).

#cli-output("DSW-1", "ping 8.8.8.8 source Vlan10 repeat 10", read("outputs/DSW-1-ping-corefail.txt")) <lst-out-dsw1-ping-fail>

#console("BR-EDGE", [Соседи OSPF и трансляции NAT при отказе BR-CORE], read("outputs/BR-EDGE-corefail.txt")) <lst-out-bredge-fail>

После включения интерфейсов BR-CORE (листинг @lst-cmd-brcore-restore) соседство
восстановилось, и маршрут по умолчанию на DSW-1 снова имеет два равноценных next-hop
(листинг @lst-out-dsw1-def-restore).

#commands("BR-CORE", [восстановления интерфейсов], read("commands/BR-CORE-restore.txt")) <lst-cmd-brcore-restore>

#cli-output("DSW-1", "show ip route 0.0.0.0", read("outputs/DSW-1-route-default-corerestore.txt")) <lst-out-dsw1-def-restore>

== Проектирование КВС головного офиса

=== Логическая структура сети

Сеть головного офиса (ГО) построена по той же трёхуровневой модели, что и сеть филиала,
и размещена в том же стенде: связь с филиалом идёт через общих провайдеров. В отличие от
филиала, ГО дополнительно выполняет функции граничного VPN-шлюза для филиалов, публикует
серверы в демилитаризованной зоне (DMZ) и предоставляет базовые сетевые сервисы.

Роли устройств:
- HQ-EDGE — граничный маршрутизатор: канал с публичным адресом, NAT, VPN-шлюз (GRE over
  IPsec), шлюз DMZ и фильтрация трафика на её границе. Межсетевой экран будет добавлен в
  следующих лабораторных работах; для DMZ также предусматривается система предотвращения
  вторжений (IPS) или межсетевой экран прикладного уровня (WAF);
- HQ-CORE-1, HQ-CORE-2 — дублированное ядро; между ядрами — L3 EtherChannel из двух каналов;
- HQ-DSW-1, HQ-DSW-2 — уровень распределения: маршрутизация между VLAN, резервирование
  шлюза VRRP, межсегментные ACL, DHCP relay;
- HQ-ASW-1, HQ-ASW-2 — уровень доступа, к каждому коммутатору распределения подключены
  агрегированным каналом LACP из двух линков;
- HQ-DMZ — коммутатор DMZ, подключён только к HQ-EDGE; серверы SRV-WEB и SRV-MAIL;
- HQ-INFRA — сервер DHCP, DNS и NTP; SRV-INT — внутренний сервер.

По сравнению с филиалом в ГО приняты следующие решения:
+ протокол резервирования шлюза VRRP (открытый стандарт RFC 5798) вместо проприетарного
  HSRP — это позволяет использовать в ГО оборудование разных производителей;
+ каналы между коммутаторами ядра объединены в L3 EtherChannel: обрыв одного линка не
  разрывает соседство маршрутизации между ядрами, а пропускная способность удваивается;
+ аплинки уровня доступа агрегированы по LACP (по два линка к каждому коммутатору
  распределения), что вдвое увеличивает пропускную способность между уровнями доступа и
  распределения (дополнительная задача 2 методических указаний).

#todo[схема сети ГО]

=== IP-адресация и VLAN

Для ГО выделен блок 10.1.0.0/16. Распределение VLAN приведено в таблице @tbl-hq-vlan.
Транзитные каналы ядра адресуются из сети 10.1.255.0/24 по маске /30. Публичный канал
ГО — 203.0.113.0/30 (ISP-1 — .1, HQ-EDGE — .2).

#figure(
  table(
    columns: 5,
    align: (center, left, left, left, center),
    table.header[*VLAN*][*Назначение*][*Подсеть*][*VIP / DSW-1 / DSW-2*][*VRRP master*],
    [10], [Администраторы (ADMIN)], [10.1.10.0/27], [.1 / .2 / .3], [DSW-1],
    [20], [Сотрудники (STAFF)], [10.1.20.0/24], [.1 / .2 / .3], [DSW-2],
    [50], [Внутренние серверы (SERVERS)], [10.1.50.0/26], [.1 / .2 / .3], [DSW-1],
    [55], [Сетевая инфраструктура: DHCP, DNS, NTP (INFRA)], [10.1.55.0/28], [.1 / .2 / .3], [DSW-1],
    [60], [Гостевой доступ (GUEST)], [10.1.60.0/24], [.1 / .2 / .3], [DSW-2],
    [70], [Видеонаблюдение (CCTV)], [10.1.70.0/26], [.1 / .2 / .3], [DSW-2],
    [99], [Управление (MGMT)], [10.1.99.0/28], [.1 / .2 / .3; ASW — .11/.12], [DSW-2],
    [100], [DMZ (на HQ-EDGE)], [10.1.100.0/28, fd00:1:100::/64], [HQ-EDGE .1], [—],
    [999], [BLACKHOLE (native, неиспользуемые порты)], [—], [—], [—],
  ),
  caption: [Распределение VLAN и адресация головного офиса],
) <tbl-hq-vlan>

=== Прототип сети ГО

==== Базовая настройка уровня коммутации

На коммутаторах распределения и доступа созданы VLAN ГО (VTP в прозрачном режиме),
настроен MSTP с регионом HQ: экземпляр 1 (VLAN 10, 50, 55) с корнем на HQ-DSW-1 и экземпляр 2
(VLAN 20, 60, 70, 99) с корнем на HQ-DSW-2. Все межкоммутаторные каналы — транки 802.1Q
с native VLAN 999 и без DTP, объединённые по LACP в Port-channel. Неиспользуемые порты
переведены в VLAN 999 и выключены (листинги @lst-cmd-hq-dsw1 — @lst-cmd-hq-asw2).

#commands("HQ-DSW-1", [базовой L2-настройки], read("commands/HQ-DSW-1-l2.txt")) <lst-cmd-hq-dsw1>

#commands("HQ-DSW-2", [базовой L2-настройки], read("commands/HQ-DSW-2-l2.txt")) <lst-cmd-hq-dsw2>

#commands("HQ-ASW-1", [базовой L2-настройки], read("commands/HQ-ASW-1-l2.txt")) <lst-cmd-hq-asw1>

#commands("HQ-ASW-2", [базовой L2-настройки], read("commands/HQ-ASW-2-l2.txt")) <lst-cmd-hq-asw2>

Между коммутаторами ядра собран L3 EtherChannel (листинги @lst-cmd-hq-core1 и
@lst-cmd-hq-core2), коммутатор DMZ настроен с отдельной VLAN 100 (листинг @lst-cmd-hq-dmz).
На HQ-EDGE и HQ-INFRA на этом этапе заданы только имена (листинги @lst-cmd-hq-edge и
@lst-cmd-hq-infra); при первом запуске IOL-маршрутизаторов на запрос диалога начальной
настройки дан ответ `no`.

#commands("HQ-CORE-1", [базовой настройки и L3 EtherChannel], read("commands/HQ-CORE-1-base.txt")) <lst-cmd-hq-core1>

#commands("HQ-CORE-2", [базовой настройки и L3 EtherChannel], read("commands/HQ-CORE-2-base.txt")) <lst-cmd-hq-core2>

#commands("HQ-DMZ", [базовой настройки], read("commands/HQ-DMZ-l2.txt")) <lst-cmd-hq-dmz>

#commands("HQ-EDGE", [базовой настройки], read("commands/HQ-EDGE-base.txt")) <lst-cmd-hq-edge>

#commands("HQ-INFRA", [базовой настройки], read("commands/HQ-INFRA-base.txt")) <lst-cmd-hq-infra>

Все агрегированные каналы собрались: на HQ-DSW-1 три Port-channel по два активных порта
(листинг @lst-out-hq-dsw1-ec), на HQ-ASW-1 — два (листинг @lst-out-hq-asw1-ec), L3
EtherChannel между ядрами в состоянии RU (листинг @lst-out-hq-core1); записи CDP с именем
Switch — устаревшие записи того же соседа HQ-CORE-2, полученные до смены имени устройства. HQ-DSW-1 является
корнем MST1, все его порты — назначенные (листинг @lst-out-hq-dsw1-stp). На HQ-ASW-1
резервный канал заблокирован в каждом экземпляре свой: в MST1 корневой порт — Po1 (к
HQ-DSW-1), Po2 в состоянии Alternate/Blocking, в MST2 — наоборот (листинг
@lst-out-hq-asw1-stp). Таким образом, петли устранены, а нагрузка разных групп VLAN
распределяется между коммутаторами распределения.

#cli-output("HQ-DSW-1", "show etherchannel summary | begin Group", read("outputs/HQ-DSW-1-etherchannel.txt"), size: 8pt) <lst-out-hq-dsw1-ec>

#cli-output("HQ-ASW-1", "show etherchannel summary | begin Group", read("outputs/HQ-ASW-1-etherchannel.txt"), size: 8pt) <lst-out-hq-asw1-ec>

#console("HQ-CORE-1", [Состояние L3 EtherChannel и соседи CDP], read("outputs/HQ-CORE-1-etherchannel-cdp.txt")) <lst-out-hq-core1>

#cli-output("HQ-DSW-1", "show spanning-tree mst 1 | begin Interface", read("outputs/HQ-DSW-1-stp-mst1.txt"), size: 8pt) <lst-out-hq-dsw1-stp>

#console("HQ-ASW-1", [Состояние портов MSTP], read("outputs/HQ-ASW-1-stp.txt")) <lst-out-hq-asw1-stp>

#todo[L3: ядро, OSPF, VRRP, HQ-EDGE и NAT; DHCP/DNS/NTP; DMZ; безопасность; VPN; IPv6]

== Верификация и траблшутинг

#todo[ping/traceroute с source, show ip route / show ipv6 route, show spanning-tree, туннель, NAT]

// СЫРОЕ (2026-10-16), формализовать на шаге 12
=== Проверки сценария сдачи (сырое)

#todo[оформить] MSTP: link-type p2p на HQ-DSW применён по одному Po (листинги @lst-raw-hq-p2p-cmd,
@lst-raw-hq-p2p); при отказе аплинка резервный канал переходит в Forwarding за ~0,2 с в ГО и
сразу в филиале (листинги @lst-raw-hq-mstp, @lst-raw-br-mstp). Изоляция VLAN — листинг
@lst-raw-isolation; IP–MAC–порт и DAI — листинг @lst-raw-ipmac; traceroute внутри DSW —
@lst-raw-trace; п. 2.4: IPv6, ping/traceroute с source через VPN — @lst-raw-ipv6, @lst-raw-dsw1-hq, @lst-raw-bredge-trace.

#commands("HQ-DSW-1 и HQ-DSW-2", [включения link-type point-to-point], read("commands/HQ-DSW-link-type-p2p.txt")) <lst-raw-hq-p2p-cmd>

#console("HQ-DSW-1, HQ-DSW-2", [Тип каналов MSTP после настройки], read("outputs/HQ-DSW-stp-p2p.txt")) <lst-raw-hq-p2p>

#console("HQ-ASW-1", [Отказ аплинка Po1 (MSTP)], read("outputs/HQ-ASW-1-mstp-fail.txt")) <lst-raw-hq-mstp>

#console("ASW-1", [Отказ аплинка e0/0 (MSTP)], read("outputs/ASW-1-mstp-fail.txt")) <lst-raw-br-mstp>

#console("хостах филиала и ГО", [Проверка изоляции VLAN], read("outputs/demo-6-isolation.txt")) <lst-raw-isolation>

#console("ASW-1, ASW-3, PC-GUEST", [Привязка IP–MAC–порт и подмена IP], read("outputs/demo-7-ip-mac-port.txt")) <lst-raw-ipmac>

#console("PC-ADMIN, PC-SALES", [traceroute между VLAN одного DSW], read("outputs/demo-2-traceroute-same-dsw.txt")) <lst-raw-trace>

#console("HQ-EDGE", [Таблица маршрутизации IPv6], read("outputs/HQ-EDGE-ipv6-route.txt")) <lst-raw-ipv6>

#console("DSW-1", [ping в ГО с source Vlan10], read("outputs/DSW-1-ping-hq-source.txt")) <lst-raw-dsw1-hq>

#console("BR-EDGE", [traceroute в ГО с source], read("outputs/BR-EDGE-traceroute-hq-source.txt")) <lst-raw-bredge-trace>

#console("HQ-EDGE, HQ-DSW-1", [Потеря транзита через HQ-DSW до отключения CEF], read("outputs/HQ-EDGE-cef-glean.txt")) <lst-raw-hq-cef>

=== Траблшутинг: потеря транзитного трафика между VLAN филиала

#todo[оформить] Симптом: хост↔хост между VLAN не работал, если оба VLAN маршрутизирует один DSW
(HSRP Active в обоих), в т. ч. вариант 5 — PC-SALES → SRV-FILE 10.2.20.42. Работало, когда
кадр уходил через Po1 к другому DSW (его прямой порт к ASW в этом MST-экземпляре Alternate).
В ГО (VRRP, к ASW только Port-channel) — работает (листинг @lst-raw-hq-admin-srvint).
DSW формирует кадр верно (adjacency, листинги @lst-raw-dsw2-adj и @lst-raw-dsw1-adj), счётчик растёт,
но хост пакет не получает: на SRV-DHCP 0 local destination, в debug — только HSRP hello
(листинги @lst-raw-srvdhcp-cef, @lst-raw-srvdhcp-debug). Пакеты, порождённые самим DSW
(process switching), доходят. Вывод — ошибка CEF-коммутации IOL L2 при выходе
маршрутизированного кадра в физический транк. Решение — `no ip cef` на DSW-1/DSW-2
(листинг @lst-raw-nocef); после — echo доходит (листинг @lst-raw-srvdhcp-nocef), вариант 5
работает (листинги @lst-raw-sales-ping, @lst-raw-sales-acl), ADMIN↔ACC и интернет — тоже
(листинг @lst-raw-admin-acc). В ГО тот же образ: транзит через HQ-DSW проходил только при
уже разрешённом ARP (листинг @lst-raw-hq-cef) — `no ip cef` применён и на HQ-DSW-1/2. Попутно найдено: DSW-1 упал (stopped) через ~2 мин после start_all,
поднят start_node.

#cli-output("PC-HQ-ADMIN", "ping 10.1.50.10 -c 4", read("outputs/HQ-ADMIN-ping-srvint.txt")) <lst-raw-hq-admin-srvint>

#cli-output("DSW-2", "show adjacency vlan 20 detail", read("outputs/DSW-2-adjacency-srvfile.txt")) <lst-raw-dsw2-adj>

#cli-output("DSW-1", "show adjacency vlan 50 detail | begin 10.2.50.10", read("outputs/DSW-1-adjacency-srvdhcp.txt")) <lst-raw-dsw1-adj>

#cli-output("SRV-DHCP", "show ip traffic", read("outputs/SRV-DHCP-traffic-cef.txt")) <lst-raw-srvdhcp-cef>

#cli-output("SRV-DHCP", "show logging | include IP:|ICMP", read("outputs/SRV-DHCP-debug-cef.txt"), size: 8pt) <lst-raw-srvdhcp-debug>

#commands("DSW-1 и DSW-2", [отключения CEF], read("commands/DSW-no-cef.txt")) <lst-raw-nocef>

#console("SRV-DHCP", [ICMP-статистика после отключения CEF], read("outputs/SRV-DHCP-traffic-nocef.txt")) <lst-raw-srvdhcp-nocef>

#console("PC-SALES", [Доступ к файловому серверу (вариант 5)], read("outputs/PC-SALES-ping-srvfile.txt")) <lst-raw-sales-ping>

#cli-output("DSW-2", "show ip access-lists SALES-IN", read("outputs/DSW-2-sales-in.txt")) <lst-raw-sales-acl>

#console("PC-ADMIN", [Связность ADMIN → ACC и интернет], read("outputs/PC-ADMIN-ping-acc.txt")) <lst-raw-admin-acc>

=== Траблшутинг: неполная безопасность HQ-ASW-2

#todo[оформить] После перезапуска HQ-INFRA не отвечал, хосты ГО не получали DHCP: на HQ-ASW-2
не было trust на Po1/Po2 (DAI резал ARP от шлюзов — 68 DHCP Drops в VLAN 55), Port Security и
маршрута по умолчанию (команды при первоначальном вводе потерялись). Исправлено
(листинг @lst-raw-hq-asw2-fix), после — все 4 хоста ГО получили адреса.

#commands("HQ-ASW-2", [исправления безопасности доступа], read("commands/HQ-ASW-2-security-fix.txt")) <lst-raw-hq-asw2-fix>

// СЫРОЕ (2026-10-16): финальный прогон базовых проверок
=== Финальный прогон базовых проверок (сырое)

#console("стенд", [Финальный прогон базовых проверок], read("outputs/final-check-20261016.txt")) <lst-raw-final-check>

// СЫРОЕ (2026-10-16)
=== Доработки ГО: VLAN для DHCP Snooping/DAI и корень CIST (сырое)

#todo[оформить] DHCP Snooping и DAI на коммутаторах доступа ГО включены только для VLAN хостов,
подключённых к этому коммутатору: HQ-ASW-1 — 10, 20, 60 (ADMIN, STAFF, GUEST), HQ-ASW-2 — 50, 55, 70
(SRV-INT, HQ-INFRA, CAM-HQ; серверы со статикой — через ARP ACL DAI-STATIC) (листинг @lst-raw-asw-snoop-vlans).
На HQ-DSW явно задан приоритет CIST (MST0), как в филиале: корень CIST — HQ-DSW-1 (листинг @lst-raw-mst0).

#commands("HQ-ASW-1/2", [VLAN для DHCP Snooping и DAI], read("commands/HQ-ASW-snooping-vlans.txt")) <lst-raw-asw-snoop-vlans>

#commands("HQ-DSW-1/2", [приоритет MST0], read("commands/HQ-DSW-mst0-priority.txt")) <lst-raw-mst0>

= Заключение

#todo[выводы]

// СЫРОЕ (2026-10-16): приложение с итоговыми конфигурациями (configs/ из выгрузки стенда)
#show: appendixes

= Итоговые конфигурации устройств

#for name in (
  "ISP", "ISP-2", "BR-EDGE", "BR-CORE", "BR-CORE-2", "DSW-1", "DSW-2", "ASW-1", "ASW-2", "ASW-3", "SRV-DHCP",
  "HQ-EDGE", "HQ-CORE-1", "HQ-CORE-2", "HQ-DSW-1", "HQ-DSW-2", "HQ-ASW-1", "HQ-ASW-2", "HQ-DMZ", "HQ-INFRA",
) [
  #{
    show raw: set text(size: 8pt)
    device-config(name, read("configs/" + name + ".txt"))
  } #label("lst-cfg-" + name)
]
