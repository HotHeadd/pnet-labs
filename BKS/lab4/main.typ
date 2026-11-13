#import "@local/mephi-lab:0.1.0": lab-report
#show: lab-report.with(lab-number: 4, topic: "Установка и конфигурирование комплексных аппаратно-программных межсетевых экранов (UTM/NGFW)", discipline: "Безопасность компьютерных сетей", student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."), group: "Б23-505", teacher: "Басыня Е. А.")
#let listing(caption, body) = figure({
  set text(size: 8pt)
  raw(body.trim().split("\n").map(line => line.clusters().chunks(94).map(x => x.join("")).join("\n")).join("\n"), block: true)
}, caption: caption, kind: raw)
#let names(v) = if v == none { "—" } else if v.len() == 0 { "любой" } else { v.join(", ") }
#let shot-ratios = (
  "img/kerio-final-audit.png": 0.401367,
  "img/kerio-evidence-connectivity.png": 0.271484,
  "img/c4-finish-results.png": 0.568359,
  "img/c4-finish-events.png": 0.568359,
  "img/continent-management-current.png": 0.327148,
  "img/continent-isolation-current.png": 0.123047,
  "img/continent-ids-current.png": 0.568359,
  "img/kerio-tests-wan.png": 0.549805,
  "img/kerio-tests-dmz.png": 0.104492,
  "img/kerio-tests-admin.png": 0.234375,
  "img/kerio-evidence-baseline-events.png": 0.364258,
  "img/kerio-evidence-av.png": 0.512695,
  "img/kerio-apps-current.png": 0.291992,
  "img/kerio-events.png": 0.364258,
  "img/kerio-evidence-scan-log.png": 0.475586,
  "img/kerio-evidence-scan-drop.png": 0.438477,
  "img/kerio-evidence-paths.png": 0.382812,
  "img/kerio-evidence-path-events.png": 0.364258,
  "img/continent-evidence-geoip.png": 0.290039,
  "img/kerio-evidence-geoip.png": 0.25293,
)
#let shot(file, caption) = figure(layout(size => block(
  width: 100%, height: size.width * shot-ratios.at(file, default: 0.75), clip: true,
  place(top + left, image(file, width: size.width, height: size.width * 0.75))
)), caption: caption)
#let first-lines(file, n) = { let lines = read(file).split("\n"); lines.slice(0, calc.min(n, lines.len())).join("\n") }

#let delivery-example(file, component) = {
  let marker = "External monitor SNMP delivery: verified"
  let matched = read(file).split(marker).filter(x => x.contains("Component: " + component))
  assert(matched.len() == 1, message: "Ожидается один раздел доставки " + component)
  let confirmation = "Exact payload found in snmptrapd log: yes"
  assert(matched.first().contains(confirmation), message: "Нет подтверждения доставки")
  marker + matched.first().split(confirmation).first() + confirmation
}

= Цель работы
Развернуть Kerio Control и «Континент 4», настроить межсетевое экранирование, NAT, защитные модули и мониторинг, провести испытания и сравнить платформы. Вариант 6: опубликовать веб-сервер DMZ, запретить мессенджеры и файлообменные приложения группе «Гости», настроить GeoIP и сравнить доступ при включённом и выключенном ограничении.

= Характеристика платформ и критерии сравнения
Kerio Control объединяет межсетевой экран, NAT, антивирус, IPS и контроль приложений в одном веб-интерфейсе. «Континент 4» использует центр управления сетью (ЦУС), узел безопасности и Менеджер конфигурации на Windows; политика передаётся на узел отдельной задачей установки. Сравнение выполняется по надёжности, информационной безопасности, быстродействию и трудоёмкости сопровождения.

