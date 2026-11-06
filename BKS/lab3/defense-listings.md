# БКС3: справка по каждому листингу к защите

Сверено с `main.typ`, `configs/`, `outputs/` и `demo-checks.md` 27.10.2026.
Номера соответствуют порядку 22 листингов в текущем отчёте. Это пояснение сохранённых
конфигураций и протоколов, а не новая проверка работающего стенда.

Как отвечать: сначала назначение листинга одним предложением, затем команда и её параметры,
после этого — какой результат подтверждает настройку. Конфигурационные директивы не нужно
вводить в оболочку: их читает соответствующая служба. В таблицах номера строк относятся
к файлу, приведённому непосредственно над таблицей. Скобки и запятые JSON задают структуру;
смысл имеют имена полей и их значения.

## Картина целиком — ответ за минуту

Есть два независимых способа добраться до одного сервиса `10.1.50.10:8080`:

1. **Межофисный VPN:** BR-CLIENT `10.2.20.42` → BR-GW `10.2.20.1` → GRE `tun0`
   внутри IPsec между `203.0.113.20` и `203.0.113.10` → HQ-GW → HQ-SRV.
   GRE переносит IP и multicast OSPF, IPsec защищает GRE, OSPF распространяет LAN-маршруты,
   iptables ограничивает разрешённые потоки. NAT между LAN отсутствует.
2. **Прокси-каскад:** приложение → SOCKS5 `127.0.0.1:1080` → VLESS/TLS к
   XRAY-RELAY `203.0.113.30:443` → отдельное VLESS/TLS-соединение к HQ-GW
   `203.0.113.10:443` → обычный TCP/HTTP к HQ-SRV. На первом переходе BR-GW
   делает узкий SNAT клиента в `203.0.113.20`. Это последовательная цепочка, не резервирование.

На шлюзах `ens3` — WAN, `ens4` — LAN, `ens5` — управление. На клиенте имена и роли другие:
его LAN — `ens3`. Нельзя переносить смысл имени интерфейса с одного узла на другой.
Служебный default route через `192.168.15.2` нужен для управления; более специфичные
маршруты и фильтрация направляют проверяемый обмен через учебную сеть.

## Навигация

