#import "@local/mephi-lab:0.1.0": lab-report
#show: lab-report.with(lab-number: 4, topic: "Установка и конфигурирование комплексных аппаратно-программных межсетевых экранов (UTM/NGFW)", discipline: "Безопасность компьютерных сетей", student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."), group: "Б23-505", teacher: "Басыня Е. А.")
#let listing(caption, body) = figure({
  show raw: set text(size: 8.5pt)
  raw(body.trim().split("\n").map(line => line.clusters().chunks(88).map(x => x.join("")).join("\n")).join("\n"), block: true)
}, caption: caption, kind: raw)
#show figure.where(kind: raw): set block(breakable: false)
#let names(v) = if v == none { "-" } else if v.len() == 0 { "любой" } else { v.join(", ") }
#let first-lines(file, n) = { let lines = read(file).split("\n"); lines.slice(0, calc.min(n, lines.len())).join("\n") }
#import "terminal-heights.typ": terminal-heights
#let terminal(file, caption) = figure(layout(size => box(
  width: size.width, height: size.width * terminal-heights.at(file), clip: true,
  align(top + left, image(file, width: size.width, height: size.width * 600 / 1024))
)), caption: caption)

= Цель работы
Развернуть Kerio Control и «Континент 4», настроить межсетевое экранирование, NAT, защитные модули и мониторинг, провести испытания и сравнить платформы. Вариант 6: опубликовать веб-сервер DMZ, запретить мессенджеры и файлообменные приложения группе «Гости», настроить GeoIP и сравнить доступ при включённом и выключенном ограничении.

= Характеристика платформ и критерии сравнения
Kerio Control объединяет межсетевой экран, NAT, антивирус, IPS и контроль приложений в одном веб-интерфейсе. «Континент 4» использует центр управления сетью (ЦУС), узел безопасности и Менеджер конфигурации на Windows; политика передаётся на узел отдельной задачей установки. Сравнение выполняется по надёжности, информационной безопасности, быстродействию и трудоёмкости сопровождения.

= Топология стенда и адресация
Стенд развёрнут в PNETLab и разделён на WAN, LAN, DMZ и Management. Обе платформы используют одинаковые адреса интерфейсов и одни и те же тестовые машины, поэтому включаются поочерёдно. Схема приведена на рисунке @fig-topology, адресация - в таблице @tab-addressing.
#figure(image("img/topology.svg", width: 100%), caption: [Схема стенда и принятая адресация]) <fig-topology>
#figure(table(columns: (1.1fr, 1.3fr, 1.9fr), align: left,
table.header([Узел], [Рабочий адрес], [Назначение и параметры ВМ]),
[KERIO], [192.168.100.2 / 10.1.10.1 / 10.1.50.1 / 10.1.99.1], [Kerio Control 10.0.1 build 9439, 2 vCPU, 4 ГиБ, virtio-net],
[CONTINENT], [те же адреса на te-0-0…te-3-0], [«Континент 4.2.1-653», узел безопасности с ЦУС, 2 vCPU, 8 ГиБ, vmxnet3],
[LAN-CLIENT], [10.1.10.42/24], [Клиент LAN (labguest), Ubuntu 22.04, 1 vCPU, 1 ГиБ],
[DMZ-WEB], [10.1.50.10/26], [Ubuntu 22.04, 1 vCPU, 1 ГиБ; nginx HTTP/HTTPS, контрольный файл и EICAR],
[WAN-TEST], [192.168.100.1/24], [Ubuntu 22.04, 1 vCPU, 1 ГиБ; NAT наружу, DNS/NTP, веб-сервер, IRC и BitTorrent],
[ADMIN-LINUX], [10.1.99.10/24], [Ubuntu 22.04, 1 vCPU, 3 ГиБ; syslog, SNMP-приёмник, ICAP/ClamAV],
[ADMIN-WIN], [10.1.99.20/24], [Windows Server 2019, 2 vCPU, 4 ГиБ; Менеджер конфигурации, CSP],
), caption: [Адресация и параметры виртуальных машин]) <tab-addressing>
Проверяемый трафик проходит между сегментами через NGFW; служебные OOB-интерфейсы используются для обслуживания ВМ. В DMZ выделена подсеть /26 на 62 адреса.

Через Kerio оба ping-пакета до шлюза получили ответ, TCP-traceroute достиг сервера DMZ (листинг @lst-connectivity).
#listing([Связность LAN при работе Kerio], read("outputs/kerio-connectivity-lan.txt").split("\n").filter(x => not x.starts-with("2026-")).join("\n")) <lst-connectivity>
При работе через «Континент» ping до шлюза не получил ответа, но TCP-traceroute достиг 10.1.50.10 (листинг @lst-c-connectivity). Доступность сервера также подтверждена HTTP-запросом.
#listing([Проверка связности LAN при работе «Континента»], read("outputs/continent-connectivity-lan.txt").split("\n").filter(x => not x.starts-with("2026-")).join("\n")) <lst-c-connectivity>

= Установка и базовая настройка
«Континент» развёрнут как узел безопасности с ЦУС. Для управления на ADMIN-WIN установлены Менеджер конфигурации и CSP; учебная лицензия показана на рисунке @fig-c4-license.
#figure(image("img/continent-license.png", width: 100%), caption: [Лицензия и интерфейс управления «Континента»]) <fig-c4-license>

Версии и лицензии сведены в таблицу @tab-versions. Журнал ЦУС зафиксировал успешный импорт базы IPS «Континента» в 19:33 МСК.
#block(breakable: false)[
#set text(size: 10pt)
#figure(table(columns: (1fr, 1.5fr, 1fr, 2.3fr), align: left,
table.header([Платформа], [Версия], [Лицензия], [Базы сигнатур]),
[Kerio Control], [10.0.1 build 9439], [Пробная, активна, 25 пользователей], [AV 10903722; IPS 5.150/2.3546. Обновление: 13.11.2026],
[«Континент»], [4.2.1-653], [Учебная, активна], [IPS 4.2.1.53. Выпуск 18.04.2025, импорт 06.11.2026],
), caption: [Версии платформ, лицензии и обновление баз]) <tab-versions>
]

Пароли по умолчанию заменены, настроен NTP 192.168.100.1. Управление разрешено из Management: TCP 4081 для Kerio и TCP 444 для ЦУС.