= Топология стенда и адресация
Стенд выделен в отдельную лабораторную BKS4 на сервере PNETLab; предыдущие БКС 1–3 сохранены. Обе платформы используют одинаковые адреса интерфейсов и одни и те же тестовые машины, поэтому включаются поочерёдно. Схема приведена на рисунке @fig-topology, адресация — в таблице @tab-addressing.
#figure(image("img/topology.svg", width: 100%), caption: [Схема стенда и принятая адресация]) <fig-topology>
#figure(table(columns: (1.1fr, 1.3fr, 1.9fr), align: left,
table.header([Узел], [Рабочий адрес], [Назначение и параметры ВМ]),
[KERIO], [192.168.100.2 / 10.1.10.1 / 10.1.50.1 / 10.1.99.1], [Kerio Control 10.0.1 build 9439, 2 vCPU, 4 ГиБ, virtio-net],
[CONTINENT], [те же адреса на te-0-0…te-3-0], [«Континент 4.2.1-653», узел безопасности с ЦУС, 2 vCPU, 8 ГиБ, vmxnet3],
[LAN-CLIENT], [10.1.10.42/24], [Клиент LAN (гость labguest), Ubuntu 22.04, 1 ГиБ],
[DMZ-WEB], [10.1.50.10/26], [nginx HTTP/HTTPS, контрольный файл, EICAR, ZIP с EICAR],
[WAN-TEST], [192.168.100.1/24], [«Интернет»: NAT наружу, DNS/NTP, веб-сервер, IRC и BitTorrent для тестов],
[ADMIN-LINUX], [10.1.99.10/24], [АРМ администратора: syslog, SNMP-приёмник, ICAP/ClamAV, скрипты API, 3 ГиБ],
[ADMIN-WIN], [10.1.99.20/24], [Windows Server 2019: Менеджер конфигурации «Континента», CSP, 4 ГиБ],
), caption: [Адресация и параметры виртуальных машин]) <tab-addressing>
Рабочий трафик направляется через выбранный NGFW; служебные OOB-интерфейсы используются для обслуживания. Платформы включаются поочерёдно. WAN-TEST предоставляет DNS/NTP, HTTP/HTTPS, IRC на 6667/16667 и BitTorrent на 6881/16881; DMZ-WEB — nginx с контрольным файлом и EICAR в обычном и ZIP-виде. Клиенты используют рабочие исходные адреса и маршруты через NGFW.

Ping и TCP-traceroute из LAN приведены в листинге @lst-connectivity. HTTP-порт 80 выбран в соответствии с политикой доступа.
#listing([Связность LAN при работе Kerio], read("outputs/kerio-connectivity-lan.txt")) <lst-connectivity>

= Установка и базовая настройка
«Континент 4.2.1-653» развёрнут как узел безопасности с ЦУС; на ADMIN-WIN установлены Менеджер конфигурации 4.2.1.653 и CSP. Импортированы учебная лицензия до 31.12.2026 и пакет сигнатур 4.2.1.53 от 18.04.2025 (рисунок @fig-c4-license).
#figure(image("img/continent-license.png", width: 100%), caption: [«Континент»: интерфейс управления и учебная лицензия]) <fig-c4-license>

Kerio Control 10.0.1 build 9439 зарегистрирован с trial-лицензией на 25 пользователей до 06.12.2026. Антивирусная база 10903722 и IPS 5.150/2.3546 обновлены 13.11.2026; состояние показано на рисунке @fig-k-status.
#shot("img/kerio-final-audit.png", [Kerio: версия, действующая лицензия и состояния модулей]) <fig-k-status>
На обеих платформах изменены пароли, настроены NTP 192.168.100.1 и часовой пояс Москва. Управление доступно из Management: Kerio 4081, ЦУС 444. Доступ администратора подтверждён рисунком @fig-c4-mgmt и проверками раздела тестирования.
#shot("img/continent-management-current.png", [«Континент»: чтение политики из Management]) <fig-c4-mgmt>