1. [Интерфейсы HQ-GW](#listing-1) — `configs/HQ-GW-netplan.yaml`.
2. [Интерфейсы BR-GW](#listing-2) — `configs/BR-GW-netplan.yaml`.
3. [HQ-GW: GRE](#listing-3) — `configs/HQ-GW-gre.service`.
4. [HQ-GW: IPsec](#listing-4) — `configs/HQ-GW-ipsec.conf`.
5. [HQ-GW: OSPF](#listing-5) — `configs/HQ-GW-frr.conf`.
6. [HQ-GW: FW](#listing-6) — `configs/HQ-GW-rules.v4`.
7. [BR-GW: GRE](#listing-7) — `configs/BR-GW-gre.service`.
8. [BR-GW: IPsec](#listing-8) — `configs/BR-GW-ipsec.conf`.
9. [BR-GW: OSPF](#listing-9) — `configs/BR-GW-frr.conf`.
10. [BR-GW: FW](#listing-10) — `configs/BR-GW-rules.v4`.
11. [BR-CLIENT: Xray](#listing-11) — `configs/BR-CLIENT-xray.json`.
12. [XRAY-RELAY: Xray](#listing-12) — `configs/XRAY-RELAY-xray.json`.
13. [HQ-GW: Xray](#listing-13) — `configs/HQ-GW-xray.json`.
14. [Служба внутреннего веб-сервиса ГО](#listing-14) — `configs/HQ-SRV-web.service`.
15. [Проверка ICMP, HTTP и пути от клиента филиала](#listing-15) — `outputs/BR-CLIENT-connectivity.txt`.
16. [Соседство OSPF, маршруты и IPsec на шлюзе филиала](#listing-16) — `outputs/BR-GW-routing.txt`.
17. [Пакеты на WAN при защищённом обмене](#listing-17) — `outputs/WAN-encryption.txt`.
18. [Проверка MTU туннеля](#listing-18) — `outputs/BR-CLIENT-MTU.txt`.
19. [Разрешённый и запрещённый запросы через каскад](#listing-19) — `outputs/BR-CLIENT-xray.txt`.
20. [Подтверждение двух последовательных переходов Xray](#listing-20) — `outputs/Xray-cascade-logs.txt`.
21. [Отказ IPsec и промежуточного прокси с последующим восстановлением](#listing-21) — `outputs/failure-tests.txt`.
22. [Проверка служб и передачи данных после перезагрузки](#listing-22) — `outputs/after-reboot.txt`.

<a id="listing-1"></a>

## Листинг 1. Интерфейсы HQ-GW

**Сказать сначала:** «Сохраняем адреса трёх интерфейсов шлюза ГО и служебный default route.»

Файл: [configs/HQ-GW-netplan.yaml](configs/HQ-GW-netplan.yaml). Метка отчёта: `lst-hq-netplan`.

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
      - "203.0.113.10/24"
    ens4:
      addresses:
      - "10.1.50.1/26"
    ens5:
      addresses:
      - "192.168.15.211/24"
      nameservers:
        addresses:
        - 1.1.1.1
        - 8.8.8.8
      routes:
      - to: "default"
        via: "192.168.15.2"
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `network:` | Корневой раздел сетевой конфигурации Netplan. |
| 2 | `version: 2` | Версия схемы Netplan, а не версия IP. |
| 3 | `ethernets:` | Раздел Ethernet-интерфейсов. |
| 4 | `ens3:` | WAN шлюза: общий учебный сегмент 203.0.113.0/24. |
| 5 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 6 | `- "203.0.113.10/24"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 7 | `ens4:` | LAN данного офиса: HQ 10.1.50.0/26, BR 10.2.20.0/24. |
| 8 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 9 | `- "10.1.50.1/26"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 10 | `ens5:` | Отдельный интерфейс управления 192.168.15.0/24. |
| 11 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 12 | `- "192.168.15.211/24"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 13 | `nameservers:` | Настройка DNS-резолверов для самого шлюза; это не запуск DNS-сервера. |
| 14 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 15 | `- 1.1.1.1` | IP внешнего DNS-резолвера; обращения к числовым IP в проверках разрешения DNS не требуют. |
| 16 | `- 8.8.8.8` | IP внешнего DNS-резолвера; обращения к числовым IP в проверках разрешения DNS не требуют. |
| 17 | `routes:` | Список статических маршрутов интерфейса. |
| 18 | `- to: "default"` | Маршрут по умолчанию 0.0.0.0/0: используется, когда нет более специфичного подходящего маршрута. |
| 19 | `via: "192.168.15.2"` | Next hop служебного default route в сети управления. OSPF-маршрут к удалённой LAN специфичнее /0 и выбирается вместо него. |

<a id="listing-2"></a>

## Листинг 2. Интерфейсы BR-GW

**Сказать сначала:** «То же для филиала; роли интерфейсов сохранены, WAN/LAN-IP другие.»

Файл: [configs/BR-GW-netplan.yaml](configs/BR-GW-netplan.yaml). Метка отчёта: `lst-br-netplan`.

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
      - "203.0.113.20/24"
    ens4:
      addresses:
      - "10.2.20.1/24"
    ens5:
      addresses:
      - "192.168.15.212/24"
      nameservers:
        addresses:
        - 1.1.1.1
        - 8.8.8.8
      routes:
      - to: "default"
        via: "192.168.15.2"
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `network:` | Корневой раздел сетевой конфигурации Netplan. |
| 2 | `version: 2` | Версия схемы Netplan, а не версия IP. |
| 3 | `ethernets:` | Раздел Ethernet-интерфейсов. |
| 4 | `ens3:` | WAN шлюза: общий учебный сегмент 203.0.113.0/24. |
| 5 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 6 | `- "203.0.113.20/24"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 7 | `ens4:` | LAN данного офиса: HQ 10.1.50.0/26, BR 10.2.20.0/24. |
| 8 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 9 | `- "10.2.20.1/24"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 10 | `ens5:` | Отдельный интерфейс управления 192.168.15.0/24. |
| 11 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 12 | `- "192.168.15.212/24"` | Статический адрес и длина префикса: /24 = 255.255.255.0, /26 = 255.255.255.192. Адрес шлюза LAN используется конечными узлами как next hop. |
| 13 | `nameservers:` | Настройка DNS-резолверов для самого шлюза; это не запуск DNS-сервера. |
| 14 | `addresses:` | Список статических адресов интерфейса; внутри nameservers — список DNS-серверов. |
| 15 | `- 1.1.1.1` | IP внешнего DNS-резолвера; обращения к числовым IP в проверках разрешения DNS не требуют. |
| 16 | `- 8.8.8.8` | IP внешнего DNS-резолвера; обращения к числовым IP в проверках разрешения DNS не требуют. |
| 17 | `routes:` | Список статических маршрутов интерфейса. |
| 18 | `- to: "default"` | Маршрут по умолчанию 0.0.0.0/0: используется, когда нет более специфичного подходящего маршрута. |
| 19 | `via: "192.168.15.2"` | Next hop служебного default route в сети управления. OSPF-маршрут к удалённой LAN специфичнее /0 и выбирается вместо него. |

<a id="listing-3"></a>

## Листинг 3. HQ-GW: GRE

**Сказать сначала:** «Создаём GRE-интерфейс при загрузке, адресуем и задаём MTU.»

Файл: [configs/HQ-GW-gre.service](configs/HQ-GW-gre.service). Метка отчёта: `lst-hq-gw-gre`.

```ini
[Unit]
Description=Persistent GRE tunnel for protected site-to-site traffic
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add tun0 mode gre local 203.0.113.10 remote 203.0.113.20 ttl 64
ExecStart=/sbin/ip address add 172.16.0.1/30 dev tun0
ExecStart=/sbin/ip link set tun0 mtu 1400 up
ExecStart=/sbin/sysctl -w net.ipv4.conf.tun0.rp_filter=0
ExecStop=/sbin/ip tunnel del tun0
[Install]
WantedBy=multi-user.target
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `[Unit]` | Общие сведения о службе и зависимости от других unit. |
| 2 | `Description=Persistent GRE tunnel for protected site-to-site traffic` | Человекочитаемое описание службы; на обработку пакетов не влияет. |
| 3 | `Wants=network-online.target` | Просит запустить цель готовности сети; это мягкая зависимость, а не гарантия доступности удалённого узла. |
| 4 | `After=network-online.target` | Задаёт порядок: запускать после достижения network-online.target. Само по себе After не запускает зависимость. |
| 5 | `[Service]` | Параметры запуска и окружения службы. |
| 6 | `Type=oneshot` | Выполнить короткие команды настройки и дождаться их завершения; постоянного GRE-процесса нет, интерфейс обслуживает ядро. |
| 7 | `RemainAfterExit=yes` | После успешных команд считать службу активной (active/exited), даже когда команды завершились. Это не проверка доступности туннеля. |
| 8 | `ExecStart=/sbin/ip tunnel add tun0 mode gre local 203.0.113.10 remote 203.0.113.20 ttl 64` | Создать tun0: mode gre — тип туннеля; local — собственный WAN-IP; remote — WAN-IP второго шлюза; ttl 64 — TTL внешнего IP-пакета. Эти адреса не являются адресами LAN или tun0. |
| 9 | `ExecStart=/sbin/ip address add 172.16.0.1/30 dev tun0` | Назначить внутренний IPv4-адрес GRE-интерфейсу: HQ — 172.16.0.1/30, BR — 172.16.0.2/30; dev tun0 указывает интерфейс. /30 = 255.255.255.252. |
| 10 | `ExecStart=/sbin/ip link set tun0 mtu 1400 up` | Установить MTU tun0 в 1400 байт и административно поднять интерфейс (up). Запас оставлен под GRE/IPsec; up не доказывает связь с соседом. |
| 11 | `ExecStart=/sbin/sysctl -w net.ipv4.conf.tun0.rp_filter=0` | Изменить параметр ядра: отключить reverse-path filtering именно на tun0, чтобы проверка обратного пути не мешала туннельной маршрутизации. Глобальные rp_filter также отключены в sysctl-конфиге. |
| 12 | `ExecStop=/sbin/ip tunnel del tun0` | При остановке службы удалить GRE-интерфейс tun0. |
| 13 | `[Install]` | Правила включения службы в автозагрузку. |
| 14 | `WantedBy=multi-user.target` | При systemctl enable привязать службу к обычному многопользовательскому режиму загрузки. Одна эта строка enable не выполняет. |

**Если уточнят:** `ExecStart` выполняются последовательно, потому что служба oneshot. `ip tunnel add` не идемпотентна: повторный ручной add при существующем tun0 даст ошибку. Служба создаёт GRE, но шифрование настраивается отдельно в следующем листинге.

<a id="listing-4"></a>

## Листинг 4. HQ-GW: IPsec

**Сказать сначала:** «Защищаем именно GRE между WAN-IP средствами IKEv2/IPsec transport mode.»

Файл: [configs/HQ-GW-ipsec.conf](configs/HQ-GW-ipsec.conf). Метка отчёта: `lst-hq-gw-ipsec`.

```ini
config setup
    uniqueids=yes
conn gre-site
    keyexchange=ikev2
    type=transport
    authby=psk
    left=203.0.113.10
    right=203.0.113.20
    leftprotoport=47
    rightprotoport=47
    ike=aes256-sha256-modp2048!
    esp=aes256gcm16-modp2048!
    ikelifetime=3h
    lifetime=1h
    dpddelay=10s
    dpdaction=restart
    keyingtries=%forever
    auto=start
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `config setup` | Начало глобальных параметров strongSwan/starter. |
| 2 | `uniqueids=yes` | Удалять/заменять старые IKE-соединения с совпадающими идентификаторами согласно политике uniqueids. |
| 3 | `conn gre-site` | Начало описания соединения с именем gre-site. |
| 4 | `keyexchange=ikev2` | Использовать IKEv2 для согласования ключей и SA. |
| 5 | `type=transport` | Транспортный режим: IPsec защищает GRE между WAN-IP шлюзов, без добавления ещё одного tunnel-mode IP-заголовка. |
| 6 | `authby=psk` | Аутентификация сторон заранее согласованным секретом PSK. Сам секрет находится в /etc/ipsec.secrets, а не здесь. |
| 7 | `left=203.0.113.10` | WAN-IP локальной стороны в данном файле. left/right — обозначения сторон, не обязательные роли инициатора/ответчика. |
| 8 | `right=203.0.113.20` | WAN-IP второй стороны. На другом шлюзе значения left и right зеркально переставлены. |
| 9 | `leftprotoport=47` | Селектор IP-протокола 47 (GRE). Это номер IP-протокола, не TCP/UDP-порт. |
| 10 | `rightprotoport=47` | Тот же GRE-селектор на другой стороне; шифруется GRE, а не произвольный трафик управления. |
| 11 | `ike=aes256-sha256-modp2048!` | Набор для IKE SA: AES с ключом 256 бит, SHA-256 для соответствующих функций целостности/PRF, DH MODP 2048. ! исключает добавление наборов по умолчанию. |
| 12 | `esp=aes256gcm16-modp2048!` | Набор для данных: AES-256-GCM, 16-байтовая метка аутентификации; MODP 2048 для DH при пересогласовании CHILD SA. GCM обеспечивает и шифрование, и целостность; отдельный SHA для ESP не нужен. ! — строгий список. |
| 13 | `ikelifetime=3h` | Заданный срок жизни IKE SA — 3 часа; обновление/переаутентификация планируется заранее с учётом остальных параметров реализации. |
| 14 | `lifetime=1h` | Срок жизни IPsec/CHILD SA — 1 час; rekey обычно начинается раньше истечения срока. |
| 15 | `dpddelay=10s` | Интервал проверки живости IKE-партнёра при необходимости — 10 секунд. Это не OSPF dead timer и не обещание обнаружения любого отказа за 10 секунд. |
| 16 | `dpdaction=restart` | При признании партнёра недоступным пытаться восстановить соединение. |
| 17 | `keyingtries=%forever` | Не ограничивать число последовательностей попыток установления ключевого соединения. |
| 18 | `auto=start` | При загрузке конфигурации инициировать соединение автоматически. |

**Если уточнят:** На проводе при transport mode остаются WAN-IP .10/.20, а GRE и вложенный IP защищены ESP. PSK аутентифицирует стороны, сеансовые ключи согласуются IKE/DH. Нельзя говорить, что PSK непосредственно является ключом AES для каждого пакета.

<a id="listing-5"></a>

## Листинг 5. HQ-GW: OSPF

**Сказать сначала:** «Устанавливаем OSPF-соседство через GRE и объявляем локальную серверную LAN.»

Файл: [configs/HQ-GW-frr.conf](configs/HQ-GW-frr.conf). Метка отчёта: `lst-hq-gw-ospf`.

```ini
frr defaults traditional
hostname hq-gw
service integrated-vtysh-config
!
interface tun0
 ip ospf network point-to-point
 ip ospf hello-interval 2
 ip ospf dead-interval 8
!
router ospf
 ospf router-id 10.1.254.254
 passive-interface default
 no passive-interface tun0
 network 172.16.0.0/30 area 0.0.0.0
 network 10.1.50.0/26 area 0.0.0.0
!
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `frr defaults traditional` | Выбрать традиционный профиль настроек FRR. |
| 2 | `hostname hq-gw` | Задать имя устройства в конфигурации/CLI FRR. |
| 3 | `service integrated-vtysh-config` | Использовать объединённую конфигурацию демонов FRR через vtysh. |
| 4 | `!` | Разделитель/комментарий FRR; команды не выполняет. |
| 5 | `interface tun0` | Перейти в контекст туннельного интерфейса. |
| 6 | `ip ospf network point-to-point` | Тип OSPF-сети точка-точка: один сосед, без выборов DR/BDR. |
| 7 | `ip ospf hello-interval 2` | Отправлять OSPF Hello каждые 2 секунды. |
| 8 | `ip ospf dead-interval 8` | При отсутствии Hello 8 секунд признать соседа недоступным. Таймеры на обоих концах согласованы. |
| 9 | `!` | Разделитель/комментарий FRR; команды не выполняет. |
| 10 | `router ospf` | Начало конфигурации процесса OSPFv2. |
| 11 | `ospf router-id 10.1.254.254` | Уникальный 32-битный идентификатор OSPF: HQ 10.1.254.254, BR 10.2.254.254. Не требуется назначать его физическому интерфейсу. |
| 12 | `passive-interface default` | По умолчанию не устанавливать OSPF-соседство на интерфейсах, включённых в OSPF; их сети могут анонсироваться. |
| 13 | `no passive-interface tun0` | Разрешить Hello и соседство на tun0. Только туннель участвует в обмене с другим маршрутизатором. |
| 14 | `network 172.16.0.0/30 area 0.0.0.0` | Включить OSPF на интерфейсах, чьи адреса попадают в эту сеть, и отнести их к backbone area 0.0.0.0. LAN при passive анонсируется без соседства с хостами; это не ручной маршрут к удалённой LAN. |
| 15 | `network 10.1.50.0/26 area 0.0.0.0` | Включить OSPF на интерфейсах, чьи адреса попадают в эту сеть, и отнести их к backbone area 0.0.0.0. LAN при passive анонсируется без соседства с хостами; это не ручной маршрут к удалённой LAN. |
| 16 | `!` | Разделитель/комментарий FRR; команды не выполняет. |

**Если уточнят:** OSPF не шифрует пользовательские данные. Здесь протокол получает защиту, потому что его пакеты идут внутри GRE/IPsec. `network` не включает WAN и управление в OSPF. На LAN не ожидаем OSPF-соседей с сервером.

<a id="listing-6"></a>

## Листинг 6. HQ-GW: FW

**Сказать сначала:** «Закрываем лишний вход и транзит, разрешаем защищённый GRE и нужный сервис.»

Файл: [configs/HQ-GW-rules.v4](configs/HQ-GW-rules.v4). Метка отчёта: `lst-hq-gw-fw`.

```text
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -i ens3 -p gre -m policy --dir in --pol none -j DROP
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i ens5 -s 192.168.15.128/32 -p tcp --dport 22 -j ACCEPT
-A INPUT -i ens5 -p icmp -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.20 -p udp -m multiport --dports 500,4500 -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.20 -p esp -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.20 -p gre -m policy --dir in --pol ipsec -j ACCEPT
-A INPUT -i tun0 -p ospf -j ACCEPT
-A INPUT -i tun0 -p icmp -j ACCEPT
-A INPUT -i ens4 -p icmp -j ACCEPT
-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A OUTPUT -o ens3 -p gre -m policy --dir out --pol ipsec -j ACCEPT
-A OUTPUT -o ens3 -p gre -j DROP
-A INPUT -i ens3 -s 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT
COMMIT
*mangle
:FORWARD ACCEPT [0:0]
-A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
COMMIT
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `*filter` | Начало таблицы фильтрации пакетов. |
| 2 | `:INPUT DROP [0:0]` | Объявить цепочку INPUT, политика по умолчанию DROP; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 3 | `:FORWARD DROP [0:0]` | Объявить цепочку FORWARD, политика по умолчанию DROP; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 4 | `:OUTPUT ACCEPT [0:0]` | Объявить цепочку OUTPUT, политика по умолчанию ACCEPT; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 5 | `-A INPUT -i lo -j ACCEPT` | Разрешить пакеты loopback к самому узлу. |
| 6 | `-A INPUT -i ens3 -p gre -m policy --dir in --pol none -j DROP` | Отбросить входящий GRE с WAN, не прошедший IPsec. Стоит до ESTABLISHED,RELATED, чтобы conntrack не пропустил открытый GRE. |
| 7 | `-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Разрешить пакеты уже отслеживаемых соединений и связанных потоков (например, некоторых ICMP-ошибок). В FORWARD это правило пропускает ответы сервера; оно не разрешает произвольные новые соединения. |
| 8 | `-A INPUT -i ens5 -s 192.168.15.128/32 -p tcp --dport 22 -j ACCEPT` | Разрешить SSH к шлюзу только через интерфейс управления ens5 и только от 192.168.15.128/32. |
| 9 | `-A INPUT -i ens5 -p icmp -j ACCEPT` | Разрешить ICMP к шлюзу из сети управления. |
| 10 | `-A INPUT -i ens3 -s 203.0.113.20 -p udp -m multiport --dports 500,4500 -j ACCEPT` | Разрешить UDP к самому шлюзу от WAN-IP второго шлюза: 500 для IKE, 4500 для NAT-T/IKE по UDP. multiport позволяет указать оба порта одним правилом; наличие разрешения 4500 не означает, что NAT-T фактически используется. |
| 11 | `-A INPUT -i ens3 -s 203.0.113.20 -p esp -j ACCEPT` | Разрешить ESP (IP-протокол 50) от WAN-IP второго шлюза. ESP — защищённые данные IPsec, не TCP/UDP-порт. |
| 12 | `-A INPUT -i ens3 -s 203.0.113.20 -p gre -m policy --dir in --pol ipsec -j ACCEPT` | Разрешить GRE от второго шлюза только при входящей IPsec policy; это уже защищённый/дешифрованный стеком IPsec GRE. |
| 13 | `-A INPUT -i tun0 -p ospf -j ACCEPT` | Разрешить OSPF (IP-протокол 89) к самому маршрутизатору через tun0; без этого соседство не поднимется. |
| 14 | `-A INPUT -i tun0 -p icmp -j ACCEPT` | Разрешить диагностический ICMP к самому шлюзу со стороны туннеля. |
| 15 | `-A INPUT -i ens4 -p icmp -j ACCEPT` | Разрешить диагностический ICMP к самому шлюзу из локальной LAN. |
| 16 | `-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Разрешить пакеты уже отслеживаемых соединений и связанных потоков (например, некоторых ICMP-ошибок). В FORWARD это правило пропускает ответы сервера; оно не разрешает произвольные новые соединения. |
| 17 | `-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT` | Разрешить транзит ICMP из 10.2.20.0/24 к единственному серверу 10.1.50.10/32, вход и выход заданы явно. |
| 18 | `-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT` | Разрешить транзит TCP к порту назначения 8080 из 10.2.20.0/24 к единственному серверу 10.1.50.10/32, вход и выход заданы явно. |
| 19 | `-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT` | В этом файле строка задаёт ICMP с теми же source/destination, но противоположным направлением интерфейсов. Для обычного пути в текущей топологии избыточна; это НЕ правило ответа сервера. Ответы разрешены ESTABLISHED,RELATED. Не приписывать ей функцию обратного разрешения. |
| 20 | `-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT` | В этом файле строка задаёт TCP к порту назначения 8080 с теми же source/destination, но противоположным направлением интерфейсов. Для обычного пути в текущей топологии избыточна; это НЕ правило ответа сервера. Ответы разрешены ESTABLISHED,RELATED. Не приписывать ей функцию обратного разрешения. |
| 21 | `-A OUTPUT -o ens3 -p gre -m policy --dir out --pol ipsec -j ACCEPT` | Разрешить исходящий GRE через WAN, только если к нему применяется исходящая IPsec policy. |
| 22 | `-A OUTPUT -o ens3 -p gre -j DROP` | Отбросить остальной исходящий GRE через WAN. Вместе с предыдущим правилом предотвращает открытый GRE при потере IPsec, несмотря на общий OUTPUT ACCEPT. |
| 23 | `-A INPUT -i ens3 -s 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT` | Разрешить вход к Xray на HQ-GW:443 только от XRAY-RELAY 203.0.113.30. |
| 24 | `COMMIT` | Завершить и применить текущую таблицу в формате iptables-restore. |
| 25 | `*mangle` | Начало таблицы изменения служебных параметров пакетов (здесь TCP MSS). |
| 26 | `:FORWARD ACCEPT [0:0]` | Объявить цепочку FORWARD, политика по умолчанию ACCEPT; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 27 | `-A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu` | В транзитных TCP SYN-пакетах на выходе tun0 ограничить MSS по PMTU: --tcp-flags SYN,RST SYN проверяет SYN=1 и RST=0; TCPMSS меняет объявляемый размер TCP-данных. Это не изменение MTU и не средство для ICMP/UDP. |
| 28 | `COMMIT` | Завершить и применить текущую таблицу в формате iptables-restore. |

**Если уточнят:** Правила читаются сверху вниз внутри цепочки. `INPUT` относится к самому шлюзу, `FORWARD` — к проходящим через него пакетам, `OUTPUT` — к пакетам, сформированным самим узлом. Внешний GRE обрабатывается как трафик самого шлюза, вложенный LAN-пакет после декапсуляции — как транзит. Общий OUTPUT ACCEPT не означает полного запрета всех исходящих соединений.

<a id="listing-7"></a>

## Листинг 7. BR-GW: GRE

**Сказать сначала:** «Зеркальная GRE-настройка филиала: local/remote и внутренний адрес меняются местами.»

Файл: [configs/BR-GW-gre.service](configs/BR-GW-gre.service). Метка отчёта: `lst-br-gw-gre`.

```ini
[Unit]
Description=Persistent GRE tunnel for protected site-to-site traffic
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add tun0 mode gre local 203.0.113.20 remote 203.0.113.10 ttl 64
ExecStart=/sbin/ip address add 172.16.0.2/30 dev tun0
ExecStart=/sbin/ip link set tun0 mtu 1400 up
ExecStart=/sbin/sysctl -w net.ipv4.conf.tun0.rp_filter=0
ExecStop=/sbin/ip tunnel del tun0
[Install]
WantedBy=multi-user.target
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `[Unit]` | Общие сведения о службе и зависимости от других unit. |
| 2 | `Description=Persistent GRE tunnel for protected site-to-site traffic` | Человекочитаемое описание службы; на обработку пакетов не влияет. |
| 3 | `Wants=network-online.target` | Просит запустить цель готовности сети; это мягкая зависимость, а не гарантия доступности удалённого узла. |
| 4 | `After=network-online.target` | Задаёт порядок: запускать после достижения network-online.target. Само по себе After не запускает зависимость. |
| 5 | `[Service]` | Параметры запуска и окружения службы. |
| 6 | `Type=oneshot` | Выполнить короткие команды настройки и дождаться их завершения; постоянного GRE-процесса нет, интерфейс обслуживает ядро. |
| 7 | `RemainAfterExit=yes` | После успешных команд считать службу активной (active/exited), даже когда команды завершились. Это не проверка доступности туннеля. |
| 8 | `ExecStart=/sbin/ip tunnel add tun0 mode gre local 203.0.113.20 remote 203.0.113.10 ttl 64` | Создать tun0: mode gre — тип туннеля; local — собственный WAN-IP; remote — WAN-IP второго шлюза; ttl 64 — TTL внешнего IP-пакета. Эти адреса не являются адресами LAN или tun0. |
| 9 | `ExecStart=/sbin/ip address add 172.16.0.2/30 dev tun0` | Назначить внутренний IPv4-адрес GRE-интерфейсу: HQ — 172.16.0.1/30, BR — 172.16.0.2/30; dev tun0 указывает интерфейс. /30 = 255.255.255.252. |
| 10 | `ExecStart=/sbin/ip link set tun0 mtu 1400 up` | Установить MTU tun0 в 1400 байт и административно поднять интерфейс (up). Запас оставлен под GRE/IPsec; up не доказывает связь с соседом. |
| 11 | `ExecStart=/sbin/sysctl -w net.ipv4.conf.tun0.rp_filter=0` | Изменить параметр ядра: отключить reverse-path filtering именно на tun0, чтобы проверка обратного пути не мешала туннельной маршрутизации. Глобальные rp_filter также отключены в sysctl-конфиге. |
| 12 | `ExecStop=/sbin/ip tunnel del tun0` | При остановке службы удалить GRE-интерфейс tun0. |
| 13 | `[Install]` | Правила включения службы в автозагрузку. |
| 14 | `WantedBy=multi-user.target` | При systemctl enable привязать службу к обычному многопользовательскому режиму загрузки. Одна эта строка enable не выполняет. |

**Если уточнят:** От листинга 3 отличается только направление WAN-IP и адрес tun0 .2 вместо .1; параметры службы и их смысл те же.

<a id="listing-8"></a>

## Листинг 8. BR-GW: IPsec

**Сказать сначала:** «Зеркальная IPsec-настройка филиала; криптографические параметры совпадают.»

Файл: [configs/BR-GW-ipsec.conf](configs/BR-GW-ipsec.conf). Метка отчёта: `lst-br-gw-ipsec`.

```ini
config setup
    uniqueids=yes
conn gre-site
    keyexchange=ikev2
    type=transport
    authby=psk
    left=203.0.113.20
    right=203.0.113.10
    leftprotoport=47
    rightprotoport=47
    ike=aes256-sha256-modp2048!
    esp=aes256gcm16-modp2048!
    ikelifetime=3h
    lifetime=1h
    dpddelay=10s
    dpdaction=restart
    keyingtries=%forever
    auto=start
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `config setup` | Начало глобальных параметров strongSwan/starter. |
| 2 | `uniqueids=yes` | Удалять/заменять старые IKE-соединения с совпадающими идентификаторами согласно политике uniqueids. |
| 3 | `conn gre-site` | Начало описания соединения с именем gre-site. |
| 4 | `keyexchange=ikev2` | Использовать IKEv2 для согласования ключей и SA. |
| 5 | `type=transport` | Транспортный режим: IPsec защищает GRE между WAN-IP шлюзов, без добавления ещё одного tunnel-mode IP-заголовка. |
| 6 | `authby=psk` | Аутентификация сторон заранее согласованным секретом PSK. Сам секрет находится в /etc/ipsec.secrets, а не здесь. |
| 7 | `left=203.0.113.20` | WAN-IP локальной стороны в данном файле. left/right — обозначения сторон, не обязательные роли инициатора/ответчика. |
| 8 | `right=203.0.113.10` | WAN-IP второй стороны. На другом шлюзе значения left и right зеркально переставлены. |
| 9 | `leftprotoport=47` | Селектор IP-протокола 47 (GRE). Это номер IP-протокола, не TCP/UDP-порт. |
| 10 | `rightprotoport=47` | Тот же GRE-селектор на другой стороне; шифруется GRE, а не произвольный трафик управления. |
| 11 | `ike=aes256-sha256-modp2048!` | Набор для IKE SA: AES с ключом 256 бит, SHA-256 для соответствующих функций целостности/PRF, DH MODP 2048. ! исключает добавление наборов по умолчанию. |
| 12 | `esp=aes256gcm16-modp2048!` | Набор для данных: AES-256-GCM, 16-байтовая метка аутентификации; MODP 2048 для DH при пересогласовании CHILD SA. GCM обеспечивает и шифрование, и целостность; отдельный SHA для ESP не нужен. ! — строгий список. |
| 13 | `ikelifetime=3h` | Заданный срок жизни IKE SA — 3 часа; обновление/переаутентификация планируется заранее с учётом остальных параметров реализации. |
| 14 | `lifetime=1h` | Срок жизни IPsec/CHILD SA — 1 час; rekey обычно начинается раньше истечения срока. |
| 15 | `dpddelay=10s` | Интервал проверки живости IKE-партнёра при необходимости — 10 секунд. Это не OSPF dead timer и не обещание обнаружения любого отказа за 10 секунд. |
| 16 | `dpdaction=restart` | При признании партнёра недоступным пытаться восстановить соединение. |
| 17 | `keyingtries=%forever` | Не ограничивать число последовательностей попыток установления ключевого соединения. |
| 18 | `auto=start` | При загрузке конфигурации инициировать соединение автоматически. |

**Если уточнят:** На обоих шлюзах PSK согласован отдельно; в публичной справке и отчёте его значение не приводится. Поля left/right в этом файле переставлены относительно листинга 4.

<a id="listing-9"></a>

## Листинг 9. BR-GW: OSPF

**Сказать сначала:** «OSPF филиала объявляет клиентскую LAN и узнаёт сеть серверов ГО.»

Файл: [configs/BR-GW-frr.conf](configs/BR-GW-frr.conf). Метка отчёта: `lst-br-gw-ospf`.

```ini
frr defaults traditional
hostname br-gw
service integrated-vtysh-config
!
interface tun0
 ip ospf network point-to-point
 ip ospf hello-interval 2
 ip ospf dead-interval 8
!
router ospf
 ospf router-id 10.2.254.254
 passive-interface default
 no passive-interface tun0
 network 172.16.0.0/30 area 0.0.0.0
 network 10.2.20.0/24 area 0.0.0.0
!
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `frr defaults traditional` | Выбрать традиционный профиль настроек FRR. |
| 2 | `hostname br-gw` | Задать имя устройства в конфигурации/CLI FRR. |
| 3 | `service integrated-vtysh-config` | Использовать объединённую конфигурацию демонов FRR через vtysh. |
| 4 | `!` | Разделитель/комментарий FRR; команды не выполняет. |
| 5 | `interface tun0` | Перейти в контекст туннельного интерфейса. |
| 6 | `ip ospf network point-to-point` | Тип OSPF-сети точка-точка: один сосед, без выборов DR/BDR. |
| 7 | `ip ospf hello-interval 2` | Отправлять OSPF Hello каждые 2 секунды. |
| 8 | `ip ospf dead-interval 8` | При отсутствии Hello 8 секунд признать соседа недоступным. Таймеры на обоих концах согласованы. |
| 9 | `!` | Разделитель/комментарий FRR; команды не выполняет. |
| 10 | `router ospf` | Начало конфигурации процесса OSPFv2. |
| 11 | `ospf router-id 10.2.254.254` | Уникальный 32-битный идентификатор OSPF: HQ 10.1.254.254, BR 10.2.254.254. Не требуется назначать его физическому интерфейсу. |
| 12 | `passive-interface default` | По умолчанию не устанавливать OSPF-соседство на интерфейсах, включённых в OSPF; их сети могут анонсироваться. |
| 13 | `no passive-interface tun0` | Разрешить Hello и соседство на tun0. Только туннель участвует в обмене с другим маршрутизатором. |
| 14 | `network 172.16.0.0/30 area 0.0.0.0` | Включить OSPF на интерфейсах, чьи адреса попадают в эту сеть, и отнести их к backbone area 0.0.0.0. LAN при passive анонсируется без соседства с хостами; это не ручной маршрут к удалённой LAN. |
| 15 | `network 10.2.20.0/24 area 0.0.0.0` | Включить OSPF на интерфейсах, чьи адреса попадают в эту сеть, и отнести их к backbone area 0.0.0.0. LAN при passive анонсируется без соседства с хостами; это не ручной маршрут к удалённой LAN. |
| 16 | `!` | Разделитель/комментарий FRR; команды не выполняет. |

**Если уточнят:** Router ID 10.2.254.254 идентифицирует BR-GW, а next hop удалённого маршрута — реальный адрес соседа 172.16.0.1. Эти значения нельзя путать.

<a id="listing-10"></a>

## Листинг 10. BR-GW: FW

**Сказать сначала:** «Фильтрация филиала плюс разрешение и SNAT первого перехода каскада.»

Файл: [configs/BR-GW-rules.v4](configs/BR-GW-rules.v4). Метка отчёта: `lst-br-gw-fw`.

```text
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -i ens3 -p gre -m policy --dir in --pol none -j DROP
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i ens5 -s 192.168.15.128/32 -p tcp --dport 22 -j ACCEPT
-A INPUT -i ens5 -p icmp -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.10 -p udp -m multiport --dports 500,4500 -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.10 -p esp -j ACCEPT
-A INPUT -i ens3 -s 203.0.113.10 -p gre -m policy --dir in --pol ipsec -j ACCEPT
-A INPUT -i tun0 -p ospf -j ACCEPT
-A INPUT -i tun0 -p icmp -j ACCEPT
-A INPUT -i ens4 -p icmp -j ACCEPT
-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT
-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT
-A OUTPUT -o ens3 -p gre -m policy --dir out --pol ipsec -j ACCEPT
-A OUTPUT -o ens3 -p gre -j DROP
-A FORWARD -i ens4 -o ens3 -s 10.2.20.42/32 -d 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT
COMMIT
*mangle
:FORWARD ACCEPT [0:0]
-A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
COMMIT
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.2.20.42/32 -d 203.0.113.30/32 -o ens3 -p tcp --dport 443 -j SNAT --to-source 203.0.113.20
COMMIT
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `*filter` | Начало таблицы фильтрации пакетов. |
| 2 | `:INPUT DROP [0:0]` | Объявить цепочку INPUT, политика по умолчанию DROP; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 3 | `:FORWARD DROP [0:0]` | Объявить цепочку FORWARD, политика по умолчанию DROP; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 4 | `:OUTPUT ACCEPT [0:0]` | Объявить цепочку OUTPUT, политика по умолчанию ACCEPT; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 5 | `-A INPUT -i lo -j ACCEPT` | Разрешить пакеты loopback к самому узлу. |
| 6 | `-A INPUT -i ens3 -p gre -m policy --dir in --pol none -j DROP` | Отбросить входящий GRE с WAN, не прошедший IPsec. Стоит до ESTABLISHED,RELATED, чтобы conntrack не пропустил открытый GRE. |
| 7 | `-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Разрешить пакеты уже отслеживаемых соединений и связанных потоков (например, некоторых ICMP-ошибок). В FORWARD это правило пропускает ответы сервера; оно не разрешает произвольные новые соединения. |
| 8 | `-A INPUT -i ens5 -s 192.168.15.128/32 -p tcp --dport 22 -j ACCEPT` | Разрешить SSH к шлюзу только через интерфейс управления ens5 и только от 192.168.15.128/32. |
| 9 | `-A INPUT -i ens5 -p icmp -j ACCEPT` | Разрешить ICMP к шлюзу из сети управления. |
| 10 | `-A INPUT -i ens3 -s 203.0.113.10 -p udp -m multiport --dports 500,4500 -j ACCEPT` | Разрешить UDP к самому шлюзу от WAN-IP второго шлюза: 500 для IKE, 4500 для NAT-T/IKE по UDP. multiport позволяет указать оба порта одним правилом; наличие разрешения 4500 не означает, что NAT-T фактически используется. |
| 11 | `-A INPUT -i ens3 -s 203.0.113.10 -p esp -j ACCEPT` | Разрешить ESP (IP-протокол 50) от WAN-IP второго шлюза. ESP — защищённые данные IPsec, не TCP/UDP-порт. |
| 12 | `-A INPUT -i ens3 -s 203.0.113.10 -p gre -m policy --dir in --pol ipsec -j ACCEPT` | Разрешить GRE от второго шлюза только при входящей IPsec policy; это уже защищённый/дешифрованный стеком IPsec GRE. |
| 13 | `-A INPUT -i tun0 -p ospf -j ACCEPT` | Разрешить OSPF (IP-протокол 89) к самому маршрутизатору через tun0; без этого соседство не поднимется. |
| 14 | `-A INPUT -i tun0 -p icmp -j ACCEPT` | Разрешить диагностический ICMP к самому шлюзу со стороны туннеля. |
| 15 | `-A INPUT -i ens4 -p icmp -j ACCEPT` | Разрешить диагностический ICMP к самому шлюзу из локальной LAN. |
| 16 | `-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | Разрешить пакеты уже отслеживаемых соединений и связанных потоков (например, некоторых ICMP-ошибок). В FORWARD это правило пропускает ответы сервера; оно не разрешает произвольные новые соединения. |
| 17 | `-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT` | В этом файле строка задаёт ICMP с теми же source/destination, но противоположным направлением интерфейсов. Для обычного пути в текущей топологии избыточна; это НЕ правило ответа сервера. Ответы разрешены ESTABLISHED,RELATED. Не приписывать ей функцию обратного разрешения. |
| 18 | `-A FORWARD -i tun0 -o ens4 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT` | В этом файле строка задаёт TCP к порту назначения 8080 с теми же source/destination, но противоположным направлением интерфейсов. Для обычного пути в текущей топологии избыточна; это НЕ правило ответа сервера. Ответы разрешены ESTABLISHED,RELATED. Не приписывать ей функцию обратного разрешения. |
| 19 | `-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p icmp -j ACCEPT` | Разрешить транзит ICMP из 10.2.20.0/24 к единственному серверу 10.1.50.10/32, вход и выход заданы явно. |
| 20 | `-A FORWARD -i ens4 -o tun0 -s 10.2.20.0/24 -d 10.1.50.10/32 -p tcp --dport 8080 -j ACCEPT` | Разрешить транзит TCP к порту назначения 8080 из 10.2.20.0/24 к единственному серверу 10.1.50.10/32, вход и выход заданы явно. |
| 21 | `-A OUTPUT -o ens3 -p gre -m policy --dir out --pol ipsec -j ACCEPT` | Разрешить исходящий GRE через WAN, только если к нему применяется исходящая IPsec policy. |
| 22 | `-A OUTPUT -o ens3 -p gre -j DROP` | Отбросить остальной исходящий GRE через WAN. Вместе с предыдущим правилом предотвращает открытый GRE при потере IPsec, несмотря на общий OUTPUT ACCEPT. |
| 23 | `-A FORWARD -i ens4 -o ens3 -s 10.2.20.42/32 -d 203.0.113.30/32 -p tcp --dport 443 -j ACCEPT` | Разрешить клиенту 10.2.20.42 новый TCP-поток из LAN ens4 через WAN ens3 исключительно к relay 203.0.113.30:443. Это первый TLS-переход каскада. |
| 24 | `COMMIT` | Завершить и применить текущую таблицу в формате iptables-restore. |
| 25 | `*mangle` | Начало таблицы изменения служебных параметров пакетов (здесь TCP MSS). |
| 26 | `:FORWARD ACCEPT [0:0]` | Объявить цепочку FORWARD, политика по умолчанию ACCEPT; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 27 | `-A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu` | В транзитных TCP SYN-пакетах на выходе tun0 ограничить MSS по PMTU: --tcp-flags SYN,RST SYN проверяет SYN=1 и RST=0; TCPMSS меняет объявляемый размер TCP-данных. Это не изменение MTU и не средство для ICMP/UDP. |
| 28 | `COMMIT` | Завершить и применить текущую таблицу в формате iptables-restore. |
| 29 | `*nat` | Начало таблицы NAT; здесь только отдельный выход клиента к relay. |
| 30 | `:POSTROUTING ACCEPT [0:0]` | Объявить цепочку POSTROUTING, политика по умолчанию ACCEPT; [0:0] — начальные счётчики пакетов и байтов. Политика этой таблицы не отменяет фильтрацию в других таблицах. |
| 31 | `-A POSTROUTING -s 10.2.20.42/32 -d 203.0.113.30/32 -o ens3 -p tcp --dport 443 -j SNAT --to-source 203.0.113.20` | После выбора маршрута заменить source только у TCP/443 клиента к relay на WAN-IP BR-GW 203.0.113.20; conntrack выполняет обратное преобразование ответов. Межофисный VPN под это правило не попадает. |
| 32 | `COMMIT` | Завершить и применить текущую таблицу в формате iptables-restore. |

**Если уточнят:** Два зеркальных правила FORWARD с теми же source/destination присутствуют и здесь; рабочее направление запроса на BR — ens4 → tun0. Обратные пакеты принимает ESTABLISHED,RELATED. SNAT не скрывает адрес 10.2.20.42 от HQ-SRV при обычном межофисном VPN; он применяется только к отдельному TCP/443-потоку на relay.

<a id="listing-11"></a>

## Листинг 11. BR-CLIENT: Xray

**Сказать сначала:** «Локальный SOCKS принимает запрос приложения и направляет разрешённое назначение на relay через VLESS/TLS.»

Файл: [configs/BR-CLIENT-xray.json](configs/BR-CLIENT-xray.json). Метка отчёта: `lst-br-client-xray`.

```json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "entry",
      "listen": "127.0.0.1",
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": false
      }
    }
  ],
  "outbounds": [
    {
      "tag": "next",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "203.0.113.30",
            "port": 443,
            "users": [
              {
                "id": "8d64fe98-2401-4522-a7ab-8d6f636ac301",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "relay.bks3.test",
          "minVersion": "1.3",
          "certificates": [
            {
              "usage": "verify",
              "certificateFile": "/etc/xray/ca.crt"
            }
          ]
        }
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "ip": [
          "10.1.50.10/32"
        ],
        "port": "8080",
        "network": "tcp",
        "outboundTag": "next"
      },
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
```

| Поле и значение | Что означает |
|---|---|
| `log.access = "/var/log/xray/access.log"` | Файл журнала принятых соединений; по нему проверяем переходы каскада. |
| `log.error = "/var/log/xray/error.log"` | Файл журнала ошибок Xray. |
| `log.loglevel = "warning"` | Порог warning для журнала диагностики; access log настраивается отдельно. |
| `inbounds[0].tag = "entry"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `inbounds[0].listen = "127.0.0.1"` | Адрес прослушивания: loopback клиента доступен локальным приложениям; WAN-IP серверных узлов принимает соответствующий TLS-переход. |
| `inbounds[0].port = 1080` | Локальный порт входа: 1080 — SOCKS на клиенте; 443 — VLESS/TLS на relay или HQ. |
| `inbounds[0].protocol = "socks"` | Протокол входа: socks для локального приложения; vless для межузлового прокси-перехода. |
| `inbounds[0].settings.auth = "noauth"` | SOCKS без отдельного пароля. Вход ограничен 127.0.0.1; это не открытый сетевой SOCKS-прокси. |
| `inbounds[0].settings.udp = false` | Отключить SOCKS UDP; проверяется TCP-доступ к веб-сервису. |
| `outbounds[0].tag = "next"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[0].protocol = "vless"` | Следующий прокси-переход через VLESS; его транспорт дополнительно защищён TLS. |
| `outbounds[0].settings.vnext[0].address = "203.0.113.30"` | IP следующего Xray-узла: с клиента relay .30, с relay шлюз HQ .10. Это не адрес конечного HTTP-сервера. |
| `outbounds[0].settings.vnext[0].port = 443` | Порт следующего Xray-узла — TCP/443. |
| `outbounds[0].settings.vnext[0].users[0].id = "8d64fe98-2401-4522-a7ab-8d6f636ac301"` | UUID для аутентификации на следующем VLESS-входе: окончание 301 на первом переходе, 302 на втором. |
| `outbounds[0].settings.vnext[0].users[0].encryption = "none"` | Внутреннее шифрование VLESS отключено по схеме протокола; включённый ниже TLS продолжает защищать межузловой канал. |
| `outbounds[0].streamSettings.network = "tcp"` | Транспорт Xray — TCP. Это отдельный параметр от network=tcp в правиле маршрутизации. |
| `outbounds[0].streamSettings.security = "tls"` | Включить TLS для этого межузлового соединения. |
| `outbounds[0].streamSettings.tlsSettings.serverName = "relay.bks3.test"` | Имя для TLS/SNI и проверки сертификата: relay.bks3.test либо hq.bks3.test. Соединение устанавливается к заданному IP; это имя не требует отдельного DNS-поиска для выбора того IP. |
| `outbounds[0].streamSettings.tlsSettings.minVersion = "1.3"` | Минимальная допустимая версия TLS — 1.3. |
| `outbounds[0].streamSettings.tlsSettings.certificates[0].usage = "verify"` | Режим verify: сертификат CA используется как доверенный материал для проверки сертификата удалённой стороны. |
| `outbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile = "/etc/xray/ca.crt"` | ca.crt на исходящей стороне — доверенный учебный CA; server.crt на входящей — предъявляемый сертификат данного сервера. |
| `outbounds[1].tag = "blocked"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[1].protocol = "blackhole"` | Выход, блокирующий попавшие в него соединения. |
| `routing.domainStrategy = "AsIs"` | AsIs: не выполнять дополнительное разрешение доменов ради IP-правил routing. В разрешающем правиле указан числовой IP. |
| `routing.rules[0].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[0].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[0].ip[0] = "10.1.50.10/32"` | Разрешённое конечное назначение — ровно один IPv4-адрес 10.1.50.10/32. |
| `routing.rules[0].port = "8080"` | Порт конечного назначения 8080; это не TLS-порт 443 следующего прокси. |
| `routing.rules[0].network = "tcp"` | Разрешающее правило относится только к TCP. |
| `routing.rules[0].outboundTag = "next"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |
| `routing.rules[1].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[1].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[1].outboundTag = "blocked"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |

Пустой объект `settings: {}` у blackhole означает отсутствие дополнительных настроек. Объекты `{}` и массивы `[]` объединяют поля и элементы; это не команды.

**Если уточнят:** SOCKS-адрес 127.0.0.1 существует на BR-CLIENT, не на шлюзе. TLS проверяет сервер по учебному CA и имени relay.bks3.test; UUID проверяет VLESS-клиента. Это две разные проверки.

<a id="listing-12"></a>

## Листинг 12. XRAY-RELAY: Xray

**Сказать сначала:** «Relay завершает первый TLS-переход, проверяет назначение и создаёт второй к HQ-GW.»

Файл: [configs/XRAY-RELAY-xray.json](configs/XRAY-RELAY-xray.json). Метка отчёта: `lst-xray-relay-xray`.

```json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "entry",
      "listen": "203.0.113.30",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "8d64fe98-2401-4522-a7ab-8d6f636ac301"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "minVersion": "1.3",
          "certificates": [
            {
              "certificateFile": "/etc/xray/server.crt",
              "keyFile": "/etc/xray/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "next",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "203.0.113.10",
            "port": 443,
            "users": [
              {
                "id": "8d64fe98-2401-4522-a7ab-8d6f636ac302",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "hq.bks3.test",
          "minVersion": "1.3",
          "certificates": [
            {
              "usage": "verify",
              "certificateFile": "/etc/xray/ca.crt"
            }
          ]
        }
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "ip": [
          "10.1.50.10/32"
        ],
        "port": "8080",
        "network": "tcp",
        "outboundTag": "next"
      },
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
```

| Поле и значение | Что означает |
|---|---|
| `log.access = "/var/log/xray/access.log"` | Файл журнала принятых соединений; по нему проверяем переходы каскада. |
| `log.error = "/var/log/xray/error.log"` | Файл журнала ошибок Xray. |
| `log.loglevel = "warning"` | Порог warning для журнала диагностики; access log настраивается отдельно. |
| `inbounds[0].tag = "entry"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `inbounds[0].listen = "203.0.113.30"` | Адрес прослушивания: loopback клиента доступен локальным приложениям; WAN-IP серверных узлов принимает соответствующий TLS-переход. |
| `inbounds[0].port = 443` | Локальный порт входа: 1080 — SOCKS на клиенте; 443 — VLESS/TLS на relay или HQ. |
| `inbounds[0].protocol = "vless"` | Протокол входа: socks для локального приложения; vless для межузлового прокси-перехода. |
| `inbounds[0].settings.clients[0].id = "8d64fe98-2401-4522-a7ab-8d6f636ac301"` | Разрешённый UUID клиента VLESS на этом переходе. Совпадает с id исходящего клиента предыдущего узла; не сертификат и не ключ TLS. |
| `inbounds[0].settings.decryption = "none"` | У VLESS нет собственного шифрования полезных данных в этом режиме; конфиденциальность обеспечивает security=tls. |
| `inbounds[0].streamSettings.network = "tcp"` | Транспорт Xray — TCP. Это отдельный параметр от network=tcp в правиле маршрутизации. |
| `inbounds[0].streamSettings.security = "tls"` | Включить TLS для этого межузлового соединения. |
| `inbounds[0].streamSettings.tlsSettings.minVersion = "1.3"` | Минимальная допустимая версия TLS — 1.3. |
| `inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile = "/etc/xray/server.crt"` | ca.crt на исходящей стороне — доверенный учебный CA; server.crt на входящей — предъявляемый сертификат данного сервера. |
| `inbounds[0].streamSettings.tlsSettings.certificates[0].keyFile = "/etc/xray/server.key"` | Путь к закрытому ключу TLS-сервера; содержимое ключа в отчёте отсутствует. |
| `outbounds[0].tag = "next"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[0].protocol = "vless"` | Следующий прокси-переход через VLESS; его транспорт дополнительно защищён TLS. |
| `outbounds[0].settings.vnext[0].address = "203.0.113.10"` | IP следующего Xray-узла: с клиента relay .30, с relay шлюз HQ .10. Это не адрес конечного HTTP-сервера. |
| `outbounds[0].settings.vnext[0].port = 443` | Порт следующего Xray-узла — TCP/443. |
| `outbounds[0].settings.vnext[0].users[0].id = "8d64fe98-2401-4522-a7ab-8d6f636ac302"` | UUID для аутентификации на следующем VLESS-входе: окончание 301 на первом переходе, 302 на втором. |
| `outbounds[0].settings.vnext[0].users[0].encryption = "none"` | Внутреннее шифрование VLESS отключено по схеме протокола; включённый ниже TLS продолжает защищать межузловой канал. |
| `outbounds[0].streamSettings.network = "tcp"` | Транспорт Xray — TCP. Это отдельный параметр от network=tcp в правиле маршрутизации. |
| `outbounds[0].streamSettings.security = "tls"` | Включить TLS для этого межузлового соединения. |
| `outbounds[0].streamSettings.tlsSettings.serverName = "hq.bks3.test"` | Имя для TLS/SNI и проверки сертификата: relay.bks3.test либо hq.bks3.test. Соединение устанавливается к заданному IP; это имя не требует отдельного DNS-поиска для выбора того IP. |
| `outbounds[0].streamSettings.tlsSettings.minVersion = "1.3"` | Минимальная допустимая версия TLS — 1.3. |
| `outbounds[0].streamSettings.tlsSettings.certificates[0].usage = "verify"` | Режим verify: сертификат CA используется как доверенный материал для проверки сертификата удалённой стороны. |
| `outbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile = "/etc/xray/ca.crt"` | ca.crt на исходящей стороне — доверенный учебный CA; server.crt на входящей — предъявляемый сертификат данного сервера. |
| `outbounds[1].tag = "blocked"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[1].protocol = "blackhole"` | Выход, блокирующий попавшие в него соединения. |
| `routing.domainStrategy = "AsIs"` | AsIs: не выполнять дополнительное разрешение доменов ради IP-правил routing. В разрешающем правиле указан числовой IP. |
| `routing.rules[0].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[0].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[0].ip[0] = "10.1.50.10/32"` | Разрешённое конечное назначение — ровно один IPv4-адрес 10.1.50.10/32. |
| `routing.rules[0].port = "8080"` | Порт конечного назначения 8080; это не TLS-порт 443 следующего прокси. |
| `routing.rules[0].network = "tcp"` | Разрешающее правило относится только к TCP. |
| `routing.rules[0].outboundTag = "next"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |
| `routing.rules[1].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[1].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[1].outboundTag = "blocked"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |

Пустой объект `settings: {}` у blackhole означает отсутствие дополнительных настроек. Объекты `{}` и массивы `[]` объединяют поля и элементы; это не команды.

**Если уточнят:** На relay есть два разных TLS-контекста: входящий серверный с собственным server.key и исходящий клиентский с проверкой hq.bks3.test. Relay видит назначение и завершает первый TLS-канал; это не сквозной TLS от приложения до HQ-SRV.

<a id="listing-13"></a>

## Листинг 13. HQ-GW: Xray

**Сказать сначала:** «HQ-GW завершает второй TLS-переход и открывает прямое соединение только к разрешённому серверу и порту.»

Файл: [configs/HQ-GW-xray.json](configs/HQ-GW-xray.json). Метка отчёта: `lst-hq-gw-xray`.

```json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "entry",
      "listen": "203.0.113.10",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "8d64fe98-2401-4522-a7ab-8d6f636ac302"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "minVersion": "1.3",
          "certificates": [
            {
              "certificateFile": "/etc/xray/server.crt",
              "keyFile": "/etc/xray/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "next",
      "protocol": "freedom",
      "settings": {
        "finalRules": [
          {
            "action": "allow",
            "network": "tcp",
            "ip": [
              "10.1.50.10/32"
            ],
            "port": "8080"
          },
          {
            "action": "block",
            "blockDelay": "0"
          }
        ]
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "ip": [
          "10.1.50.10/32"
        ],
        "port": "8080",
        "network": "tcp",
        "outboundTag": "next"
      },
      {
        "type": "field",
        "inboundTag": [
          "entry"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
```

| Поле и значение | Что означает |
|---|---|
| `log.access = "/var/log/xray/access.log"` | Файл журнала принятых соединений; по нему проверяем переходы каскада. |
| `log.error = "/var/log/xray/error.log"` | Файл журнала ошибок Xray. |
| `log.loglevel = "warning"` | Порог warning для журнала диагностики; access log настраивается отдельно. |
| `inbounds[0].tag = "entry"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `inbounds[0].listen = "203.0.113.10"` | Адрес прослушивания: loopback клиента доступен локальным приложениям; WAN-IP серверных узлов принимает соответствующий TLS-переход. |
| `inbounds[0].port = 443` | Локальный порт входа: 1080 — SOCKS на клиенте; 443 — VLESS/TLS на relay или HQ. |
| `inbounds[0].protocol = "vless"` | Протокол входа: socks для локального приложения; vless для межузлового прокси-перехода. |
| `inbounds[0].settings.clients[0].id = "8d64fe98-2401-4522-a7ab-8d6f636ac302"` | Разрешённый UUID клиента VLESS на этом переходе. Совпадает с id исходящего клиента предыдущего узла; не сертификат и не ключ TLS. |
| `inbounds[0].settings.decryption = "none"` | У VLESS нет собственного шифрования полезных данных в этом режиме; конфиденциальность обеспечивает security=tls. |
| `inbounds[0].streamSettings.network = "tcp"` | Транспорт Xray — TCP. Это отдельный параметр от network=tcp в правиле маршрутизации. |
| `inbounds[0].streamSettings.security = "tls"` | Включить TLS для этого межузлового соединения. |
| `inbounds[0].streamSettings.tlsSettings.minVersion = "1.3"` | Минимальная допустимая версия TLS — 1.3. |
| `inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile = "/etc/xray/server.crt"` | ca.crt на исходящей стороне — доверенный учебный CA; server.crt на входящей — предъявляемый сертификат данного сервера. |
| `inbounds[0].streamSettings.tlsSettings.certificates[0].keyFile = "/etc/xray/server.key"` | Путь к закрытому ключу TLS-сервера; содержимое ключа в отчёте отсутствует. |
| `outbounds[0].tag = "next"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[0].protocol = "freedom"` | Конечный прямой выход: HQ-GW сам открывает TCP-соединение к HQ-SRV. |
| `outbounds[0].settings.finalRules[0].action = "allow"` | allow разрешает только заданное совпадение; завершающий block запрещает остальные назначения на последнем выходе freedom. |
| `outbounds[0].settings.finalRules[0].network = "tcp"` | Ограничить конечное соединение TCP. |
| `outbounds[0].settings.finalRules[0].ip[0] = "10.1.50.10/32"` | Разрешить на конечном выходе только 10.1.50.10/32, включая явное исключение для этого частного адреса. |
| `outbounds[0].settings.finalRules[0].port = "8080"` | Разрешить на конечном выходе только порт 8080. |
| `outbounds[0].settings.finalRules[1].action = "block"` | allow разрешает только заданное совпадение; завершающий block запрещает остальные назначения на последнем выходе freedom. |
| `outbounds[0].settings.finalRules[1].blockDelay = "0"` | При блокировке не добавлять задержку (0). |
| `outbounds[1].tag = "blocked"` | Локальная метка входа/выхода для routing и журналов; не DNS-имя и не адрес узла. |
| `outbounds[1].protocol = "blackhole"` | Выход, блокирующий попавшие в него соединения. |
| `routing.domainStrategy = "AsIs"` | AsIs: не выполнять дополнительное разрешение доменов ради IP-правил routing. В разрешающем правиле указан числовой IP. |
| `routing.rules[0].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[0].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[0].ip[0] = "10.1.50.10/32"` | Разрешённое конечное назначение — ровно один IPv4-адрес 10.1.50.10/32. |
| `routing.rules[0].port = "8080"` | Порт конечного назначения 8080; это не TLS-порт 443 следующего прокси. |
| `routing.rules[0].network = "tcp"` | Разрешающее правило относится только к TCP. |
| `routing.rules[0].outboundTag = "next"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |
| `routing.rules[1].type = "field"` | Правило сопоставления полей соединения. |
| `routing.rules[1].inboundTag[0] = "entry"` | Применять правило к соединениям с входа entry. |
| `routing.rules[1].outboundTag = "blocked"` | next направляет совпавший разрешённый поток дальше; blocked отправляет остальные соединения entry в blackhole. Порядок правил существенен. |

Пустой объект `settings: {}` у blackhole означает отсутствие дополнительных настроек. Объекты `{}` и массивы `[]` объединяют поля и элементы; это не команды.

**Если уточнят:** Здесь next — метка выхода freedom, а на предыдущих узлах next — метка выхода vless: одинаковая метка не означает одинаковый протокол. После HQ-GW до HTTP-сервера данные передаются без TLS в серверной LAN. Нельзя говорить, что HTTP шифруется до самого Python-сервера.

<a id="listing-14"></a>

## Листинг 14. Служба внутреннего веб-сервиса ГО

**Сказать сначала:** «Запускаем простой HTTP-сервис на LAN-IP с ограничением прав процесса.»

Файл: [configs/HQ-SRV-web.service](configs/HQ-SRV-web.service). Метка отчёта: `lst-web-service`.

```ini
[Unit]
Description=Internal HQ web service
After=network-online.target
Wants=network-online.target
[Service]
DynamicUser=yes
User=bks3-web
WorkingDirectory=/srv/bks3
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 10.1.50.10
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
```

| Строка | Команда / директива | Объяснение |
|---|---|---|
| 1 | `[Unit]` | Общие сведения о службе и зависимости от других unit. |
| 2 | `Description=Internal HQ web service` | Человекочитаемое описание службы; на обработку пакетов не влияет. |
| 3 | `After=network-online.target` | Задаёт порядок: запускать после достижения network-online.target. Само по себе After не запускает зависимость. |
| 4 | `Wants=network-online.target` | Просит запустить цель готовности сети; это мягкая зависимость, а не гарантия доступности удалённого узла. |
| 5 | `[Service]` | Параметры запуска и окружения службы. |
| 6 | `DynamicUser=yes` | systemd выделяет временную системную учётную запись для процесса на время работы службы. |
| 7 | `User=bks3-web` | Имя пользователя веб-службы; вместе с DynamicUser это динамически выделяемая учётная запись. |
| 8 | `WorkingDirectory=/srv/bks3` | Рабочий каталог процесса; Python отдаёт файлы из этой директории, включая index.html. |
| 9 | `ExecStart=/usr/bin/python3 -m http.server 8080 --bind 10.1.50.10` | Запустить модуль стандартной библиотеки Python http.server на TCP/8080, слушать только LAN-адрес 10.1.50.10. Это HTTP без TLS. |
| 10 | `Restart=on-failure` | Перезапускать процесс при аварийном завершении; обычная остановка через systemctl stop сама его не возобновляет. |
| 11 | `NoNewPrivileges=true` | Запретить процессу и потомкам получать новые привилегии через exec, например setuid-программы. |
| 12 | `ProtectSystem=strict` | Сделать почти всю иерархию файловой системы доступной службе только для чтения; отдельные исключения и специальные файловые системы рассматриваются отдельно. |
| 13 | `ProtectHome=true` | Закрыть службе доступ к домашним каталогам пользователей. |
| 14 | `PrivateTmp=true` | Дать службе отдельное представление /tmp и /var/tmp. |
| 15 | `[Install]` | Правила включения службы в автозагрузку. |
| 16 | `WantedBy=multi-user.target` | При systemctl enable привязать службу к обычному многопользовательскому режиму загрузки. Одна эта строка enable не выполняет. |

**Если уточнят:** Служба привязана к 10.1.50.10, поэтому не слушает адрес управления. Python http.server достаточно для демонстрационного ответа; это не реализация полноценного прикладного сервиса.

<a id="listing-15"></a>

## Листинг 15. Проверка ICMP, HTTP и пути от клиента филиала

Файл: [outputs/BR-CLIENT-connectivity.txt](outputs/BR-CLIENT-connectivity.txt). Метка отчёта: `lst-connectivity`.

**Сказать сначала:** «Проверяем выбранный маршрут, ICMP, прикладной HTTP и путь через два шлюза с клиентского LAN-адреса».

| Команда | Разбор |
|---|---|
| `ip route get 10.1.50.10` | Запросить у ядра выбор маршрута к этому адресу; пакет к серверу не посылает. `via 10.2.20.1` — следующий шлюз, `dev ens3` — интерфейс клиента, `src 10.2.20.42` — выбранный source, `uid 1000` — пользователь запроса. `cache` не доказывает наличие статического маршрута. |
| `ping -I 10.2.20.42 -c 4 10.1.50.10` | Отправить 4 ICMP Echo Request; `-I` здесь задаёт исходный IP. Проверяем именно LAN-источник, а не адрес управления. |
| `curl --interface 10.2.20.42 http://10.1.50.10:8080` | Выполнить HTTP-запрос к серверу на TCP/8080, привязав соединение к указанному локальному IP. Это прямой VPN-путь, SOCKS в команде не указан. |
| `traceroute -n -I 10.1.50.10` | Посылать ICMP-пробы с растущим TTL; `-n` отключает преобразование адресов в DNS-имена, `-I` выбирает ICMP. У traceroute `-I` имеет другой смысл, чем у ping. |

В ping `icmp_seq` — номер запроса, `ttl` — оставшийся TTL ответа, `time` — RTT.
`4 transmitted, 4 received, 0% packet loss` подтверждает 4 успешных ответа; `min/avg/max/mdev`
— минимум, среднее, максимум и разброс RTT. `64 bytes` — размер ICMP-сообщения ответа,
а не полного Ethernet-кадра. Строка `BKS3: protected HQ service` подтверждает ответ приложения,
но сама по себе не доказывает шифрование — для этого есть SA и WAN-захват.

Traceroute показывает `10.2.20.1` → `172.16.0.1` → `10.1.50.10`; `*` означает отсутствие
ответа на отдельную пробу до таймаута, а не обязательно потерю всего потока.
В сохранённой команде не указаны параметры, объясняющие напечатанные `6 hops max`:
это сокращённая запись. Полная команда из сценария защиты:

```sh
traceroute -n -I -m 6 -w 1 10.1.50.10
```

`-m 6` ограничивает TTL шестью переходами, `-w 1` задаёт ожидание ответа в секундах.


<a id="listing-16"></a>

## Листинг 16. Соседство OSPF, маршруты и IPsec на шлюзе филиала

Файл: [outputs/BR-GW-routing.txt](outputs/BR-GW-routing.txt). Метка отчёта: `lst-routing`.

**Сказать сначала:** «OSPF синхронизирован, удалённая LAN получена динамически, IPsec установил защиту GRE».

| Запись / команда | Что объяснить |
|---|---|
| `vtysh -c show_ip_ospf_neighbor` в отчёте | Сокращённая некопируемая запись: у FRR команда состоит из слов с пробелами. Правильный вызов: `sudo vtysh -c 'show ip ospf neighbor'`. `vtysh` — оболочка управления FRR, `-c` выполняет одну CLI-команду и завершает работу; кавычки сохраняют её одним аргументом. |
| `ip route` | Показать IPv4-таблицу маршрутизации ядра. Для одного источника маршрутов можно использовать `ip route show proto ospf`. |
| `ipsec statusall` | Подробно показать состояние демона IKE, загруженное соединение и SA. Для доступа обычно используют `sudo ipsec statusall`. |

**Таблица соседа OSPF:** `Neighbor ID 10.1.254.254` — Router ID HQ-GW, `Address 172.16.0.1`
— его адрес в туннеле. `Full` — базы состояния каналов синхронизированы. Суффикс `DROther`
не означает ошибку и не требует выбора DR в point-to-point. `Dead Time` — оставшееся время
до признания соседа потерянным без новых Hello. `tun0:172.16.0.2` — локальный интерфейс/адрес BR.
`Pri` — приоритет для выборов DR в применимых типах сети. `RXmtL/RqstL/DBsmL` — размеры списков
повторной передачи, запросов и описания БД; нули означают отсутствие ожидающих элементов на снимке.

**Маршрут:** `10.1.50.0/26 ... via 172.16.0.1 dev tun0 proto ospf metric 20` — до серверной
LAN идём через HQ-GW по GRE, маршрут установлен OSPF. `nhid 24` — внутренний идентификатор
объекта next hop ядра, не номер узла PNETLab. `metric 20` — метрика установленного маршрута;
сама строка не объясняет её составляющие. `proto kernel scope link` — непосредственно подключённая
сеть, созданная по адресу интерфейса. `proto static` у служебного default — статический маршрут;
его наличие не делает удалённую LAN статической.

**IPsec:** `charon` — IKE-демон strongSwan; версия/ядро/uptime/память/worker threads — служебная
диагностика процесса. Список loaded plugins показывает загруженные модули, а не все одновременно
используемые алгоритмы. `Listening IP addresses` — локальные адреса; это не список разрешённых
туннельных сетей. `Connections` описывает конфигурацию; доказательство установления — раздел SA.
`1 up, 0 connecting`, `ESTABLISHED` — IKE SA существует; `INSTALLED, TRANSPORT` — CHILD/IPsec SA
установлена в ядре. IKE proposal — согласованный набор для управления; `AES_GCM_16_256` —
алгоритм защиты данных (16 байт метки, 256 бит ключа). `SPIs` — идентификаторы SA, не секретные
ключи; суффиксы `_i/_o` обозначают входящее/исходящее направление, `reqid` связывает
состояния и политики ядра. `bytes_i/bytes_o`, `pkts` — счётчики защищённого трафика, `rekeying`
— время до обновления ключевого материала. Конечные селекторы `.20/32[gre] === .10/32[gre]`
показывают защиту GRE между двумя WAN-IP. Наличие SA не заменяет проверку передачи полезных данных.


<a id="listing-17"></a>

## Листинг 17. Пакеты на WAN при защищённом обмене

Файл: [outputs/WAN-encryption.txt](outputs/WAN-encryption.txt). Метка отчёта: `lst-wan`.

**Сказать сначала:** «Смотрим трафик вне гостевых шлюзов: между WAN-адресами виден ESP, открытого GRE в этом захвате нет».

В самом листинге есть вывод tcpdump, но нет командной строки. Воспроизводимая команда из `demo-checks.md`:

```sh
sudo tcpdump -nn -i vnet8_1 'ip proto 50 or ip proto 47'
```

`sudo` — запуск с необходимыми правами; `tcpdump` — захват пакетов; `-nn` отключает
преобразование адресов и портов в имена; `-i vnet8_1` выбирает WAN-мост **на хосте PNETLab**,
а не внутри Ubuntu. Фильтр в кавычках оставляет ESP (50) и GRE (47); `or` означает «или».
Имя моста зависит от текущей сессии, его нужно сверить перед показом. Остановка — Ctrl+C.

В строках: время → внешний IP источника и назначения → `ESP` → `spi` (идентификатор SA)
→ `seq` (номер пакета данной SA) → `length` (длина ESP-части, без внешнего IP-заголовка и Ethernet-заголовка).
Два SPI соответствуют двум направлениям. SPI можно сопоставить с `ipsec statusall`.
Номера seq не обязаны совпадать между направлениями. По зашифрованному содержимому
нельзя непосредственно прочитать HTTP или адрес клиента LAN.

`link-type EN10MB` — Ethernet-захват; `capture size 262144` — максимально захватываемый размер,
а не MTU. `16 packets captured` — число записанных пакетов; `0 dropped by kernel` — отсутствие
потерь в буфере захвата, не доказательство нулевых потерь сети. Отсутствие GRE относится к месту,
фильтру и интервалу этой проверки; отрицательный тест отдельно проверяет поведение без IPsec.


<a id="listing-18"></a>

## Листинг 18. Проверка MTU туннеля

Файл: [outputs/BR-CLIENT-MTU.txt](outputs/BR-CLIENT-MTU.txt). Метка отчёта: `lst-mtu`.

**Сказать сначала:** «Проверяем прохождение внутреннего IPv4-пакета 1400 байт без фрагментации».

```sh
ping -M do -s 1372 -I 10.2.20.42 -c 3 10.1.50.10
```

| Параметр | Смысл |
|---|---|
| `-M do` | Стратегия PMTU discovery с запретом фрагментации: IPv4 DF и контроль размера по PMTU. |
| `-s 1372` | 1372 байта данных ICMP, без заголовков. |
| `-I 10.2.20.42` | Явный исходный LAN-IP. |
| `-c 3` | Три запроса. |
| `10.1.50.10` | Сервер назначения. |

1372 данных + 8 ICMP + 20 IPv4 = **1400 байт внутреннего IP-пакета**.
Поэтому ping пишет `1372(1400)`. `1380 bytes from` — ICMP-заголовок вместе с данными,
без внешнего IPv4-заголовка. На WAN GRE/IPsec добавляют накладные расходы, поэтому размер
на WAN больше 1400. Успешные 3/3 подтверждают прохождение выбранного размера;
этот тест не ищет точный максимальный MTU и не доказывает, что пакет 1401 обязательно не пройдёт.


<a id="listing-19"></a>

## Листинг 19. Разрешённый и запрещённый запросы через каскад

Файл: [outputs/BR-CLIENT-xray.txt](outputs/BR-CLIENT-xray.txt). Метка отчёта: `lst-xray-test`.

**Сказать сначала:** «Через SOCKS запрос к разрешённому сервису проходит, к другому порту — нет».

```sh
curl --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:8080
```

`--socks5-hostname` направляет запрос через SOCKS5 и передаёт разрешение имени прокси,
если в URL имя. Здесь назначение задано IP, поэтому преимущества удалённого DNS в этом тесте нет.
`127.0.0.1:1080` — локальный Xray клиента; `10.1.50.10:8080` — конечная цель, а не адрес прокси.
На межузловых участках Xray создаёт TLS-переходы, хотя URL приложения начинается с `http://`.

`curl via SOCKS to forbidden port 22` — поясняющая подпись, **не настоящая команда**.
Команда из сценария защиты:

```sh
curl --max-time 4 --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:22
```

`--max-time 4` ограничивает всю операцию четырьмя секундами. `forbidden_port_exit=52` —
сохранённый код возврата curl, где 52 означает пустой ответ сервера. Это не «код ACL 52».
Его можно получить в оболочке так: `rc=$?; printf 'forbidden_port_exit=%s\n' "$rc"`
непосредственно после curl. Сам по себе неуспешный HTTP-запрос на порт SSH не доказывает
блокировку ACL: HTTP не является протоколом SSH. Вывод рассматриваем вместе с явными
правилами Xray, разрешающими только 8080. Проверка показывает успешный разрешённый
сервис и отказ альтернативного запроса, а не полное сканирование всех запрещённых портов.


<a id="listing-20"></a>

## Листинг 20. Подтверждение двух последовательных переходов Xray

Файл: [outputs/Xray-cascade-logs.txt](outputs/Xray-cascade-logs.txt). Метка отчёта: `lst-cascade`.

**Сказать сначала:** «Оба Xray-сервера записали обработку одного назначения на двух последовательных переходах».

В листинге представлены строки access.log, а не команды. Для чтения на XRAY-RELAY и HQ-GW:

```sh
sudo tail /var/log/xray/access.log
```

`tail` показывает последние 10 строк по умолчанию; `sudo` даёт доступ к журналу.
`xray-relay` и `hq-gw` в листинге — подписи узлов.
В строке `from 203.0.113.20:52380 accepted tcp:10.1.50.10:8080 [entry -> next]`:
время — момент записи; `from` — сетевой peer текущего входящего соединения, включая временный
TCP-порт; `accepted` — запрос принят Xray; `tcp:...` — конечное назначение;
`entry -> next` — выбранные локальные метки входа и выхода.

Relay видит source `.20`, потому что BR-GW сделал SNAT первого перехода.
HQ-GW видит source `.30`, потому что второй TLS-переход создал relay. Порты 52380/44674
временные и при повторении изменятся. На relay next — VLESS-выход, на HQ-GW next — freedom.
Сами записи accepted не доказывают доставку полного HTTP-ответа; это подтверждает curl.
Одинаковое назначение, близкое время и разные peer согласуются с конфигурацией каскада.


<a id="listing-21"></a>

## Листинг 21. Отказ IPsec и промежуточного прокси с последующим восстановлением

Файл: [outputs/failure-tests.txt](outputs/failure-tests.txt). Метка отчёта: `lst-failure`.

**Сказать сначала:** «Проверяем отказ без утечки открытого GRE, удаление OSPF-маршрута и восстановление обоих способов доступа».

Префиксы `BR-GW:`, `BR-CLIENT:` и `XRAY-RELAY:` обозначают место выполнения — их не вводят
в терминал. Команды остановки уже выполнялись при формировании протокола; справка их заново
не запускала. На защите согласовать краткий отказ с работающими в общей сессии.

| Команда / запись | Разбор и ожидаемый смысл |
|---|---|
| BR-GW: `sudo systemctl stop strongswan-starter` | Остановить службу IKE/IPsec. `systemctl` управляет systemd, stop останавливает сейчас, но не отключает автозагрузку. GRE-интерфейс может остаться up, хотя защищённой доставки больше нет. |
| BR-CLIENT: `ping -c 3 -W 1 10.1.50.10` | Три ICMP-пробы; `-W 1` — ожидание ответа в секундах. 100% потерь здесь ожидаемы. |
| BR-GW: `ip route show proto ospf` | Показать только маршруты, установленные OSPF. После истечения dead timer вывод пуст: соседство утрачено и удалённая LAN отозвана. |
| Захват с `0 packets captured` | В отчёте нет команды/фильтра этого отрицательного захвата; по описанию проверяли отсутствие открытого GRE. Без сведений о фильтре нельзя утверждать отсутствие вообще всех пакетов на WAN. Для отдельной проверки GRE пригоден tcpdump с фильтром `ip proto 47` на WAN-мосту. |
| BR-GW: `sudo systemctl start strongswan-starter` | Запустить IPsec, дождаться SA и Full, затем снова проверить ping. |
| `ping after IPsec restore` | Поясняющая подпись. Выполняем `ping -c 3 -W 1 10.1.50.10`; в сохранённом результате 3/3 ответа. |
| XRAY-RELAY: `sudo systemctl stop xray` | Остановить промежуточный процесс; оба шлюза VPN при этом не останавливаются. |
| `curl via SOCKS while relay stopped` | Подпись для запроса через локальный SOCKS; использовать полную команду ниже. `curl_exit=56` — ошибка получения данных, здесь reset peer. Код не является специальным кодом отказа relay. |
| XRAY-RELAY: `sudo systemctl start xray` | Запустить relay обратно. Затем тот же SOCKS-запрос снова возвращает строку сервиса. |

Полная команда для сравнения до/во время/после отказа relay:

```sh
curl --max-time 8 --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:8080
```

Отсутствие маршрута не заменяет запрет открытого GRE: между остановкой IPsec и истечением
OSPF dead timer маршрут ещё может существовать. Именно OUTPUT-пара ipsec ACCEPT / GRE DROP
защищает этот промежуток. После демонстрации обе остановленные службы нужно вернуть,
проверить Full, ping и HTTP. `stop_lab` к этому тесту отношения не имеет.


<a id="listing-22"></a>

## Листинг 22. Проверка служб и передачи данных после перезагрузки

Файл: [outputs/after-reboot.txt](outputs/after-reboot.txt). Метка отчёта: `lst-reboot`.

**Сказать сначала:** «После перезагрузки службы поднимаются автоматически, маршруты и оба HTTP-пути восстанавливаются».

В листинге сохранены результаты без исходных команд и без подписей каждой строки active.
По одному этому файлу нельзя достоверно приписать каждой из пяти строк active конкретную службу.
Ниже — команды для понятного повторного чтения состояния; это не утверждение, что именно
так была набрана каждая исходная строка.

| Команда | Что означает |
|---|---|
| `hostname` | Имя узла; связываем вывод с подписью NODE и адресом управления. |
| `uptime -p` | Время работы ОС после загрузки в читаемом формате: up 1 minute / up 3 minutes. |
| `systemctl is-active ИМЯ_СЛУЖБЫ` | Показать текущее состояние одной службы; active — активна. Для oneshot GRE это может быть active/exited, что не гарантирует доставку пакетов. |
| `systemctl is-enabled ИМЯ_СЛУЖБЫ` | Отдельно проверить подключение к автозагрузке: состояние active не тождественно enabled. Эти проверки не напечатаны в исходном листинге. |
| `sudo vtysh -c 'show ip ospf neighbor'` | Снова проверить Full после загрузки. |
| `ip route show proto ospf` | Проверить появление удалённой LAN через tun0. В сохранённых строках маршрутов proto не напечатан, поэтому сам фрагмент без команды не доказывает источник; сопоставляем с FRR и листингом 16. |
| `ping -c 3 10.1.50.10` на клиенте | Проверить 3/3 ICMP-ответа после загрузки. |
| `curl --interface 10.2.20.42 http://10.1.50.10:8080` | Проверить прямой путь через VPN. |
| `curl --socks5-hostname 127.0.0.1:1080 http://10.1.50.10:8080` | Проверить прокси-каскад. Две одинаковые строки ответа в протоколе относятся к двум способам доступа согласно описанию отчёта. |

Какие службы разумно проверять по именам: HQ-GW — `bks3-gre`, `strongswan-starter`, `frr`,
`netfilter-persistent`, `xray`; BR-GW — первые четыре; HQ-SRV — `bks3-web`;
BR-CLIENT — `xray`; XRAY-RELAY — `xray`, `bks3-firewall`.
NODE `.211` — HQ-GW, `.212` — BR-GW, `.213` — HQ-SRV, `.214` — клиент, `.215` — relay.
Перезагрузки на защите для простого чтения состояния не нужны.


## Общий словарь iptables — если просят разобрать каждый флаг

| Запись | Значение |
|---|---|
| `-A ЦЕПОЧКА` | Добавить правило в конец указанной цепочки. В rules.v4 это строки входного формата iptables-restore. |
| `-i`, `-o` | Входящий и исходящий интерфейсы. |
| `-s`, `-d` | IP/подсеть источника и назначения. `/32` — один IPv4-адрес, `/24` — сеть из 256 адресов. |
| `-p tcp/udp/icmp/gre/esp/ospf` | Протокол; GRE, ESP и OSPF не имеют TCP/UDP-портов. |
| `--dport`, `--dports` | Порт назначения / несколько портов назначения; multiport подключает соответствующее расширение. |
| `-m conntrack` | Сопоставление по состоянию отслеживаемого соединения. |
| `-m policy --dir in/out --pol ipsec/none` | Проверка входящей/исходящей политики IPsec либо её отсутствия. |
| `-j ACCEPT` | Разрешить в этой цепочке/таблице; последующая обработка другим hook/таблицей всё ещё возможна. |
| `-j DROP` | Молча отбросить пакет, не отправляя reject-ответ. |
| `-j SNAT --to-source IP` | Изменить исходный адрес на заданный; используется в POSTROUTING таблицы nat. |
| `COMMIT` | Завершитель таблицы iptables-restore, не команда оболочки. |

## Команды установки — дополнительная справка к файлам commands/

Они не включены отдельными листингами в текущий main.typ, но объясняют, как файлы попали
в систему. Ниже покрыты скрипты установки шлюзов и общие операции Xray/сервиса.

| Команда | Объяснение |
|---|---|
| `#!/bin/bash` | Интерпретатор для запуска скрипта как исполняемого файла. |
| `set -euo pipefail` | Завершаться при обычной необработанной ошибке команды, обращении к незаданной переменной и ошибке элемента pipeline; у `-e` есть исключения в условиях/списках оболочки. |
| `cd /tmp/bks3/configs` | Перейти в каталог доставленных конфигураций. Это путь внутри настраиваемой VM. |
| `install -m 644 SRC DST` | Скопировать файл с правами rw-r--r--; используется для конфигов без секретов и unit-файлов. |
| `install -o frr -g frr -m 640 ...` | Скопировать FRR-конфиг, назначить владельца/группу frr, права rw-r-----. |
| `install -m 600 ...` | Доступ на чтение/запись только владельцу; так сохраняется rules.v4. PSK хранится отдельно с такими же правами. |
| `sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons` | Изменить файл на месте: строку, начинающуюся с ospfd=, заменить на ospfd=yes, включив запуск OSPF-демона. |
| `iptables-restore < /etc/iptables/rules.v4` | Передать файл правил на стандартный ввод утилиты и загрузить таблицы в ядро. `<` — перенаправление оболочки. |
| `systemctl daemon-reload` | Перечитать unit-файлы systemd. Не перезапускает службы и не перечитывает автоматически FRR/Xray-конфиги. |
| `systemctl enable --now ...` | Подключить службы к автозагрузке и сразу запустить. |
| `systemctl restart strongswan-starter frr` | Остановить/запустить указанные службы, чтобы они прочли конфигурации. |
| `name=$1` | Взять имя узла из первого аргумента xray-install.sh; подставить его в имя JSON-файла. |
| `id xray >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin xray` | Проверить наличие пользователя; скрыть stdout/stderr проверки; при отсутствии создать системную учётную запись без домашнего каталога и интерактивного shell. `||` — выполнить правую часть при неуспехе левой. |
| `install -m 755 ... /usr/local/bin/xray` | Установить исполняемый файл: владелец rwx, остальные r-x. |
| `install -d -o root -g xray -m 750 /etc/xray` | Создать каталог root:xray; root имеет rwx, группа r-x, остальные доступа не имеют. |
| `install -d -o xray -g xray -m 750 /var/log/xray` | Создать доступный для записи процессом каталог журналов. |
| `install -o root -g xray -m 640 ... /etc/xray/config.json` | Дать группе службы чтение конфига, оставив запись владельцу root. |
| `chown -R xray:xray /var/log/xray` | Рекурсивно назначить владельца/группу каталогу журналов и содержимому. |
| `runuser -u xray -- /usr/local/bin/xray run -test -config /etc/xray/config.json` | Проверить Xray-конфиг от того же пользователя, который будет запускать службу; `--` отделяет опции runuser от команды. `-test` проверяет конфигурацию без обычной работы прокси. |
| `install -d -m 755 /srv/bks3` | Создать каталог файлов веб-сервиса. |
| `printf 'BKS3: protected HQ service\n' > /srv/bks3/index.html` | Записать тестовый ответ в index.html; `>` заменяет содержимое файла. |
| `cat > ... <<'EOF'` | Записать многострочный unit-файл до строки EOF; кавычки у ограничителя отключают подстановки оболочки в теле. |
| `chmod 600 /etc/netplan/50-cloud-init.yaml` | Ограничить права конфигурационного файла владельцем. |
| `ip route replace 203.0.113.0/24 via 10.2.20.1 dev ens3` | На BR-CLIENT немедленно создать/заменить маршрут к WAN каскада через LAN-шлюз. Предшествующий Python-код добавляет тот же маршрут в YAML для сохранения после загрузки. |
| `iptables -P INPUT DROP`, `iptables -P FORWARD DROP` | На relay задать политики запрета по умолчанию; -P меняет политику, в отличие от -A. |
| `iptables-save > /etc/bks3-firewall.v4` | Выгрузить текущие правила relay в файл для восстановления при загрузке. |
| `systemctl enable bks3-firewall` | Включить восстановление FW в автозагрузку; без --now команда сама немедленно службу не запускает. В скрипте правила уже применены командами iptables. |

В Python-фрагменте `BR-CLIENT-route.sh`: `yaml.safe_load` читает YAML; обращение
`d['network']['ethernets']['ens3']` выбирает LAN-интерфейс; `setdefault('routes', [])`
создаёт список маршрутов при его отсутствии; `entry` описывает сеть/next hop;
проверка `if entry not in r` не даёт добавить точный дубликат; `append` добавляет маршрут;
`yaml.safe_dump` сохраняет YAML. Здесь изменяется конфигурация, а `ip route replace`
ниже применяет маршрут в текущем ядре без перезапуска всей сети.

В unit relay `Before=xray.service` задаёт порядок до Xray, `After=network-pre.target`
— после указанной сетевой цели. `ExecStart=/bin/sh -c '... < ...'` использует shell,
потому что перенаправление `<` не выполняется systemd автоматически как синтаксис оболочки.

### Сопутствующие параметры, на которые могут сослаться при защите

| Параметр | Объяснение |
|---|---|
| `net.ipv4.ip_forward=1` | Разрешить ядру шлюза пересылать IPv4-пакеты между интерфейсами. Без этого одних маршрутов и FORWARD ACCEPT недостаточно. |
| `net.ipv4.conf.all.rp_filter=0`, `default.rp_filter=0` | Отключить проверку обратного маршрута глобально/по умолчанию; отдельно для tun0 параметр задаётся в GRE-службе. |
| `User=xray`, `Group=xray` | Запускать прокси с правами отдельного системного пользователя/группы. |
| `AmbientCapabilities=CAP_NET_BIND_SERVICE` | Дать непривилегированному процессу возможность слушать порты ниже 1024, здесь 443. |
| `ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json` | Запустить Xray с заданным JSON-конфигом. |
| `RestartSec=3` | Задержка 3 секунды перед автоматическим перезапуском при сбое. |
| `ReadWritePaths=/var/log/xray` | Исключение для записи журналов при ProtectSystem=strict. |

## Вопросы с подвохом — короткие ответы

- **Почему GRE и IPsec сразу?** GRE даёт интерфейс для IP/multicast и OSPF, IPsec защищает его на WAN.
- **Почему transport, если это Site-to-Site VPN?** Site-to-Site — роль решения; transport — режим IPsec. Внутреннюю туннельную инкапсуляцию уже обеспечивает GRE.
- **Почему 47, 50 и 89 — не порты?** Это номера IP-протоколов GRE, ESP и OSPF. Порты 500/4500 относятся к UDP, 443/8080 — к TCP в наших правилах.
- **Почему нет NAT между LAN?** Подсети не пересекаются, маршруты распространяет OSPF; исходный адрес клиента сохраняется. SNAT к relay — другой поток.
- **Есть ли резервирование в практическом каскаде?** Нет, это два последовательных звена. Второй ЦОД и SD-WAN остаются архитектурным проектом.
- **Доказывает ли active, что VPN работает?** Нет. Нужны Full, маршрут, SA, обмен данными и внешний захват.
- **Что за две лишние строки FW?** Зеркальные направления с прежними source/destination не являются разрешением ответов. Ответы принимает conntrack; объясняем фактическое действие строк.
- **Зачем TLS, если encryption=none?** none относится к уровню VLESS; TLS включён отдельно в streamSettings и защищает каждый межузловой переход.
- **Кто видит HTTP?** Прокси-узлы завершают свои TLS-сессии; конечное плечо HQ-GW → HQ-SRV — HTTP без TLS. Каскад не даёт сквозного шифрования до Python-сервера.
- **Что доказывает отказ порта 22?** Отказ именно проверенного запроса; политику назначения подтверждает конфигурация. HTTP на SSH-порту сам по себе слабый тест ACL.
- **Доказывает 1400 точный MTU пути?** Нет, только успешное прохождение выбранного размера без фрагментации внутреннего IPv4-пакета.

## Документация для уточнения терминов

Справка опирается прежде всего на файлы данного стенда. Спорные параметры проверены по документации;
актуальная документация новых версий может содержать дополнительные поля, которых нет в наших файлах.

- [Netplan: YAML](https://netplan.readthedocs.io/en/stable/netplan-yaml/) — адреса, DNS и маршруты.
- [Ubuntu 22.04: ipsec.conf, strongSwan 5.9.5](https://manpages.ubuntu.com/manpages/jammy/man5/ipsec.conf.5.html) — синтаксис используемого starter, lifetime, DPD и предложения алгоритмов.
- [FRRouting: OSPFv2](https://docs.frrouting.org/en/latest/ospfd.html) — passive-интерфейсы, тип сети и команды просмотра.
- [Netfilter: iptables](https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO-7.html) — цепочки и сопоставление правил.
- [systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) — oneshot, ExecStart и перезапуск.
- [Project X: transport](https://xtls.github.io/en/config/transport.html) и [freedom](https://xtls.github.io/en/config/outbounds/freedom.html) — транспорт, TLS и конечные ограничения finalRules.

Для поля length в строке ESP: [исходный код tcpdump, print-esp.c](https://github.com/the-tcpdump-group/tcpdump/blob/master/print-esp.c).