= Политика безопасности
== Правила «Континента»
Политика строится на сетевых объектах (BKS4_LAN, BKS4_DMZ, BKS4_MGMT, BKS4_WAN_PUBLIC, BKS4_DMZ_WEB, BKS4_WAN_TEST), сервисах и группах пользователей. Итоговый порядок правил межсетевого экрана приведён в таблице @tab-c4-fw, NAT - в таблице @tab-c4-nat. Последнее правило запрещает остальной трафик с журналированием; все разрешающие правила передают трафик в СОВ (`passips`), кроме исключения для ложного срабатывания.
#let c4fw = json("configs/continent-firewall-policy.json")
#figure({set text(size: 7pt); table(columns: (0.3fr, 2fr, 0.6fr, 1.5fr, 1.4fr, 2fr, 1.6fr), align: left,
table.header([№], [Правило], [Действие], [Источник], [Назначение], [Сервис], [Приложения / профиль]),
..c4fw.enumerate().map(((i, r)) => ([#(i + 1)], [#r.name], [#r.rule_action], [#(if r.is_inverse_src { "не " } else { "" })#names(r.src)], [#names(r.dst)], [#names(r.service)], [#names(r.applications)#(if r.at("app_profile", default: none) != none and r.app_profile.len() > 0 { " / " + r.app_profile.join(", ") } else { "" })])).flatten())},
caption: [Правила межсетевого экрана «Континента» в порядке обработки]) <tab-c4-fw>
#let c4nat = json("configs/continent-nat-policy.json")
#figure({set text(size: 8pt); table(columns: (0.3fr, 2fr, 1fr, 1.8fr, 1.8fr, 2fr), align: left,
table.header([№], [Правило], [Тип], [Источник], [Назначение], [Трансляция]),
..c4nat.map(r => ([#r.order], [#r.name], [#r.nat_type], [#names(r.at("src", default: ()))], [#names(r.at("dst", default: ()))], [#(if r.nat_type == "dnat" { r.value.ip + ":" + r.port_value.dst } else if r.nat_type == "masquerade" { "адрес WAN 192.168.100.2" } else { "без трансляции" })])).flatten())},
caption: [Правила NAT «Континента»]) <tab-c4-nat>
Внутренние сети обмениваются трафиком без NAT. LAN и Management используют SNAT; публикация 8080/8443 переводится в 80/443 DMZ-сервера. Правила HTTP с антивирусным профилем и явный запрет остальных сервисов LAN→DMZ стоят выше гостевого DPI.

== Правила Kerio Control
Политика Kerio задаётся таблицей правил с интерфейсными и адресными объектами; трансляции встроены в правила (DNAT в правилах публикации, SNAT в правилах выхода). Итоговая политика приведена в таблице @tab-kerio-fw; правило по умолчанию - Drop с журналированием.
#let kpol = json("configs/kerio-traffic-policy.json")
#let mask-prefix(mask) = if mask == "255.255.255.0" { "24" } else if mask == "255.255.255.192" { "26" } else { mask }
#let kent(e) = if e.type == "RuleAny" { "любой" } else if e.at("firewall", default: false) { "Firewall" } else { e.entities.map(x => if x.type == "TrafficEntityInterface" { if x.interfaceCondition.type == "InterfaceInternet" { "WAN" } else { x.interfaceCondition.type } } else if x.type == "TrafficEntityNetwork" { x.addr1 + "/" + mask-prefix(x.addr2) } else { x.host }).join(", ") }
#let ksvc(sv) = if sv.type == "RuleAny" { "любой" } else { sv.entries.map(x => if x.definedService { x.service.name } else { str(x.protocol) + ":" + (if x.port.ports.len() > 0 { x.port.ports.map(str).join(",") } else { "*" }) }).join("; ") }
#let knat(r) = if r.enableDestinationNat { "DNAT → " + r.translatedHost + ":" + str(r.translatedPort.value) } else if r.enableSourceNat { "SNAT" } else { "-" }
#figure({set text(size: 7.5pt); table(columns: (0.3fr, 2fr, 0.7fr, 1.9fr, 1.2fr, 1.5fr, 1.2fr), align: left,
table.header([№], [Правило], [Действие], [Источник], [Назначение], [Сервис], [Трансляция]),
..kpol.rules.enumerate().map(((i, r)) => ([#(i + 1)], [#r.name], [#r.action], [#kent(r.source)], [#kent(r.destination)], [#ksvc(r.service)], [#knat(r)])).flatten(),
[-], [Block other communication], [Drop], [любой], [любой], [любой], [-])},
caption: [Правила Kerio Control в порядке обработки (6 = TCP, 17 = UDP)]) <tab-kerio-fw>
В Kerio фильтрация и NAT объединены в строках одной таблицы, в «Континенте» таблицы разделены. Обработка идёт сверху вниз; завершающее правило запрещает прочий трафик. Разрешены необходимые HTTP/HTTPS/DNS/NTP, публикации DMZ и управление из Management; DMZ→LAN запрещён.

= Настройка защитных модулей
== Антивирус
На «Континенте» профиль BKS4-HTTP-AV использует ICAP 10.1.99.10:1344 (RESPMOD, fail-closed) с c-icap/ClamAV. Он назначен HTTP-правилам LAN и Management. В Kerio включён встроенный антивирус и HTTP-сканирование (рисунок @fig-k-av-config).
#figure(image("img/kerio-webadmin-av.png", width: 100%), caption: [Kerio: параметры встроенного антивируса]) <fig-k-av-config>
EICAR и ZIP по HTTP блокируются на обеих платформах: «Континент» возвращает 403, Kerio сбрасывает соединение с нулевым телом и записывает EICAR-Test-File. По HTTPS передаются 68 байт исходного файла: без TLS-инспекции содержимое зашифровано. Домен может учитываться по SNI, если клиент передаёт его в открытом виде. Клиентские результаты показаны на рисунках @fig-c-av и @fig-k-av; антивирусное событие Kerio - на рисунке @fig-k-av-event.

== Группы и контроль приложений
В «Континенте» labguest и lab-admin входят через портал auth.bks4.test и принадлежат группам Guests и Administrators. Правило BKS4-Guests-Block-Messengers-P2P включает категории Chat/FileSharing и приложения IRC, Jabber, BitTorrent. Правило Administrators расположено выше гостевого запрета.
В Kerio созданы те же роли; автоматическая идентификация привязана к 10.1.10.42 и 10.1.99.10. AppID включён. ContentFilter запрещает гостям 88 идентификаторов из категорий Chat, InstantMessenger, Peer-to-Peer, FileTransfer и TextMessagingSMS; исключение Administrators стоит первым. Тестовые пользователи имеют только права доступа к сети.
Проверка выполняет IRC-регистрацию обычным сетевым клиентом nc и загрузку контрольного файла клиентом Transmission. На стандартном и нестандартном портах гость не получает доступ, а администратор регистрируется в IRC и скачивает файл (рисунки @fig-k-irc-admin - @fig-c-irc-guest и @fig-k-app-event).

== IDS/IPS
«Континент»: профиль BKS4-IDS-Alert, HOME_NET 10.1.50.0/26. После этапа обнаружения в режим drop переведены веб-сигнатуры 4109359/4149401/4106447/4111038/4110964 и пользовательские правила 3900001 (SYN-поток),3900002 (SYN-сканирование),3900003 (XMAS). Остальной набор - 6794 сигнатуры alert.
В режиме обнаружения «Континент» зарегистрировал сигнатуры 4109359 и 4149401 с действием allowed (таблица @tab-c4-detection). После перевода в предотвращение тестовые воздействия блокируются; соответствующие записи приведены на рисунке @fig-c-ips-event.
#let ids-detection = read("outputs/continent-ids-events.txt").trim().split("\n").slice(0, 2).map(x => json(bytes(x)))
#block(breakable: false)[
#figure(table(columns: (1fr, 1.5fr, 1.5fr, 1fr), align: left,
table.header([SID], [Источник], [Назначение], [Действие]),
..ids-detection.map(e => ([#e.signature_id], [#e.src_ip:#e.src_port], [#e.dest_ip:#e.dest_port], [#e.action])).flatten()
), caption: [События СОВ «Континента» в режиме обнаружения]) <tab-c4-detection>
]

Kerio: IPS включён, High/Medium/Low работают в Log and drop (рисунок @fig-k-ips-config). Для сравнения режимов использовалось SSH-сканирование: в Log соединение разрешалось с записью Alert, в Log and drop блокировалось. Результаты приведены в разделе тестирования.
#figure(image("img/kerio-webadmin-ips.png", width: 100%), caption: [Kerio: режим предотвращения и версия базы IPS]) <fig-k-ips-config>

== Ложные срабатывания и исключения
В «Континенте» легитимный запрос документации `/docs?topic=/etc/passwd` блокировался SID 4149401. Исключение BKS4-Admin-Docs-IPS-Exception задаёт 10.1.99.10→192.168.100.2:8080 с обходом IPS: после него администратор получает 200, WAN продолжает блокироваться. В Kerio IRC на 16667 вызвал SID 1:2000345; этот SID добавлен в глобальные исключения, после чего IRC администратора проходит, а гостевой DPI сохраняет запрет. Также исключены информационные curl-сигнатуры 1:2002825 и 1:2013028.
Результат исключения «Континента» показан в таблице @tab-docs-exception: доверенный администратор получает страницу, а тот же запрос из WAN остаётся заблокированным.
#block(breakable: false)[
#figure(table(columns: (2fr, 1fr, 1.7fr), align: left,
table.header([Проверка], [HTTP], [Результат]),
[До исключения: запрос документации], [000], [Таймаут],
[После исключения: Management], [200], [Страница доступна],
[После исключения: WAN], [000], [Таймаут],
), caption: [Доступ к документации до и после исключения IPS]) <tab-docs-exception>
]

В Kerio исключение SID 1:2000345 устранило блокировку легитимной IRC-регистрации администратора. Гостевой запрет контроля приложений остался включён. Без исключения IPS нарушал работу легитимного сервиса: блокировал документацию или IRC-регистрацию администратора. Проверки обеих групп приведены на рисунках @fig-k-irc-admin и @fig-k-irc-guest. Исключение ограничено одной сигнатурой; в «Континенте» оно ограничено адресом администратора и сервисом публикации.

= Результаты тестирования
Проверки выполнены с рабочих адресов LAN-CLIENT, WAN-TEST, DMZ-WEB и ADMIN-LINUX. Для обеих платформ использовались одинаковые сервисы и тестовые файлы. Результаты сведены в таблицу @tab-tests; в скобках указаны номера рисунков.

#figure({set text(size: 8.5pt); table(columns: (0.3fr, 1.4fr, 2.8fr, 2.8fr), align: left,
table.header([№], [Проверка], [Kerio Control], [«Континент»]),
[1], [LAN → WAN и SNAT], [HTTP 200; на WAN-TEST виден источник 192.168.100.2 (@fig-k-lan, @fig-k-nat)], [HTTP 200; журнал содержит SNAT адреса LAN (@fig-c-lan, @fig-c-nat-log)],
[2], [Публикация DMZ], [HTTP/HTTPS доступны на 8080/8443; правило публикации указано в журнале (@fig-k-wan, @fig-k-paths-log)], [HTTP/HTTPS доступны; журнал показывает DNAT в 10.1.50.10:80 (@fig-c-wan, @fig-c-nat-log)],
[3], [DMZ → LAN], [SSH завершается по таймауту; DROP правила изоляции (@fig-k-dmz, @fig-isolation-log)], [SSH завершается по таймауту; action=blocked (@fig-c-dmz, @fig-isolation-log)],
[4], [Антивирус], [EICAR/ZIP: сброс соединения, 0 байт; EICAR в журнале (@fig-k-av, @fig-k-av-event)], [EICAR/ZIP: HTTP 403; обнаружение ClamAV (@fig-c-av, @fig-c-av-event)],
[5], [Фильтрация по категориям], [Вариант 6 задаёт категории приложений общения и передачи файлов; гостевой запрет проверен в тесте 7], [Вариант 6 задаёт Chat/FileSharing; отдельный запрет URL-категории не задан],
[6], [Исключение администратора], [IRC-регистрация и обе загрузки разрешены (@fig-k-irc-admin, @fig-k-bt-hashes); запись пользователя показана на рисунке @fig-admins-log], [IRC-регистрация и обе загрузки разрешены (@fig-c-irc-admin, @fig-c-bt-hashes); action=allowed на рисунке @fig-admins-log],
[7], [Контроль приложений], [У гостя нет IRC-регистрации и загруженного файла на обоих портах; DENY/BitTorrent в @fig-k-app-event], [Те же клиентские отказы; blocked/BitTorrent с labguest в @fig-c-bt-event],
[8], [Сканирование], [В Log SSH определяется как open, в Drop - filtered; SID 1:2001219 (таблица @tab-k-scan, рисунок @fig-k-scan-log)], [Nmap показывает открытые публикации; сетевые пробы вызывают блокировку СОВ (@fig-c-nmap, @fig-c-ips-wan-event)],
[9], [Веб-признаки атак], [SQL-признак из WAN блокируется по SID 1:2018289 (@fig-k-ips-web, @fig-k-ips-event)], [SQL-признак и обращение к /etc/passwd блокируются СОВ (@fig-c-ips-web, @fig-c-web-event)],
[10], [Управление], [Management: ответ WebAdmin; LAN/WAN: таймаут и DROP (@fig-k-admin, @fig-k-lan, @fig-k-mgmt-log)], [Management: API HTTP 200; SYN из LAN/WAN доходит до шлюза и остаётся без ответа (@fig-c-api, @lst-c-mgmt-capture)],
)}, caption: [Результаты минимального набора тестов по заданию]) <tab-tests>