= Политика безопасности
== Правила «Континента»
Политика строится на сетевых объектах (BKS4_LAN, BKS4_DMZ, BKS4_MGMT, BKS4_WAN_PUBLIC, BKS4_DMZ_WEB, BKS4_WAN_TEST), сервисах и группах пользователей. Итоговый порядок правил межсетевого экрана приведён в таблице @tab-c4-fw (выгрузка из ЦУС по API, `configs/continent-firewall-policy.json`), NAT — в таблице @tab-c4-nat. Последнее правило запрещает остальной трафик с журналированием; все разрешающие правила передают трафик в СОВ (`passips`), кроме исключения для ложного срабатывания.
#let c4fw = json("configs/continent-firewall-policy.json")
#figure({set text(size: 7pt); table(columns: (0.3fr, 2fr, 0.6fr, 1.5fr, 1.4fr, 2fr, 1.6fr), align: left,
[№], [Правило], [Действие], [Источник], [Назначение], [Сервис], [Приложения / профиль],
..c4fw.enumerate().map(((i, r)) => ([#(i + 1)], [#r.name], [#r.rule_action], [#(if r.is_inverse_src { "не " } else { "" })#names(r.src)], [#names(r.dst)], [#names(r.service)], [#names(r.applications)#(if r.at("app_profile", default: none) != none and r.app_profile.len() > 0 { " / " + r.app_profile.join(", ") } else { "" })])).flatten())},
caption: [Правила межсетевого экрана «Континента» в порядке обработки]) <tab-c4-fw>
#let c4nat = json("configs/continent-nat-policy.json")
#figure({set text(size: 8pt); table(columns: (0.3fr, 2fr, 1fr, 1.8fr, 1.8fr, 2fr), align: left,
table.header([№], [Правило], [Тип], [Источник], [Назначение], [Трансляция]),
..c4nat.map(r => ([#r.order], [#r.name], [#r.nat_type], [#names(r.at("src", default: ()))], [#names(r.at("dst", default: ()))], [#(if r.nat_type == "dnat" { r.value.ip + ":" + r.port_value.dst } else if r.nat_type == "masquerade" { "адрес WAN 192.168.100.2" } else { "без трансляции" })])).flatten())},
caption: [Правила NAT «Континента»]) <tab-c4-nat>
Внутренние сети обмениваются трафиком без NAT. LAN и Management используют SNAT; публикация 8080/8443 переводится в 80/443 DMZ-сервера. Правила HTTP с антивирусным профилем и явный запрет остальных сервисов LAN→DMZ стоят выше гостевого DPI.

== Правила Kerio Control
Политика Kerio задаётся таблицей правил с интерфейсными и адресными объектами; трансляции встроены в правила (DNAT в правилах публикации, SNAT в правилах выхода). Итоговая политика приведена в таблице @tab-kerio-fw (выгрузка по API, `configs/kerio-traffic-policy.json`); правило по умолчанию — Drop с журналированием.
#let kpol = json("configs/kerio-traffic-policy.json")
#let mask-prefix(mask) = if mask == "255.255.255.0" { "24" } else if mask == "255.255.255.192" { "26" } else { mask }
#let kent(e) = if e.type == "RuleAny" { "любой" } else if e.at("firewall", default: false) { "Firewall" } else { e.entities.map(x => if x.type == "TrafficEntityInterface" { if x.interfaceCondition.type == "InterfaceInternet" { "WAN" } else { x.interfaceCondition.type } } else if x.type == "TrafficEntityNetwork" { x.addr1 + "/" + mask-prefix(x.addr2) } else { x.host }).join(", ") }
#let ksvc(sv) = if sv.type == "RuleAny" { "любой" } else { sv.entries.map(x => if x.definedService { x.service.name } else { str(x.protocol) + ":" + (if x.port.ports.len() > 0 { x.port.ports.map(str).join(",") } else { "*" }) }).join("; ") }
#let knat(r) = if r.enableDestinationNat { "DNAT → " + r.translatedHost + ":" + str(r.translatedPort.value) } else if r.enableSourceNat { "SNAT" } else { "—" }
#figure({set text(size: 7.5pt); table(columns: (0.3fr, 2fr, 0.7fr, 1.9fr, 1.2fr, 1.5fr, 1.2fr), align: left,
table.header([№], [Правило], [Действие], [Источник], [Назначение], [Сервис], [Трансляция]),
..kpol.rules.enumerate().map(((i, r)) => ([#(i + 1)], [#r.name], [#r.action], [#kent(r.source)], [#kent(r.destination)], [#ksvc(r.service)], [#knat(r)])).flatten(),
[—], [Block other communication], [Drop], [любой], [любой], [любой], [—])},
caption: [Правила Kerio Control в порядке обработки (6 = TCP, 17 = UDP)]) <tab-kerio-fw>
В Kerio фильтрация и NAT объединены в строках одной таблицы, в «Континенте» таблицы разделены. Обработка идёт сверху вниз; завершающее правило запрещает прочий трафик. Разрешены необходимые HTTP/HTTPS/DNS/NTP, публикации DMZ и управление из Management; DMZ→LAN запрещён.

= Настройка защитных модулей
== Антивирус
На «Континенте» профиль BKS4-HTTP-AV использует ICAP 10.1.99.10:1344 (RESPMOD, fail-closed) с c-icap/ClamAV. Он назначен HTTP-правилам LAN и Management. В Kerio включён встроенный антивирус и HTTP-сканирование (рисунок @fig-k-av-config).
#figure(image("img/kerio-webadmin-av.png", width: 100%), caption: [Kerio: параметры встроенного антивируса]) <fig-k-av-config>
EICAR и ZIP по HTTP блокируются на обеих платформах: «Континент» возвращает 403, Kerio сбрасывает соединение с нулевым телом и записывает EICAR-Test-File. По HTTPS передаются 68 байт исходного файла: при работе без TLS-инспекции содержимое зашифровано и шлюз видит доменное имя SNI. Клиентские результаты и события показаны на рисунках @fig-c4-results, @fig-c4-events и @fig-k-av.

== Группы и контроль приложений
В «Континенте» labguest и lab-admin входят через портал auth.bks4.test и принадлежат группам Guests и Administrators. Правило BKS4-Guests-Block-Messengers-P2P включает категории Chat/FileSharing и приложения IRC, Jabber, BitTorrent. Правило Administrators расположено выше гостевого запрета.
В Kerio созданы те же роли; автоматическая идентификация привязана к 10.1.10.42 и 10.1.99.10. AppID включён. ContentFilter запрещает гостям 88 идентификаторов из категорий Chat, InstantMessenger, Peer-to-Peer, FileTransfer и TextMessagingSMS; исключение Administrators стоит первым. Тестовые пользователи имеют только права доступа к сети.
Проверка выполняет IRC-регистрацию с PING/PONG и BitTorrent-handshake с чтением 16384 байт контрольного файла. На стандартном и нестандартном портах гость блокируется, администратор проходит (рисунки @fig-c4-results, @fig-k-apps и @fig-k-content-events).

== IDS/IPS
«Континент»: профиль BKS4-IDS-Alert, HOME_NET 10.1.50.0/26. После этапа обнаружения в режим drop переведены веб-сигнатуры 4109359/4149401/4106447/4111038/4110964 и пользовательские правила 3900001 (SYN-поток),3900002 (SYN-сканирование),3900003 (XMAS). Остальной набор — 6794 сигнатуры alert.
В режиме обнаружения «Континент» зарегистрировал сигнатуры 4109359 и 4149401 с действием allowed (листинг @lst-c4-detection). После перевода в предотвращение тестовые воздействия блокируются; соответствующие записи приведены на рисунке @fig-c4-events.
#listing([«Континент»: события СОВ в режиме обнаружения], first-lines("outputs/continent-ids-events.txt", 2)) <lst-c4-detection>
Kerio: IPS включён, High/Medium/Low работают в Log and drop (рисунок @fig-k-ips-config). Сначала выполнены прогоны Log, затем предотвращения. Параметры и базы сохранены в итоговой конфигурации.
#figure(image("img/kerio-webadmin-ips.png", width: 100%), caption: [Kerio: режим предотвращения и версия базы IPS]) <fig-k-ips-config>

== Ложные срабатывания и исключения
В «Континенте» легитимный запрос документации `/docs?topic=/etc/passwd` блокировался SID 4149401. Исключение BKS4-Admin-Docs-IPS-Exception задаёт 10.1.99.10→192.168.100.2:8080 с обходом IPS: после него администратор получает 200, WAN продолжает блокироваться. В Kerio IRC на 16667 вызвал SID 1:2000345; этот SID добавлен в глобальные исключения, после чего IRC администратора проходит, а гостевой DPI сохраняет запрет. Также исключены информационные curl-сигнатуры 1:2002825 и 1:2013028.
#listing([«Континент»: контроль до и после исключения], first-lines("outputs/continent-docs-exception-before.txt", 3) + "\n" + first-lines("outputs/continent-docs-exception-after-admin.txt", 4) + "\n" + first-lines("outputs/continent-docs-exception-after-wan.txt", 4)) <lst-fp-c4>
#listing([Kerio: исключение ложного срабатывания IRC], read("outputs/kerio-ips-false-positive-exception.txt")) <lst-fp-k>
Исключения нужны для сохранения легитимного сервиса при совпадении с сигнатурой. Их область ограничивается доверенным источником либо конкретным SID; после изменения повторяются разрешённый и запрещённый сценарии.

= Результаты тестирования
Проверки выполнены на общей топологии поочерёдно для двух NGFW. Подробный прогон «Континента» датирован 07.11.2026, контроль обеих платформ —13–14.11.2026. Метки времени оригинальных выводов сохранены. В таблице @tab-tests собраны проверки, применимые к варианту 6.
#figure({set text(size: 8.5pt); table(columns: (1.25fr, 2.2fr, 2.2fr), align: left,
table.header([Проверка], [«Континент»], [Kerio]),
[LAN→WAN], [HTTP 200, SNAT], [HTTP 200, SNAT],
[Публикация DMZ], [8080/8443 доступны], [8080/8443 доступны],
[DMZ→LAN], [SSH timeout; blocked], [SSH timeout; DROP],
[EICAR/ZIP], [HTTP 403; событие AV], [Сброс/0 байт; EICAR-Test-File],
[HTTPS EICAR], [200/68 байт], [200/68 байт],
[DPI Guest/Admin], [Гость:4 таймаута; Admin:4 успеха], [Гость:4 прерывания; Admin:4 успеха],
[Сканирование WAN], [3900002 blocked; SYN:8 ответов из 120], [SSH:Log open; Drop filtered, SID 2001219],
[Веб-сигнатуры WAN], [Таймаут, nativeblocked], [Таймаут, Packetdrop],
[Веб-запросы LAN], [HTTP-прокси; сетевые проверки на 443], [Nginx404, HTTP-соединение разрешено],
[Управление], [444 только Management], [4081 только Management],
)}, caption: [Результаты проверок]) <tab-tests>

== «Континент 4»
Публикации доступны из WAN; неопубликованные сервисы и DMZ→LAN блокируются. Гость получает 403 для EICAR/ZIP и таймауты IRC/BitTorrent на 6667/16667/6881/16881. Администратор проходит все четыре протокольные проверки. Клиентские результаты и соответствующие поля нативных записей приведены на рисунках @fig-c4-results и @fig-c4-events; управление — на рисунке @fig-c4-mgmt.
Проверка API ЦУС с одинаковыми действующими учётными данными: из Management получен HTTP 200, из LAN и WAN — ConnectTimeout (листинг @lst-c4-management-access).
#listing([«Континент»: доступ к API ЦУС из трёх сегментов, 07.11.2026], read("outputs/continent-final-management.txt").split("\n").filter(x => x.starts-with("Data source:") or x.starts-with("Transport result:") or x.starts-with("HTTP status:") or x.starts-with("Authenticated read:")).map(x => x.split(" HTTPSConnectionPool").first()).join("\n")) <lst-c4-management-access>
#shot("img/c4-finish-results.png", [«Континент»: LAN→WAN, AV и протокольные проверки Guest/Admin]) <fig-c4-results>
#shot("img/c4-finish-events.png", [«Континент»: события изоляции, DPI, AV и IPS]) <fig-c4-events>
Nmap из WAN вызывает 3900002, SYN-поток —3900001; тестовые веб-запросы блокируются. Из 120 SYN ответ получен на 8. XMAS-пакеты теряются на stateful-фильтре. Из LAN HTTP проходит через AV-прокси; на форвардируемом 443 получены сетевые IPS-блокировки (листинг @lst-c4-lan-ips). Результат WAN-проверки показан на рисунке @fig-c4-ids.
#shot("img/continent-ids-current.png", [«Континент»: Nmap, веб-пробы, XMAS и SYN из WAN]) <fig-c4-ids>
#listing([«Континент»: сетевые IPS-проверки LAN→DMZ:443], first-lines("outputs/continent-final-ids-lan-443.txt", 17)) <lst-c4-lan-ips>

== Kerio Control
Публикации 8080/8443 доступны, порты 22/443 фильтруются (рисунок @fig-k-wan). События базовых разрешений, изоляции и защиты управления приведены на рисунке @fig-k-base-events; разрешённый доступ администратора — на рисунке @fig-k-admin.
#shot("img/kerio-tests-wan.png", [Kerio: публикации и доступ к управлению из WAN]) <fig-k-wan>
#shot("img/kerio-tests-admin.png", [Kerio: доступ из Management]) <fig-k-admin>
#shot("img/kerio-tests-dmz.png", [Kerio: изоляция DMZ→LAN]) <fig-k-dmz>
#shot("img/kerio-evidence-baseline-events.png", [Kerio: нативные события базовых разрешений и запретов]) <fig-k-base-events>
#shot("img/kerio-evidence-av.png", [Kerio: EICAR/ZIP по HTTP, HTTPS-контроль и нативные AV-детекты]) <fig-k-av>
#shot("img/kerio-apps-current.png", [Kerio: IRC/BitTorrent на двух портах для Guest/Admin]) <fig-k-apps>
#shot("img/kerio-events.png", [Kerio: пользователь, правило и приложение в событиях ContentFilter]) <fig-k-content-events>
Для проверки SSH-пробы временно разрешена публикация 22→DMZ:22 только с WAN-TEST. В Log Nmap определяет OpenSSH, журнал содержит Alert; в Drop порт filtered и Packetdrop по тому же SID 1:2001219. Временное правило после сравнения удалено (рисунки @fig-k-log и @fig-k-drop).
#shot("img/kerio-evidence-scan-log.png", [Kerio: результат Log и нативный Alert SSH-пробы]) <fig-k-log>
#shot("img/kerio-evidence-scan-drop.png", [Kerio: результат Drop и нативный Packetdrop SSH-пробы]) <fig-k-drop>
Одинаковые SQL-подобный URI и обход каталогов проверены из WAN и LAN. Из WAN — таймаут и Packetdrop; из LAN —404 от nginx и разрешённое HTTP-соединение (рисунки @fig-k-paths и @fig-k-path-events). IPS Kerio обрабатывает входящий трафик Internet Interfaces; прямой внутренний маршрут проходит по политике межсетевого экрана.
#shot("img/kerio-evidence-paths.png", [Kerio: результаты одинаковых веб-запросов LAN/WAN]) <fig-k-paths>
#shot("img/kerio-evidence-path-events.png", [Kerio: записи контрольного сравнения LAN/WAN]) <fig-k-path-events>

= Отчётность и мониторинг
== Журналирование и оповещения
Обе платформы отправляют syslog в Management на 10.1.99.10:514. У Kerio используется штатная настройка connection/filter/security/error/alert; у «Континента» — структурированные сообщения RFC5424. Сервер хранит исходные записи и формирует статистику.
Внешний монитор ADMIN-LINUX читает IPS-события узлов, AV-события Kerio и журнал ICAP «Континента», затем отправляет SNMP-уведомления на 10.1.99.10:162 с OID 1.3.6.1.3.9999.4.0.1. Проверяется точное совпадение пейлоада монитора и snmptrapd; отправитель уведомлений —10.1.99.10. Заключительный контроль «Континента» подтвердил 4 AV и 5 IPS уведомлений, Kerio — 2 AV и 2 IPS. Для каждого компонента ниже приведены итоговое число сопоставленных сообщений и один пейлоад с подтверждением приёма (листинги @lst-notify-c4-av–@lst-notify-k-ips).
#listing([«Континент»: доставка AV-уведомления внешним монитором], delivery-example("outputs/continent-finish-delivery.txt", "AV")) <lst-notify-c4-av>
#listing([Kerio: доставка AV-уведомления внешним монитором], delivery-example("outputs/kerio-finish-notifications.txt", "AV")) <lst-notify-k-av>
#listing([«Континент»: доставка IPS-уведомления внешним монитором], delivery-example("outputs/continent-finish-delivery.txt", "IPS")) <lst-notify-c4-ips>
#listing([Kerio: доставка IPS-уведомления внешним монитором], delivery-example("outputs/kerio-finish-notifications.txt", "IPS")) <lst-notify-k-ips>

== Статистические представления
#let secstats = json("outputs/continent-final-security-statistics.json")
Из накопленного журнала узла получены три представления: по пользователям, по распознанным приложениям и по правилам блокировки. Выборка содержит #(secstats.actions.allowed + secstats.actions.blocked) записей (#secstats.actions.allowed разрешений, #secstats.actions.blocked блокировок); единица учёта — запись журнала, а не соединение или байты.
#figure(table(columns: (2fr, 1fr), align: left,
[Пользователь], [Записей],
..secstats.by_user.map(row => ([#row.user], [#row.records])).flatten()),
caption: [Записи по пользователям]) <tab-c4-stat-users>
#figure(table(columns: (1fr, 1fr, 1fr), align: left,
[Приложение], [Действие], [Записей],
..secstats.by_recognized_application.map(row => ([#row.application], [#row.action], [#row.records])).flatten()),
caption: [Записи с распознанными приложениями]) <tab-c4-stat-apps>
#figure({set text(size: 9pt); table(columns: (4fr, 1fr), align: left,
[Правило], [Записей],
..secstats.blocked_by_rule.map(row => ([#row.rule], [#row.records])).flatten())},
caption: [Блокировки по правилам]) <tab-c4-stat-blocks>
Выводы: распределение по приложениям показывает срабатывания гостевого запрета; блокировки завершающего правила позволяют выявлять нежелательные обращения и уточнять политику.

Для Kerio сформированы представления по пользователям, распознанному содержимому и правилам (таблица @tab-kerio-stats). Единица учёта — запись журнала: пакетная блокировка, решение DPI, событие IPS и завершённое соединение считаются раздельно; сумма не равна числу соединений. Приложения взяты из нативного поля Content, а не угаданы по портам. Полная статистика, включая сервисы и источники, сохранена в JSON.
#let kstats = json("outputs/kerio-statistics-final.json")
#figure({set text(size: 9pt); table(columns: (1fr, 2.5fr, 0.6fr), align: left,
table.header([Представление], [Значение], [Записей]),
..kstats.by_user.pairs().map(((k,v)) => ([Пользователь], [#k], [#v])).flatten(),
..kstats.by_detected_content.pairs().map(((k,v)) => ([Content], [#k], [#v])).flatten(),
..kstats.by_rule.pairs().slice(0, 12).map(((k,v)) => ([Правило, первые 12], [#k], [#v])).flatten()
)}, caption: [Kerio: статистические представления после 15:57 UTC 13.11.2026]) <tab-kerio-stats>
По Kerio распределение Content подтверждает IRC/BitTorrent, имена пользователей — разделение ролей, частые WebAdmin-записи — нагрузку обслуживания. Перед изменением политики следует отделять служебные обращения от пользовательского трафика.

== Разбор инцидента
«Континент»,07.11.2026 13:38:27 МСК:192.168.100.1:2224→10.1.50.10:80 послеDNAT; SID 3900002 «TCP SYN port scan to DMZ», действие blocked. Через 0,4 с сработал 3900001 «SYN flood»; соответствующие SNMP-пейлоады получены АРМ.
Kerio,13.11.2026 23:46:14 МСК:192.168.100.1:44782→10.1.50.10:80, SID 1:2018288/2018289 (SQL-признак), Packetdrop. Клиент использовал публикацию 192.168.100.2:8080 и получил таймаут; событие видно на рисунке @fig-k-path-events. Реагирование определяется сопоставлением времени, адресов, сигнатуры и действия.

== Резервное копирование и восстановление
На каждой платформе создана штатная резервная копия, изменено описание одного объекта и выполнено восстановление. На «Континенте» восстановлен компонент CDC: исходное описание BKS4_WAN_TEST и контрольные хеши правил/адресов/сервисов вернулись. Kerio восстановлен через Configuration.apply: описание BKS4-LAN-DMZ-Web и семантические хеши семи разделов совпали. Результаты — листинги @lst-restore-c4 и @lst-restore-k. Архивы с сертификатами хранятся вне репозитория на АРМ и хосте PNETLab с правами 600.
#listing([«Континент»: результат штатного восстановления], read("outputs/continent-native-restore.txt").split("\n").filter(x => x.starts-with("Control change:") or x.starts-with("Original description restored:") or x.starts-with("FW/NAT/address/service fingerprints unchanged:") or (x.starts-with("Native restore task:") and x.contains("done"))).dedup().join("\n")) <lst-restore-c4>
#listing([Kerio: описание и контрольные хеши после восстановления], read("outputs/kerio-native-restore-verify.txt")) <lst-restore-k>

= Индивидуальное задание варианта 6
Веб-сервер DMZ опубликован на обеих платформах. Группа Guests ограничена по мессенджерам и файлообменным приложениям; администратор использует те же протоколы на стандартных и нестандартных портах (рисунки @fig-c4-results и @fig-k-apps).
GeoIP проверен при выключенном и включённом запрете US. На изолированном WAN эмулируются источники 5.255.255.5 (RU) и 8.8.8.8 (US); назначение — собственная публикация 192.168.100.2:8080. Без ограничения оба получают 200; при включении RU получает 200, US — таймаут. «Континент» фиксирует src_country=US и правило BKS4-GeoIP-Block-US-to-DMZ, Kerio — классификацию US (рисунки @fig-geo-c4 и @fig-geo-k). В Kerio фильтр глобален для входящего WAN, в «Континенте» привязан к публикации DMZ.
#shot("img/continent-evidence-geoip.png", [«Континент»: GeoIP off/on и нативная блокировка US]) <fig-geo-c4>
#shot("img/kerio-evidence-geoip.png", [Kerio: GeoIP off/on и нативная классификация US]) <fig-geo-k>

= Сравнительный анализ
#figure({set text(size: 9pt); table(columns: (1.1fr, 2.4fr, 2.4fr), align: left,
table.header([Критерий], [«Континент 4»], [Kerio Control]),
[Надёжность], [Хранение в ЦУС, отдельная установка политики; штатное восстановление CDC проверено по хешам], [Подтверждение изменений в одной конфигурации; штатное восстановление семи разделов проверено по хешам],
[Информационная безопасность], [Группы/портал, DPI, ICAP AV, IPS с пользовательскими сигнатурами, GeoIP; управление из Management], [Группы/AppID, встроенный AV, IPS входящего WAN, глобальный GeoIP; управление из Management],
[Быстродействие], [Установка политики 3–5 мин; HTTP через AV-прокси выполняется за десятки миллисекунд; события доставляются за единицы секунд], [Правила применяются без отдельной задачи установки; задержки протокольных тестов и блокировки отражаются в клиентских результатах],
[Сопровождение], [Windows-АРМ с CSP, работа с ЦУС и узлом; структурированные события упрощают разбор], [Один WebAdmin и JSON-RPC API; обновления и журналы доступны из общего интерфейса],
)}, caption: [Сравнение по собственным испытаниям]) <tab-compare>

= Заключение
На двух NGFW реализованы политика с запретом по умолчанию, NAT и публикация DMZ, антивирусная проверка HTTP, групповой контроль приложений, IDS/IPS, GeoIP и мониторинг. Для варианта 6 подтверждены запрет гостевых приложений независимо от порта, исключение администратора и изменение доступа при GeoIP off/on. Проведены разбор ложных срабатываний и инцидентов, статистический анализ и контрольное восстановление конфигураций.
Для эксплуатации следует ограничивать область исключений, регулярно обновлять базы и анализировать события по пользователям и приложениям. HTTPS-контент в данной схеме передаётся в зашифрованном виде; результаты HTTP и HTTPS оцениваются раздельно.