Для варианта 6 фильтрация проверяется по категориям приложений и учётным записям. В тесте управления «Континента» представлены клиентские TCP/HTTPS-пробы; отдельная запись отказа доступа к ЦУС в журнале C4FW не получена.

== Доступ LAN к DMZ и WAN, изоляция DMZ
С LAN-CLIENT сначала выполнен `ip route get 10.1.50.10`: он показывает следующий переход через NGFW. Затем curl загрузил allowed.txt из DMZ и WAN. Параметр `--interface` фиксирует рабочий адрес клиента, `--noproxy '*'` исключает системный прокси, `-m 5` ограничивает время ожидания. В ответ получен текст контрольного файла.
После HTTP проверен SSH LAN→DMZ и DMZ→LAN. `timeout 5 nc -s ... -vz ... 22` ограничивает попытку пятью секундами; код 124 означает истечение времени ожидания. Разрешённый доступ администратора к тому же SSH-сервису проверяется отдельно, чтобы отличить сетевой запрет от недоступности сервера (рисунки @fig-k-lan - @fig-c-dmz).
#block(breakable: false)[
В Kerio запросы HTTP из LAN проходят, SSH в DMZ завершается с кодом 124, а WebAdmin из LAN не отвечает (рисунок @fig-k-lan).

#terminal("img/direct-kerio-lan.png", [Kerio: маршрут и HTTP/SSH из LAN]) <fig-k-lan>
]
#block(breakable: false)[
У «Континента» маршрут проходит через 10.1.10.1: оба контрольных файла получены, соединение с SSH в DMZ заблокировано (рисунок @fig-c-lan).

#terminal("img/direct-continent-lan.png", [«Континент»: те же команды из LAN]) <fig-c-lan>
]
#block(breakable: false)[
Подключение из DMZ к SSH клиента LAN через Kerio не установлено: timeout возвращает код 124 (рисунок @fig-k-dmz).

#terminal("img/direct-kerio-dmz.png", [Kerio: попытка SSH из DMZ в LAN]) <fig-k-dmz>
]
#block(breakable: false)[
Аналогичная попытка через «Континент» также завершается по таймауту, что соответствует принятой изоляции DMZ (рисунок @fig-c-dmz).

#terminal("img/direct-continent-dmz.png", [«Континент»: попытка SSH из DMZ в LAN]) <fig-c-dmz>
]

#block(breakable: false)[
Оба шлюза записали запрет соединения 10.1.50.10 → 10.1.10.42:22: Kerio сообщает DROP, «Континент» - blocked (рисунок @fig-isolation-log).

#terminal("img/direct-dmz-isolation-journal.png", [Записи блокировки DMZ → LAN на обеих платформах]) <fig-isolation-log>
]

== Публикация сервера и доступ администратора
С WAN-TEST curl обращается к 192.168.100.2:8080 и :8443. Ответ allowed.txt подтверждает, что DNAT доставляет запрос на nginx в DMZ. Для учебного сертификата HTTPS используется `-k`. Затем проверяется недоступность управления из WAN.
С ADMIN-LINUX выполняются те же HTTP-проверка и попытка TCP-соединения с SSH DMZ-WEB; оба доступа разрешены. В Kerio дополнительно проверяется WebAdmin 4081. Проверки Континента на TCP444 сопоставлены для Management и недоверенных сегментов; открытый TCP-порт сам по себе не заменяет аутентифицированное чтение политики. Поэтому из Management дополнительно выполнен curl к /api-v1-objects/config с ГОСТ-движком OpenSSL и действующей учётной записью. Данные входа curl читает из приватного файла, в отчёт выводятся HTTP-код и число конфигураций, без содержимого закрытых объектов (рисунки @fig-k-wan - @fig-c-mgmt-wan).
#block(breakable: false)[
С WAN через Kerio доступны публикации 8080 и 8443, тогда как обращение к WebAdmin 4081 завершается по таймауту (рисунок @fig-k-wan).

#terminal("img/direct-kerio-wan.png", [Kerio: публикации HTTP/HTTPS и запрет WebAdmin из WAN]) <fig-k-wan>
]
#block(breakable: false)[
Через обе публикации «Континента» получен текст allowed.txt с DMZ-сервера; HTTP и HTTPS разрешены (рисунок @fig-c-wan).

#terminal("img/direct-continent-wan.png", [«Континент»: публикации HTTP/HTTPS из WAN]) <fig-c-wan>
]
#block(breakable: false)[
Администратор через Kerio получает HTTP из DMZ, подключается к SSH и получает перенаправление WebAdmin с кодом 302 (рисунок @fig-k-admin).

#terminal("img/direct-kerio-admin.png", [Kerio: разрешённые доступы из Management]) <fig-k-admin>
]
#block(breakable: false)[
Из Management через «Континент» доступны HTTP и SSH сервера DMZ, в отличие от гостевого LAN (рисунок @fig-c-admin).

#terminal("img/direct-continent-admin.png", [«Континент»: разрешённые доступы из Management]) <fig-c-admin>
]
#block(breakable: false)[
Запрос к API ЦУС с адреса 10.1.99.10 получил HTTP 200. ГОСТ-движок OpenSSL позволяет установить защищённое соединение (рисунок @fig-c-api).

#terminal("img/direct-continent-api.png", [«Континент»: доступ к API ЦУС из Management]) <fig-c-api>
]
#block(breakable: false)[
Соединение с TCP 444 из LAN не установлено; nc завершился по таймауту (рисунок @fig-c-mgmt-deny).

#terminal("img/direct-continent-management-deny.png", [«Континент»: проверка TCP444 из LAN]) <fig-c-mgmt-deny>
]
#block(breakable: false)[
Попытка обратиться к TCP 444 из WAN имеет тот же результат: соединение с интерфейсом ЦУС недоступно (рисунок @fig-c-mgmt-wan).

#terminal("img/direct-continent-management-wan.png", [«Континент»: проверка TCP444 из WAN]) <fig-c-mgmt-wan>
]

#block(breakable: false)[
При контрольном прогоне захват на интерфейсах «Континента» показал трёхстороннее TCP-рукопожатие из Management и три SYN без ответных пакетов из каждого недоверенного сегмента. В пересланных записях журнала за время прогона соответствующее событие отказа отсутствует (листинг @lst-c-mgmt-capture).

#listing([Захват TCP-пакетов к порту ЦУС из Management, LAN и WAN], read("outputs/continent-management-tcp444.txt")) <lst-c-mgmt-capture>
]

#block(breakable: false)[
На WAN-TEST запрос с меткой report-nat записан от 192.168.100.2 вместо адреса LAN 10.1.10.42 - результат SNAT (рисунок @fig-k-nat).

#terminal("img/direct-kerio-nat-event.png", [Адрес источника HTTP-запроса после SNAT Kerio]) <fig-k-nat>
]
#block(breakable: false)[
Журнал соединений Kerio указывает разрешающие правила выхода в WAN и публикации DMZ, а также конечные адреса соединений (рисунок @fig-k-paths-log).

#terminal("img/direct-kerio-paths-journal.png", [Разрешённые соединения LAN → WAN и WAN → DMZ в Kerio]) <fig-k-paths-log>
]
#block(breakable: false)[
В записях «Континента» явно показаны SNAT адреса LAN и DNAT публикации 8080 в 10.1.50.10:80 (рисунок @fig-c-nat-log).

#terminal("img/direct-continent-nat-journal.png", [SNAT и DNAT в журнале «Континента»]) <fig-c-nat-log>
]
#block(breakable: false)[
Kerio связывает отказы управления из LAN и WAN с правилом BKS4-Deny-Admin-Outside-Management (рисунок @fig-k-mgmt-log).

#terminal("img/direct-kerio-management-journal.png", [Блокировка управления Kerio из LAN и WAN]) <fig-k-mgmt-log>
]

== Антивирус HTTP и контроль HTTPS
Последовательно загружены allowed.txt, eicar.com и eicar.zip с DMZ-WEB. Опция `-o /dev/null` исключает печать тела, а `-w` выводит HTTP-код и число полученных байт. Контрольный файл проходит. В «Континенте» EICAR и ZIP дают 403; Kerio сбрасывает соединение и передаёт 0 байт тела, хотя заголовок HTTP200 уже мог быть отправлен.
Затем EICAR загружен по HTTPS в /tmp/eicar-https; sha256sum вычисляет хеш полученного файла. Обе платформы без TLS-инспекции передают 68 байт. HTTP-антивирус не видит содержимое зашифрованного HTTPS-соединения, поэтому тестовый файл доходит до клиента.
#block(breakable: false)[
У Kerio контрольный файл передаётся целиком; EICAR и ZIP дают сброс с нулевым телом, HTTPS передаёт 68 байт (рисунок @fig-k-av).

#terminal("img/direct-kerio-av.png", [Kerio: отдельные команды curl для контроля, EICAR, ZIP и HTTPS]) <fig-k-av>
]
#block(breakable: false)[
«Континент» возвращает HTTP 403 для EICAR и архива. Тот же EICAR по HTTPS загружен без изменения хеша (рисунок @fig-c-av).

#terminal("img/direct-continent-av.png", [«Континент»: те же HTTP/HTTPS-проверки]) <fig-c-av>
]
Записи на ADMIN-LINUX содержат имя обнаруженной угрозы, URL и адрес клиента. У Kerio событие поступает от шлюза, у «Континента» обнаружение фиксирует ICAP-сервер ClamAV.
#block(breakable: false)[
Запись Kerio содержит EICAR-Test-File, URL архива и пользователя labguest с адресом 10.1.10.42 (рисунок @fig-k-av-event).

#terminal("img/direct-kerio-av-event.png", [Kerio: событие EICAR в syslog]) <fig-k-av-event>
]
#block(breakable: false)[
ClamAV обнаружил Eicar-Test-Signature в архиве; журнал ICAP указывает адрес LAN-клиента и URL eicar.zip (рисунок @fig-c-av-event).

#terminal("img/direct-continent-av-event.png", [«Континент»: чтение события проверки EICAR]) <fig-c-av-event>
]

== Группы пользователей и контроль приложений
На Kerio источник 10.1.10.42 автоматически определяется как labguest, 10.1.99.10 - как lab-admin. В «Континенте» выполнен вход каждого пользователя через штатный портал. curl отправляет JSON на /user-auth/user-auth с рабочего IP; данные входа читаются из приватного JSON-файла с правами 600, общие параметры curl видны в файле portal.conf, а jq выводит из ответа только status. На экран выведен результат аутентификации (рисунки @fig-c-login-guest и @fig-c-login-admin).
#block(breakable: false)[
Для гостя выбран источник 10.1.10.42; выход из прежнего сеанса и последующая аутентификация вернули success (рисунок @fig-c-login-guest).

#terminal("img/direct-continent-login-guest.png", [«Континент»: вход гостя в портал с адреса LAN]) <fig-c-login-guest>
]
#block(breakable: false)[
Администратор входит с отдельного адреса 10.1.99.10 и также получает success, поэтому роли проверяются независимо (рисунок @fig-c-login-admin).

#terminal("img/direct-continent-login-admin.png", [«Континент»: вход администратора с адреса Management]) <fig-c-login-admin>
]

=== IRC на двух портах
В printf явно указаны сообщения IRC NICK, USER и PING; через канал они поступают в nc. Nc соединяется с собственным сервером 192.168.100.1 на 6667 и 16667. Sed оставляет ответ регистрации 001 и PONG, если он получен; timeout завершает короткую пробу. У администратора ответ 001 подтверждает регистрацию прикладного протокола. У гостя ответа регистрации нет; решение связывается с пользователем и IRC в журнале ContentFilter.
#block(breakable: false)[
Администратор через Kerio получает IRC-ответ 001 на портах 6667 и 16667: регистрация разрешена в обоих случаях (рисунок @fig-k-irc-admin).

#terminal("img/direct-kerio-irc-admin.png", [Kerio: IRC-регистрация администратора на 6667 и 16667]) <fig-k-irc-admin>
]
#block(breakable: false)[
Те же сообщения NICK и USER от гостя не приводят к регистрации ни на одном из двух портов (рисунок @fig-k-irc-guest).

#terminal("img/direct-kerio-irc-guest.png", [Kerio: те же IRC-запросы гостя]) <fig-k-irc-guest>
]
#block(breakable: false)[
Через «Континент» сервер подтверждает IRC-регистрацию администратора на стандартном и нестандартном портах (рисунок @fig-c-irc-admin).

#terminal("img/direct-continent-irc-admin.png", [«Континент»: IRC-регистрация администратора]) <fig-c-irc-admin>
]
#block(breakable: false)[
У гостя через «Континент» ответы 001 отсутствуют на обоих портах; соединения завершаются по ограничению времени (рисунок @fig-c-irc-guest).

#terminal("img/direct-continent-irc-guest.png", [«Континент»: IRC-запросы гостя]) <fig-c-irc-guest>
]

=== BitTorrent штатным клиентом
Тест выполняется программой transmission-cli. Сначала curl получает .torrent с собственного WAN-TEST. В отдельном каталоге настроек явно задан рабочий адрес источника; DHT, PEX, LPD, uTP и автоматическое открытие портов выключены. Private-торрент использует собственный трекер и единственный узел стенда, внешние пиры не участвуют. Эталонный SHA256 прочитан на WAN-TEST (рисунок @fig-bt-reference).
Для каждой группы созданы отдельные настройки Transmission и каталоги загрузки. У администратора появляется harmless.txt размером 3407872 байта; загрузка дополнительно проверяется по SHA256 исходного файла. У гостя каталог остаётся пустым. Проверка повторена для пиров на 6881 и 16881. Ограничение времени завершает клиент, чтобы он не оставался раздавать файл после проверки (рисунки @fig-k-bt-admin-6881 - @fig-c-bt-event).
#block(breakable: false)[
На стандартном порту BitTorrent администратор через Kerio скачал harmless.txt размером 3407872 байта (рисунок @fig-k-bt-admin-6881).

#terminal("img/direct-kerio-bt-admin-6881.png", [Kerio: Transmission администратора, пир 6881]) <fig-k-bt-admin-6881>
]
#block(breakable: false)[
Переход на порт 16881 не изменил разрешение: в каталоге администратора появился файл того же размера (рисунок @fig-k-bt-admin-16881).

#terminal("img/direct-kerio-bt-admin-16881.png", [Kerio: Transmission администратора, пир 16881]) <fig-k-bt-admin-16881>
]
#block(breakable: false)[
Для гостя Kerio не пропустил загрузку со стандартного порта: после завершения Transmission каталог пуст (рисунок @fig-k-bt-guest-6881).

#terminal("img/direct-kerio-bt-guest-6881.png", [Kerio: Transmission гостя, пир 6881]) <fig-k-bt-guest-6881>
]
#block(breakable: false)[
На нестандартном порту гостевая загрузка также не состоялась; обхода ограничения сменой порта не произошло (рисунок @fig-k-bt-guest-16881).

#terminal("img/direct-kerio-bt-guest-16881.png", [Kerio: Transmission гостя, пир 16881]) <fig-k-bt-guest-16881>
]
#block(breakable: false)[
При работе через «Континент» администратор скачал полный файл с пира на порту 6881 (рисунок @fig-c-bt-admin-6881).

#terminal("img/direct-continent-bt-admin-6881.png", [«Континент»: Transmission администратора, пир 6881]) <fig-c-bt-admin-6881>
]
#block(breakable: false)[
Администратор «Континента» получил harmless.txt и с порта 16881, что подтверждает действие исключения для его группы (рисунок @fig-c-bt-admin-16881).

#terminal("img/direct-continent-bt-admin-16881.png", [«Континент»: Transmission администратора, пир 16881]) <fig-c-bt-admin-16881>
]
#block(breakable: false)[
Каталог гостевой загрузки через «Континент» остался пустым после проверки стандартного порта BitTorrent (рисунок @fig-c-bt-guest-6881).

#terminal("img/direct-continent-bt-guest-6881.png", [«Континент»: Transmission гостя, пир 6881]) <fig-c-bt-guest-6881>
]
#block(breakable: false)[
Результат гостя на порту 16881 совпадает со стандартным: загруженного файла нет (рисунок @fig-c-bt-guest-16881).

#terminal("img/direct-continent-bt-guest-16881.png", [«Континент»: Transmission гостя, пир 16881]) <fig-c-bt-guest-16881>
]
#block(breakable: false)[
SHA256 исходного harmless.txt вычислен на WAN-TEST; с этим значением сравниваются полученные клиентами файлы (рисунок @fig-bt-reference).

#terminal("img/direct-bittorrent-reference.png", [SHA256 исходного файла на WAN-TEST]) <fig-bt-reference>
]
#block(breakable: false)[
Обе загрузки администратора через Kerio имеют тот же SHA256, что и исходный файл на сервере (рисунок @fig-k-bt-hashes).

#terminal("img/direct-kerio-bt-hashes.png", [Kerio: SHA256 файлов, загруженных с двух портов]) <fig-k-bt-hashes>
]
#block(breakable: false)[
У «Континента» хеши файлов с обоих портов также совпали с эталоном: переданы полные данные (рисунок @fig-c-bt-hashes).

#terminal("img/direct-continent-bt-hashes.png", [«Континент»: SHA256 файлов, загруженных с двух портов]) <fig-c-bt-hashes>
]
#block(breakable: false)[
Kerio распознал BitTorrent на 6881 и 16881, указал labguest и запретил соединения правилом гостевой группы (рисунок @fig-k-app-event).

#terminal("img/direct-kerio-app-event.png", [Kerio: пользователь и запрет BitTorrent]) <fig-k-app-event>
]
#block(breakable: false)[
В журнале «Континента» BitTorrent заблокирован для labguest на обоих портах; обе записи относятся к гостевому правилу (рисунок @fig-c-bt-event).

#terminal("img/direct-continent-bt-event.png", [«Континент»: блокировка BitTorrent для labguest]) <fig-c-bt-event>
]

#block(breakable: false)[
Записи обеих платформ связывают разрешённые соединения на тестовые порты с пользователем lab-admin и администраторским правилом (рисунок @fig-admins-log).

#terminal("img/direct-admins-journal.png", [Разрешённые соединения администратора на обеих платформах]) <fig-admins-log>
]

== IDS/IPS: команды сканирования и веб-запросов
Nmap запущен непосредственно на WAN-TEST с параметрами -sS (SYN-сканирование), -sV (определение сервиса), -Pn (без предварительного ping), -n (без DNS). Проверяются только четыре порта своего NGFW. Доступные публикации отделены от filtered-портов. На Kerio сканирование остановлено по лимиту 25 секунд без полной таблицы портов; доступность публикаций отдельно проверена curl выше. Само состояние filtered не приравнивается к срабатыванию IPS: требуется соответствующее событие (рисунки @fig-k-nmap - @fig-c-ips-lan).
#block(breakable: false)[
Сканирование четырёх портов Kerio достигло лимита host-timeout. По этому кадру нельзя определить итоговое состояние каждого порта (рисунок @fig-k-nmap).

#terminal("img/direct-kerio-nmap.png", [Kerio: сканирование Nmap из WAN]) <fig-k-nmap>
]
#block(breakable: false)[
Nmap у «Континента» определил веб-службы и показал filtered для SSH; это описание доступных сервисов со стороны WAN (рисунок @fig-c-nmap).

#terminal("img/direct-continent-nmap.png", [«Континент»: сканирование Nmap из WAN]) <fig-c-nmap>
]
Для проверки влияния IPS Kerio использовалась отдельная временная публикация SSH в DMZ. В режиме Log Nmap определил OpenSSH, а после включения блокировки тот же порт стал filtered. По окончании проверки временная публикация удалена.
#block(breakable: false)[
#figure(table(columns: (1.1fr, 1.4fr, 2fr), align: left,
table.header([Режим], [Nmap, TCP 22], [Событие IPS]),
[Log], [open, OpenSSH 8.9p1], [Alert, SID 1:2001219],
[Log and drop], [filtered], [Packet drop, SID 1:2001219],
), caption: [Сравнение обнаружения и предотвращения SSH-сканирования Kerio]) <tab-k-scan>
]

#block(breakable: false)[
SID 1:2001219 в Kerio сначала дал Alert, а в режиме предотвращения - Packet drop для SSH-сканирования (рисунок @fig-k-scan-log).

#terminal("img/direct-kerio-scan-journal.png", [Сигнатура SSH-сканирования Kerio в режимах Log и Drop]) <fig-k-scan-log>
]
Перед веб-пробами curl получает allowed.txt. Затем отправляются URI с SQL-признаком и обращением к /etc/passwd. Тестовый nginx обрабатывает эти URI как запросы статических страниц. Из WAN реакция - таймаут и запись блокировки с SID; из LAN прямой путь Kerio возвращает 404 без IPS-детекта.
#block(breakable: false)[
Через Kerio обычный HTTP из WAN проходит, а SQL-подобный URI и запрос с обходом каталогов завершаются по таймауту (рисунок @fig-k-ips-web).

#terminal("img/direct-kerio-ips-web.png", [Kerio: контрольный HTTP и две веб-пробы из WAN]) <fig-k-ips-web>
]
#block(breakable: false)[
Прямые запросы LAN → DMZ доходят до nginx и получают 404. В этом пути Kerio не зафиксировал веб-детект IPS (рисунок @fig-k-ips-lan).

#terminal("img/direct-kerio-ips-lan.png", [Kerio: те же веб-пробы из LAN]) <fig-k-ips-lan>
]
#block(breakable: false)[
У «Континента» контрольный файл доступен, но запрос с User-Agent Nmap и URI /etc/passwd ответа не получают (рисунок @fig-c-ips-web).

#terminal("img/direct-continent-ips-web.png", [«Континент»: контроль, User-Agent Nmap и URI с /etc/passwd]) <fig-c-ips-web>
]
#block(breakable: false)[
SQL-подобный параметр передан через curl; запрос не получил HTTP-ответа в течение пяти секунд (рисунок @fig-c-sql).

#terminal("img/direct-continent-sql.png", [«Континент»: команда SQL-подобного запроса]) <fig-c-sql>
]
#block(breakable: false)[
Журнал СОВ «Континента» связывает веб-пробу из WAN с сервером DMZ и действием blocked (рисунок @fig-c-web-event).

#terminal("img/direct-continent-ips-web-event.png", [«Континент»: событие блокировки веб-пробы]) <fig-c-web-event>
]
#block(breakable: false)[
У Kerio отказ SQL-подобного запроса подтверждён действием Packet drop и сигнатурой 1:2018289 (рисунок @fig-k-ips-event).

#terminal("img/direct-kerio-ips-event.png", [Kerio: событие блокировки веб-запроса]) <fig-k-ips-event>
]
#block(breakable: false)[
СОВ «Континента» зафиксировала сетевую пробу от LAN 10.1.10.42 к DMZ и заблокировала её (рисунок @fig-c-ips-event).

#terminal("img/direct-continent-ips-event.png", [«Континент»: блокировка сетевой пробы из LAN]) <fig-c-ips-event>
]
#block(breakable: false)[
Для источника WAN 192.168.100.1 журнал «Континента» также содержит блокировку сетевого воздействия на DMZ (рисунок @fig-c-ips-wan-event).

#terminal("img/direct-continent-ips-wan-event.png", [«Континент»: блокировка SYN-пробы из WAN]) <fig-c-ips-wan-event>
]
На Континенте дополнительно выполнены ограниченные пробы hping3: 12 XMAS-пакетов и 120 SYN. Пакеты XMAS могут быть отброшены межсетевым экраном до СОВ, поэтому их потеря сопоставляется с журналом. Сетевые сигнатуры внутреннего пути проверяются на форвардируемом 443, поскольку HTTP завершается на AV-прокси.
#block(breakable: false)[
hping3 отправил ограниченные серии XMAS и SYN; показаны параметры команд и статистика ответов (рисунок @fig-c-flags).

#terminal("img/direct-continent-tcp-flags.png", [«Континент»: команды hping3 с XMAS и SYN]) <fig-c-flags>
]
#block(breakable: false)[
На внутреннем пути проверен TCP 443: Nmap и SYN-проба направлены на сервер DMZ с адреса LAN (рисунок @fig-c-ips-lan).

#terminal("img/direct-continent-ips-lan.png", [«Континент»: сетевые проверки LAN→DMZ:443]) <fig-c-ips-lan>
]

= Отчётность и мониторинг
== Журналирование и оповещения
Обе платформы отправляют syslog в Management на 10.1.99.10:514. События прочитаны на сервере журналов; в них сопоставлены источник, назначение, пользователь, SID и действие.
Внешний монитор на ADMIN-LINUX преобразует события AV/IPS в SNMP-уведомления. Отправитель - 10.1.99.10, приёмник snmptrapd - 10.1.99.10:162. Оповещения формирует внешний монитор по событиям шлюза и ICAP-сервера. Приём проверен по журналу snmptrapd: сообщение содержит компонент защиты, адреса и сигнатуру (рисунки @fig-k-notification - @fig-c-av-notification).
#block(breakable: false)[
SNMP-приёмник получил сообщение об IPS Kerio: в нём есть SID 1:2018289, адреса и действие blocked (рисунок @fig-k-notification).

#terminal("img/direct-kerio-notification.png", [Kerio: чтение доставленного уведомления в snmptrapd]) <fig-k-notification>
]
#block(breakable: false)[
В уведомлении «Континента» указаны SYN flood, SID 3900001 и источник 10.1.10.42; сообщение принято snmptrapd (рисунок @fig-c-notification).

#terminal("img/direct-continent-notification.png", [«Континент»: чтение доставленного уведомления в snmptrapd]) <fig-c-notification>
]
#block(breakable: false)[
Уведомление антивируса Kerio содержит EICAR, имя labguest и URL тестового файла, что позволяет определить затронутого клиента (рисунок @fig-k-av-notification).

#terminal("img/direct-kerio-av-notification.png", [Kerio: доставленное AV-уведомление с EICAR и пользователем]) <fig-k-av-notification>
]
#block(breakable: false)[
От ICAP-монитора получено сообщение Eicar-Test-Signature с адресом клиента и URL архива (рисунок @fig-c-av-notification).

#terminal("img/direct-continent-av-notification.png", [«Континент»: доставленное AV-уведомление ICAP]) <fig-c-av-notification>
]
== Статистические представления
#let secstats = json("outputs/continent-final-security-statistics.json")
По журналу «Континента» построены три представления: по пользователям, по распознанным приложениям и по правилам блокировки. Выборка содержит #(secstats.actions.allowed + secstats.actions.blocked) записей (#secstats.actions.allowed разрешений, #secstats.actions.blocked блокировок); единица учёта - запись журнала, а не соединение или байты (таблицы @tab-c4-stat-users - @tab-c4-stat-blocks).
#figure(table(columns: (2fr, 1fr), align: left,
[Пользователь], [Записей],
..secstats.by_user.map(row => ([#row.user], [#row.records])).flatten()),
caption: [Записи по пользователям]) <tab-c4-stat-users>
#block(breakable: false)[
#figure(table(columns: (1fr, 1fr, 1fr), align: left,
[Приложение], [Действие], [Записей],
..secstats.by_recognized_application.map(row => ([#row.application], [#row.action], [#row.records] )).flatten()),
caption: [Записи с распознанными приложениями]) <tab-c4-stat-apps>
]
#figure({set text(size: 9pt); table(columns: (4fr, 1fr), align: left,
[Правило], [Записей],
..secstats.blocked_by_rule.map(row => ([#row.rule], [#row.records])).flatten())},
caption: [Блокировки по правилам]) <tab-c4-stat-blocks>
В выборке «Континента» по 11 блокировок IRC и BitTorrent; все 22 записи относятся к гостевому правилу. Ещё 42 отказа дал BKS4-Default-Deny: при разборе таких событий следует проверить, нужны ли запрещённые обращения рабочим сервисам.

Для Kerio сформированы представления по пользователям, распознанному содержимому и правилам (таблица @tab-kerio-stats). Единица учёта - запись журнала: пакетная блокировка, решение DPI, событие IPS и завершённое соединение считаются раздельно; сумма не равна числу соединений. Приложение определяется по полю Content в журнале контроля приложений. В разрез пользователей включены записи с полем User, поэтому их сумма отличается от общего числа записей по правилам.
#let kstats = json("outputs/kerio-statistics-final.json")
#figure({set text(size: 9pt); table(columns: (1fr, 2.5fr, 0.6fr), align: left,
table.header([Представление], [Значение], [Записей]),
..kstats.by_user.pairs().map(((k,v)) => ([Пользователь], [#k], [#v])).flatten(),
..kstats.by_detected_content.pairs().map(((k,v)) => ([Content], [#k], [#v])).flatten(),
..kstats.by_rule.pairs().slice(0, 12).map(((k,v)) => ([Правило, первые 12], [#k], [#v])).flatten()
)}, caption: [Статистика Kerio по пользователям, приложениям и правилам]) <tab-kerio-stats>
В выборке Kerio распознаны четыре события IRC и четыре события BitTorrent, включая два Suspected P2P. Правило Management дало 775 записей, поэтому служебные обращения администратора нужно учитывать отдельно от пользовательской активности.

== Разбор инцидента
#block(breakable: false)[
На «Континенте» событие 13:38:27 содержит источник 192.168.100.1:2224 и получателя 10.1.50.10:80 после DNAT. СОВ определила SYN-сканирование по SID 3900002 и записала действие blocked. Через 0,4 с сработала сигнатура 3900001 «SYN flood»; оба сообщения поступили на SNMP-приёмник.

У Kerio в событии 22:48:07 указаны источник 192.168.100.1:37084, сервер 10.1.50.10:80 и SID 1:2018289. Действие Packet drop соответствует таймауту SQL-подобного запроса на клиенте (рисунок @fig-k-ips-event). В обоих случаях журнал позволяет связать воздействие с адресами, сигнатурой и решением шлюза.
]

== Резервное копирование и восстановление
Для каждой платформы создана резервная копия конфигурации. Затем изменено описание контрольного объекта и выполнено восстановление. В «Континенте» восстановлен компонент CDC, в Kerio использован Configuration.apply. Описание объектов вернулось к исходному значению, контрольные хеши конфигурации совпали (таблица @tab-restore).
#block(breakable: false)[
#figure(table(columns: (1fr, 1.8fr, 2.6fr), align: left,
table.header([Платформа], [Контрольное изменение], [Результат восстановления]),
[«Континент»], [Описание BKS4_WAN_TEST], [Исходное описание восстановлено; хеши FW, NAT, адресов и сервисов совпали],
[Kerio], [Описание BKS4-LAN-DMZ-Web], [Исходное описание восстановлено; совпали хеши семи разделов конфигурации],
), caption: [Проверка восстановления конфигурации]) <tab-restore>
]

Архивы с сертификатами и ключами хранятся на АРМ администратора и хосте PNETLab с правами доступа 600.

= Индивидуальное задание варианта 6
На обеих платформах опубликован веб-сервер DMZ. Проверки IRC и Transmission демонстрируют запрет гостю и разрешение администратору на стандартных и нестандартных портах; пользователь и решение видны в журнале.
Для GeoIP на WAN-TEST двум адресам loopback назначены 5.255.255.5 (RU) и 8.8.8.8 (US). Curl привязан к каждому источнику и обращается только к собственной публикации 192.168.100.2:8080.
#block(breakable: false)[
С включённым GeoIP Kerio пропускает запрос от 5.255.255.5, а для источника 8.8.8.8 возвращается таймаут (рисунок @fig-k-geoip).

#terminal("img/direct-kerio-geoip-on.png", [Kerio: проверка GeoIP при включённом запрете US]) <fig-k-geoip>
]
#block(breakable: false)[
На публикации «Континента» источник RU получает контрольный файл, а источник US не получает ответа (рисунок @fig-c-geoip).

#terminal("img/direct-continent-geoip-on.png", [«Континент»: проверка GeoIP при включённом запрете US]) <fig-c-geoip>
]
При отключённом географическом ограничении оба источника получают HTTP 200. После включения запрета US доступ из префикса RU сохраняется, а запрос из US завершается по таймауту (таблица @tab-geoip-results). В Kerio настройка действует на входящий WAN-трафик, в «Континенте» правило ограничено публикацией DMZ.
#block(breakable: false)[
#figure(table(columns: (1fr, 1.5fr, 1fr, 1fr), align: left,
table.header([Платформа], [Запрет US], [Источник RU], [Источник US]),
[Kerio], [Выключен], [HTTP 200], [HTTP 200],
[Kerio], [Включён], [HTTP 200], [Таймаут],
[«Континент»], [Выключен], [HTTP 200], [HTTP 200],
[«Континент»], [Включён], [HTTP 200], [Таймаут],
), caption: [Доступ к DMZ с географическим ограничением и без него]) <tab-geoip-results>
]

Журнал «Континента» связывает отказ с источником 8.8.8.8, страной US и правилом BKS4-GeoIP-Block-US-to-DMZ (листинг @lst-geoip-block).
#listing([Блокировка источника US правилом GeoIP], read("outputs/continent-geoip-enabled.txt").split("\n").filter(x => x.contains("C4FW event_type")).map(x => x.split(" C4FW ").last()).join("\n")) <lst-geoip-block>

= Сравнительный анализ
Результаты сравнения сведены в таблицу @tab-compare.
#block(breakable: false)[
#figure({set text(size: 9pt); table(columns: (1.1fr, 2.4fr, 2.4fr), align: left,
table.header([Критерий], [«Континент 4»], [Kerio Control]),
[Надёжность и отказоустойчивость], [Восстановление CDC вернуло описание объекта и контрольные хеши. На стенде один узел безопасности], [Восстановление вернуло описание правила и хеши семи разделов. На стенде один шлюз],
[Информационная безопасность], [Гостевые IRC/BitTorrent блокируются. ICAP запрещает EICAR по HTTP, СОВ фиксирует блокировки из WAN и LAN. Управление ограничено Management], [Гостевой AppID и HTTP-антивирус работают. Веб-пробы IPS из WAN блокируются, прямой LAN → DMZ возвращает 404 без детекта. Управление ограничено Management],
[Быстродействие], [Контрольный HTTP проходит через ICAP; EICAR получает HTTP 403. Для применения политики нужна отдельная задача установки], [Контрольный HTTP проходит; EICAR блокируется сбросом соединения. Изменения правил применяются в WebAdmin],
[Сопровождение], [Windows-АРМ с CSP, работа с ЦУС и узлом; структурированные события упрощают разбор], [Один WebAdmin и JSON-RPC API; обновления и журналы доступны из общего интерфейса],
)}, caption: [Сравнение по собственным испытаниям]) <tab-compare>
]


Нагрузочное измерение пропускной способности не выполнялось. Сравнение быстродействия ограничено поведением контрольных запросов и способом применения настроек.

= Заключение
На двух NGFW реализованы политика с запретом по умолчанию, NAT и публикация DMZ, антивирусная проверка HTTP, групповой контроль приложений, IDS/IPS, GeoIP и мониторинг. Для варианта 6 подтверждены запрет гостевых приложений независимо от порта, исключение администратора и изменение доступа при GeoIP off/on. Проведены разбор ложных срабатываний и инцидентов, статистический анализ и контрольное восстановление конфигураций.
Для защищённого HTTPS потребуется TLS-инспекция с доверенным сертификатом на клиентах. Прямой LAN→DMZ в Kerio возвращает 404 без веб-детекта IPS; эту границу следует учитывать при размещении внутренних сервисов. Исключения IPS нужно сохранять в пределах проверенной сигнатуры либо доверенного источника и сервиса.
