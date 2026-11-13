#import "@local/mephi-lab:0.1.0": lab-report
#show: lab-report.with(lab-number: 4, topic: "Установка и конфигурирование комплексных аппаратно-программных межсетевых экранов (UTM/NGFW)", discipline: "Безопасность компьютерных сетей", student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."), group: "Б23-505", teacher: "Басыня Е. А.")
#let listing(caption, body) = figure({
  show raw: set text(size: 8pt)
  let wrapped = if body.trim() == "" { "(Нет сохранённого вывода; проверка не подтверждена.)" } else {
    body.trim().split("\n").map(line => if line == "" { "" } else {
      line.clusters().chunks(90).map(chunk => chunk.join("")).join("\n")
    }).join("\n")
  }
  raw(wrapped, block: true)
}, caption: caption, kind: raw)
#let names(v) = if v == none { "—" } else if v.len() == 0 { "любой" } else { v.join(", ") }

= Цель работы
Развернуть на изолированном стенде два UTM/NGFW — Kerio Control 10.0.1 и «Континент 4.2.1», построить на каждом политику «запрещено всё, что явно не разрешено», настроить NAT и публикацию веб-сервера DMZ, антивирусную проверку, контроль приложений, IDS/IPS, журналирование и оповещения, выполнить набор тестов и сравнить платформы. Индивидуальное задание (вариант 6): веб-сервер в DMZ, запрет мессенджеров и файлообменных сервисов для группы «Гости», ограничение доступа к DMZ по географическому признаку и сравнение с вариантом без ограничения.

= Краткая характеристика платформ и критерии сравнения
Kerio Control (GFI) — программный UTM на Linux с единым веб-интерфейсом администрирования (порт 4081) и JSON-RPC API; защитные модули (антивирус, IPS, контроль приложений) активируются лицензией после онлайн-регистрации. «Континент 4» («Код Безопасности») — сертифицированный NGFW с выделенным центром управления сетью (ЦУС), Менеджером конфигурации на Windows и REST API ЦУС (порт 444, ГОСТ TLS); изменение политики — это правка конфигурации в ЦУС с последующей установкой на узел безопасности.

Платформы сравниваются по критериям методички: надёжность и отказоустойчивость, информационная безопасность, быстродействие, трудоёмкость сопровождения. Выводы в разделе сравнения опираются только на собственные измерения и наблюдения на стенде.

= Топология стенда и адресация
Стенд выделен в отдельную лабораторную BKS4 на сервере PNETLab; предыдущие БКС1–3 сохранены. Обе платформы используют одинаковые адреса интерфейсов и одни и те же тестовые машины, поэтому включаются поочерёдно. Схема приведена на рисунке @fig-topology, адресация — в таблице @tab-addressing.
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
Подсеть DMZ /26 сохранена из предыдущих работ. У Linux-машин есть служебные OOB-интерфейсы (192.168.15.0/24) для установки пакетов и сбора результатов; в испытаниях всегда явно выбирается рабочий исходный адрес, для которого отдельная таблица маршрутизации направляет трафик через NGFW (рисунок @fig-source-route). WAN-TEST и DMZ-WEB используют соответствующие интерфейсы NGFW как шлюз по умолчанию.
#figure(image("img/lan-source-route.png", width: 100%), caption: [Рабочий исходный адрес LAN и маршрут через NGFW]) <fig-source-route>

== Подготовка тестовых машин
Созданы самостоятельные тонкие диски на базе Ubuntu 22.04. Установлены nginx, curl, nmap, hping3, rsyslog, snmptrapd. WAN-TEST транслирует адреса 192.168.100.0/24 наружу, предоставляет DNS (dnsmasq) и NTP (chrony) для стенда (листинг @lst-wan-bootstrap). На DMZ-WEB и WAN-TEST размещены контрольный файл `allowed.txt`, стандартный безвредный EICAR и ZIP-архив с ним; для HTTPS выпущены учебные сертификаты. Локальная проверка DMZ-сервера — листинг @lst-web-local.
#listing([Подготовка тестовых машин и внешнего NAT], read("commands/bootstrap-host.sh")) <lst-wan-bootstrap>
#listing([Локальная проверка веб-сервера DMZ], read("outputs/dmz-web-local-check.txt")) <lst-web-local>
Для контроля приложений на WAN-TEST подняты собственные IRC-сервер (inspircd, порты 6667 и 16667) и BitTorrent-раздача (transmission, порты 6881 и 16881) без внешних трекеров и DHT; клиент выполняет регистрацию IRC с PING/PONG и настоящий BitTorrent-handshake с чтением 16 КиБ безвредного файла (листинг @lst-app-control).
#listing([Локальный контроль тестовых серверов приложений], read("outputs/app-servers-local-control.txt")) <lst-app-control>

= Установка и базовая настройка
== «Континент 4»
Образы ЦУС и узла безопасности из учебного архива перенесены из VMware в QEMU; после переноса штатно применено именование интерфейсов te-0-0…te-3-0. Выполнена инициализация «Узел безопасности с ЦУС» (RSA и ГОСТ), выпущены корневой BKS4 Lab CA и сервисный сертификат ncc.bks4.test, Management назначен te-3-0 с адресом 10.1.99.1/24. На АРМ ADMIN-WIN установлены Менеджер конфигурации 4.2.1.653 и «Код Безопасности CSP» (листинг @lst-admin-installed), системная локаль ru-RU. Импортирована учебная лицензия; Менеджер показывает срок действия до 31.12.2026 и доступные защитные модули (рисунок @fig-continent-license). Версия ПО узла 4.2.1-653; импортирован подписанный пакет решающих правил СОВ 4.2.1.53 от 18.04.2025 (более свежий пакет в учебном архиве отсутствует). Время синхронизируется с NTP 192.168.100.1, часовой пояс Europe/Moscow.
#listing([Установленные компоненты АРМ], read("outputs/admin-win-installed.txt")) <lst-admin-installed>
#figure(image("img/continent-license.png", width: 100%), caption: [Учебная лицензия, привязанная к узлу «Континента»]) <fig-continent-license>
Доступ к управлению ЦУС ограничен сетью Management: с одинаковыми действующими реквизитами API 444 читается только с 10.1.99.10, из LAN и WAN соединение не устанавливается (листинг @lst-c4-management).
#listing([Доступ к управлению ЦУС с рабочих адресов сегментов], read("outputs/continent-final-management.txt")) <lst-c4-management>

== Kerio Control
Kerio Control 10.0.1 build 9439 развёрнут из официального образа. Изменён пароль Admin, назначены адреса таблицы @tab-addressing, NTP 192.168.100.1 и часовой пояс Москва. 13.11.2026 завершена штатная регистрация trial на 25 пользователей до 06.12.2026: `licenseSet=true`, `rsTrialRegistered`, `LoginRegular`. Состояние сохранилось после нативного восстановления конфигурации (листинг @lst-kerio-status, рисунок @fig-kerio-status).
#listing([Лицензия и фактическое состояние модулей Kerio после восстановления], read("outputs/kerio-status-final.txt")) <lst-kerio-status>
#figure(image("img/kerio-status.png", width: 100%), caption: [Текущее состояние Kerio, прочитанное через штатный API с АРМ]) <fig-kerio-status>
IPS, контроль приложений, GeoIP, журналы и штатный экспорт доступны. Антивирус лицензирован, но остаётся `AntivirusWaitingForInitialDb`: первоначальная база не загрузилась, обновление завершилось ошибкой. IPS использует работоспособную установленную базу 5.0/2.1215; попытка её обновления также дала Download error. Поэтому доступность лицензии и актуальность защитных баз оцениваются раздельно.

Администрирование Kerio 4081 доступно из Management; из LAN и WAN обращения завершаются таймаутом (листинги @lst-kerio-lan, @lst-kerio-wan и @lst-kerio-admin). Порт 4080 также включён в явное запрещающее правило вне Management; актуальные клиентские испытания относятся к 4081.

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
Принципы: внутренний трафик между LAN, DMZ и Management не транслируется; LAN и Management выходят наружу через SNAT; веб-сервер опубликован на 192.168.100.2:8080 и :8443 с переводом в 80/443, причём правило фильтрации задаётся по исходному адресу и порту до DNAT. Порядок правил существенен: правила с HTTP-профилем антивируса стоят выше правила контроля приложений, иначе поток, перехваченный прокси, удерживается DPI (раздел контроля приложений); явный запрет LAN → DMZ для остальных сервисов стоит сразу после веб-правил и до DPI, чтобы отбрасывать соединения на первом пакете с записью в журнал.

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
Для смешанных наборов HTTP/HTTPS и DNS/NTP используются штатные объекты сервисов. При чтении политики после новой API-сессии проверяется полный набор ссылок; правила ICMP содержат только объект «Any ICMP». Правило BKS4-Syslog разрешает UDP/514 с самого шлюза к 10.1.99.10; его собственное журналирование выключено, чтобы не создавать поток записей о пересылке журналов.

Существенная особенность API Kerio: изменения `TrafficPolicy.set` применяются сразу, но считаются ожидающими подтверждения; их нужно закрепить вызовом `Session.confirmConfig` со списком меток времени из `Session.getConfigTimestamp`, иначе при завершении сессии конфигурация откатывается. Это было выявлено на стенде и учтено в `tools/kerio-policy-fix.py`.

== Сопоставление принципов
Обе платформы обрабатывают правила сверху вниз до первого совпадения, с запретом по умолчанию. «Континент» оперирует именованными объектами, группами пользователей и профилями модулей, прикреплёнными к правилу; изменения накапливаются в ЦУС и устанавливаются на узел задачей (3–5 минут на стенде). Kerio объединяет фильтрацию и NAT в одной строке правила и применяет изменения мгновенно; зоны выражаются интерфейсными объектами (`InterfaceInternet`, `Firewall`).

= Модули защиты
== Антивирусная проверка на шлюзе («Континент»)
Встроенный антивирус «Континента» использует внешний ICAP-сервер; на ADMIN-LINUX развёрнуты c-icap с модулем virus_scan и ClamAV (листинг @lst-icap-config). Профиль BKS4-HTTP-AV (ICAP 10.1.99.10:1344, RESPMOD, fail-closed) привязан ко всем HTTP-правилам LAN, DMZ и Management. HTTPS проходит отдельными правилами без TLS-инспекции (вариантом не предусмотрена).
#listing([Настройка сервера ICAP], read("commands/configure-icap.sh")) <lst-icap-config>
Результат для гостя LAN и администратора: контрольный файл HTTP 200, EICAR и ZIP с EICAR — HTTP 403 со страницей «VIRUS FOUND» от C-ICAP на серверах DMZ и WAN; по HTTPS получены исходные 68 байт EICAR с тем же SHA-256, что у файла на сервере (листинги @lst-c4-av-guest, @lst-c4-av-admin, @lst-c4-https-origin). Без TLS-инспекции шлюз видит только SNI и не может проверить содержимое HTTPS — это ожидаемое поведение.
#listing([Антивирус через шлюз, гость LAN 10.1.10.42], read("outputs/continent-final-av-guest.txt")) <lst-c4-av-guest>
#listing([Антивирус через шлюз, администратор 10.1.99.10], read("outputs/continent-final-av-admin.txt")) <lst-c4-av-admin>
#listing([Исходный файл и сертификат сервера], read("outputs/https-origin-reference.txt")) <lst-c4-https-origin>
На Kerio встроенный антивирус доступен по лицензии, но не готов к проверке: первоначальная база отсутствует. В итоговом тесте EICAR и ZIP по HTTP из LAN получены полностью (68 и 186 байт, HTTP 200; листинг @lst-kerio-lan). Детект вируса и антивирусное оповещение Kerio не подтверждены. HTTPS используется без TLS-инспекции; его успешная передача сама по себе не проверяет AV.

== Пользователи, группы и контроль приложений («Континент»)
Созданы локальные пользователи labguest и lab-admin в группах BKS4 Guests и BKS4 Administrators. Идентификация на LAN — штатный портал аутентификации auth.bks4.test на 10.1.10.1 с отдельным RSA-сертификатом; до входа HTTP гостя перенаправляется на портал. Вход гостя и администратора выполняется с разных адресов (10.1.10.42 и 10.1.99.10), так как смена пользователя на одном адресе без выхода оставляет прежнюю привязку (листинги @lst-c4-guest-login и @lst-c4-admin-login).
#listing([Аутентификация гостя через портал], read("outputs/continent-guest-login.txt")) <lst-c4-guest-login>
#listing([Аутентификация администратора], read("outputs/continent-admin-login.txt")) <lst-c4-admin-login>
Правило BKS4-Guests-Block-Messengers-P2P запрещает группе Guests приложения IRC, Jabber, BitTorrent и категории Chat и FileSharing для любых получателей и любых портов; выше него стоит исключение BKS4-Administrators-Lab-Protocol-Exception для группы администраторов. Отдельные ограничения по URL-категориям и типам файлов вариантом 6 не заданы.

Первоначально правило контроля приложений стояло выше правил с HTTP-профилем антивируса, и после входа гостя любой HTTP зависал: запрос перехватывался прокси, а классификатор приложений удерживал поток (захват на хосте показал только TCP-handshake наружу без GET и без обращения к ICAP). Перенос веб-правил LAN выше правила DPI устранил проблему. Второе наблюдение: при правиле контроля приложений «любой сервис» TCP-handshake и первые байты неизвестного протокола (баннер SSH) проходят до классификации, после чего поток молча прерывается без записи в журнал; поэтому добавлен явный запрет BKS4-Deny-LAN-to-DMZ-Other до правила DPI — теперь SSH из LAN в DMZ отбрасывается на первом пакете с событием журнала (листинг @lst-c4-events).

Результат: гость получает таймаут на IRC 6667/16667 и BitTorrent 6881/16881, администратор проходит все четыре проверки; при этом обычный HTTP гостя работает, а EICAR блокируется (листинги @lst-c4-apps-guest и @lst-c4-apps-admin).
#listing([Гость: IRC и BitTorrent заблокированы независимо от порта], read("outputs/continent-final-apps-guest.txt")) <lst-c4-apps-guest>
#listing([Администратор: исключение разрешает те же приложения], read("outputs/continent-final-apps-admin.txt")) <lst-c4-apps-admin>

== Пользователи и контроль приложений Kerio
Штатные группы Guests и Administrators содержат labguest и lab-admin. Для изолированного стенда настроена автоматическая идентификация по рабочим адресам 10.1.10.42 и 10.1.99.10; это не проверка пароля через портал. Оба тестовых пользователя не имеют прав изменения конфигурации. В ContentFilter исключение Administrators стоит выше запрета Guests. Запрещены 88 идентификаторов приложений из категорий Chat, InstantMessenger, Peer-to-Peer, FileTransfer и TextMessagingSMS. Модуль AppID включён; точные условия сохранены в `configs/kerio-content-policy.json`.
Четыре правила МЭ разрешают тестовые TCP-порты только к собственному WAN-TEST; решение DPI принимается по протоколу и группе. Администратор проходит IRC-регистрацию и PING/PONG, получает 16384 байта BitTorrent на каждом порту. Гость после TCP-handshake получает reset/timeout на всех четырёх портах; нативный filter содержит labguest, запрещающее правило и IRC либо BitTorrent (листинги @lst-k-app-admin, @lst-k-app-guest, @lst-kerio-events). Начальное установление TCP не считается успешной передачей приложения.
#listing([Kerio: исключение администратора, два порта каждого протокола], read("outputs/kerio-apps-admin.txt")) <lst-k-app-admin>
#listing([Kerio: запрет приложений для гостя], read("outputs/kerio-apps-guest.txt")) <lst-k-app-guest>
#figure(image("img/kerio-apps-current.png", width: 100%), caption: [Kerio: результаты протокольных тестов администратора и гостя]) <fig-k-app-current>

== IDS/IPS («Континент»)
Профиль BKS4-IDS-Alert создан из вендорской базы (33 964 сигнатуры) сначала в режиме обнаружения (рисунок @fig-ids-settings); HOME_NET задан как сеть DMZ 10.1.50.0/26. В режиме обнаружения из WAN зарегистрированы Nmap User-Agent (SID 4109359) и `/etc/passwd` в URI (SID 4149401) с действием allowed (листинг @lst-c4-ids-events).
#figure(image("img/continent-ids-alert-settings.png", width: 100%), caption: [Профиль СОВ в режиме обнаружения]) <fig-ids-settings>
#listing([События в режиме обнаружения], read("outputs/continent-ids-events.txt")) <lst-c4-ids-events>
Для режима предотвращения выбран оптимальный вендорский набор (6794 сигнатуры в alert) и восемь сигнатур в drop: подтверждённые веб-сигнатуры 4109359, 4149401, 4106447, 4111038, 4110964 и три пользовательские сигнатуры (листинг @lst-c4-user-sigs). Вендорские сигнатуры сканирования имеют высокие пороги и `noalert`, поэтому сканирование и SYN-поток обнаруживаются пользовательскими правилами по частоте SYN от одного источника; XMAS-пакеты описаны отдельной сигнатурой. Пользовательские сигнатуры загружены через API `/ipssignature` и проверены узлом.
#listing([Пользовательские сигнатуры СОВ], read("configs/continent-ips-user-signatures.txt")) <lst-c4-user-sigs>

== IDS/IPS Kerio
Сначала для всех уровней выбран режим Log. Контрольный SQL-подобный URI к опубликованному собственному nginx получает HTTP 404, а native security содержит Alert (SID 1:2011037 и 1:2006446). Затем для High/Medium включён DropAndLog, Low оставлен Log. Тот же тип запроса получает таймаут и Packet drop; точные URI под установленные сигнатуры SQL и обхода пути также блокируются (листинги @lst-k-ids-alert, @lst-k-ips-web). На сервере нет Joomla/Magento или уязвимого приложения: проверяется распознавание безвредных строк, выполнение атаки не производится.
#listing([Kerio: тест в режиме обнаружения], read("outputs/kerio-ids-alert-wan.txt")) <lst-k-ids-alert>
#listing([Kerio: веб-сигнатуры в режиме предотвращения], read("outputs/kerio-ips-web-signatures.txt")) <lst-k-ips-web>
Nmap из WAN обнаруживается сигнатурой 1:2001219 ET SCAN Potential SSH Scan с действием Alert; неопубликованные порты фильтрует МЭ. Подавление портового сканирования именно IPS не подтверждено. Для XMAS зарегистрированы предупреждения декодера, их наличие не доказывает блокировку сканирования. Из LAN прямые тестовые HTTP-URI к DMZ получают 404 без соответствующего свежего IPS-события (листинг @lst-k-ips-lan): этот путь не выдаётся за подтверждённую защиту от веб-атак.
#listing([Kerio: контроль тех же URI из LAN], read("outputs/kerio-ips-web-lan.txt")) <lst-k-ips-lan>

== Журналирование и оповещения («Континент»)
События узла отправляются по syslog (RFC 5424, структурированные данные) на 10.1.99.10:514 и сохраняются на ADMIN-LINUX. Настроен SNMP v2 только на интерфейсе Management с trap-получателем 10.1.99.10:162; штатный LinkUp подтверждает работу SNMP. Для оповещений об IPS и антивирусе на ADMIN-LINUX работает внешний монитор: он читает syslog узла и журнал ICAP и отправляет SNMP-уведомления в экспериментальную ветвь OID 1.3.6.1.3.9999.4 (листинги @lst-trap-receiver и @lst-trap-services).
#listing([Проверка служб оповещений], read("commands/check-alert-services.sh")) <lst-trap-receiver>
#listing([Состояние служб и привязка порта SNMP], read("outputs/continent-alert-services.txt")) <lst-trap-services>

= Результаты тестирования
Итоговый прогон выполнен на «Континенте» 07.11.2026 с 10:37 до 10:44 UTC после установки итоговой политики (задача 76d7bac5); нативные события того же интервала собраны в листинге @lst-c4-events (время в журнале узла — МСК). Сводка по минимальному набору тестов — таблица @tab-tests.
#figure({set text(size: 8pt); table(columns: (0.3fr, 1.6fr, 2.6fr, 2.2fr), align: left,
table.header([№], [Проверка], [«Континент 4»], [Kerio Control]),
[1], [LAN → Интернет], [HTTP 200, SNAT за 192.168.100.2 (@lst-c4-lan)], [HTTP 200 (@lst-kerio-lan)],
[2], [Публикация DMZ], [HTTP 8080 и HTTPS 8443 — 200; порт 22 filtered (@lst-c4-wan, @lst-c4-ids-wan)], [8080/8443 — 200, порт 22 timeout (@lst-kerio-wan)],
[3], [Изоляция DMZ → LAN], [SSH timeout, событие BKS4-Deny-DMZ-to-LAN (@lst-c4-dmz, @lst-c4-events)], [SSH timeout (@lst-kerio-dmz)],
[4], [Антивирус], [EICAR и ZIP — 403, события appfilter blocked (@lst-c4-av-guest)], [Лицензирован, первоначальная база не загружена; EICAR/ZIP 200 (@lst-kerio-lan)],
[5], [Веб-фильтр], [не задан вариантом; HTTP гостя проходит только через AV-прокси], [Отдельные URL-категории вариантом не заданы; AppID включён],
[6], [Исключение для администратора], [IRC/BitTorrent разрешены lab-admin (@lst-c4-apps-admin)], [IRC/BitTorrent разрешены lab-admin (@lst-k-app-admin)],
[7], [Контроль приложений], [IRC и BitTorrent заблокированы гостю на 6667/16667/6881/16881 (@lst-c4-apps-guest)], [Гостю запрещены оба протокола на четырёх портах (@lst-k-app-guest)],
[8], [IDS/IPS: сканирование], [SID 3900002 и 3900001 blocked, 8 из 120 SYN прошли (@lst-c4-ids-wan, @lst-c4-events)], [Сканирование обнаружено SID 1:2001219; подавление IPS не подтверждено (@lst-kerio-events)],
[9], [IDS/IPS: веб-атака], [SID 4109359, 4149401 blocked, таймаут клиента (@lst-c4-ids-wan)], [WAN: SQL/path traversal Packet drop, таймаут (@lst-k-ips-web); LAN: 404 без детекта],
[10], [Доступ к управлению], [API 444 только из Management (@lst-c4-management)], [4081 только из Management (@lst-kerio-lan, @lst-kerio-wan, @lst-kerio-status)],
)}, caption: [Минимальный набор тестов на двух платформах]) <tab-tests>

== «Континент 4»
#listing([Базовая политика: LAN], read("outputs/continent-final-base-lan.txt")) <lst-c4-lan>
#listing([Базовая политика: опубликованный веб-сервер из WAN], read("outputs/continent-final-base-wan.txt")) <lst-c4-wan>
#listing([Базовая политика: администратор], read("outputs/continent-final-base-admin.txt")) <lst-c4-admin>
#listing([Базовая политика: изоляция DMZ], read("outputs/continent-final-base-dmz.txt")) <lst-c4-dmz>
Проверка IDS/IPS из WAN: контрольный запрос разрешён; `nmap -sS -sV` видит только опубликованные порты (SYN на неопубликованные порты отбрасывает межсетевой экран ещё до СОВ), а десять SYN версии сервисов превышают порог пользовательской сигнатуры; запросы с Nmap User-Agent, UNION SELECT и `/etc/passwd` завершаются таймаутом; XMAS-пакеты отбрасываются stateful-фильтром без доставки в СОВ; из 120 SYN-пакетов hping3 после срабатывания сигнатур ответ получили 8 (листинг @lst-c4-ids-wan).
#listing([IDS/IPS из WAN], read("outputs/continent-final-ids-wan.txt")) <lst-c4-ids-wan>
Из LAN HTTP к DMZ терминируется прокси антивируса, поэтому СОВ не видит исходных запросов клиента (листинг @lst-c4-ids-lan). Сетевые сигнатуры из LAN проверены на форвардируемом порту 443: SYN-поток и сканирование обнаружены и заблокированы (листинг @lst-c4-ids-lan-443).
#listing([IDS/IPS из LAN через HTTP-прокси], read("outputs/continent-final-ids-lan.txt")) <lst-c4-ids-lan>
#listing([Сетевые сигнатуры из LAN на порту 443], read("outputs/continent-final-ids-lan-443.txt")) <lst-c4-ids-lan-443>
#listing([Нативные события итогового прогона], read("outputs/continent-final-events.txt")) <lst-c4-events>

#strong[Контроль сохранённого стенда 13.11.2026]
После повторного запуска узла выгрузка по API содержит те же 21 правило МЭ и 4 правила NAT, что и сохранённые итоговые сводки. Проверки ниже относятся к отдельному прогону 13.11; они не заменяют датировку полного прогона 07.11 в таблице @tab-tests.
С Management выполнено аутентифицированное чтение политики; HTTP/SSH к DMZ доступны, DMZ → LAN SSH блокируется (рисунки @fig-c4-management-current и @fig-c4-isolation-current). На LAN повторены HTTP-контроль, EICAR и ZIP через DMZ/WAN, а также EICAR по HTTPS без инспекции: 200/403/403 и 200 соответственно (рисунок @fig-c4-av-current).
#figure(image("img/continent-management-current.png", width: 100%), caption: [«Континент»: доступ администратора и чтение политики после запуска]) <fig-c4-management-current>
#figure(image("img/continent-isolation-current.png", width: 100%), caption: [«Континент»: текущая проверка изоляции DMZ → LAN]) <fig-c4-isolation-current>
#figure(image("img/continent-av-current.png", width: 100%), caption: [«Континент»: текущие AV-проверки гостя при работающем контроле приложений]) <fig-c4-av-current>
Гостевой протокольный тест завершается таймаутом на четырёх портах; администратор регистрируется в IRC и получает по 16384 байта BitTorrent на стандартном и нестандартном портах (рисунки @fig-c4-guest-current и @fig-c4-admin-current). Идентичность полученного блока подтверждена SHA256 `98ac455a76358d52eb1a64d3797e84d1946a3472e01e3bb1f1690409b6730244`. В журнале присутствуют имена labguest/lab-admin и соответствующие правила; журнал может агрегировать повторяющиеся события.
#figure(image("img/continent-apps-guest-current.png", width: 100%), caption: [«Континент»: запрет IRC/BitTorrent для гостя на двух портах каждого протокола]) <fig-c4-guest-current>
#figure(image("img/continent-apps-admin-current.png", width: 100%), caption: [«Континент»: исключение администратора с передачей блока данных]) <fig-c4-admin-current>
Проверка из WAN обнаруживает опубликованные сервисы и TLS-службу самого шлюза на 443; наличие TCP/TLS на 443 не означает доступ к API ЦУС на 444. СОВ фиксирует блокировки SID 3900002 (сканирование), 3900001 (SYN-поток) и 4109359 (Nmap User-Agent); для XMAS подтверждена только потеря пакетов, отдельного события СОВ нет. Нативные записи и доставка уведомлений сопоставлены по времени: подтверждены четыре AV- и три IPS-уведомления (рисунок @fig-c4-events-current; полные выводы в листингах @lst-c4-demo-ids, @lst-c4-demo-av-delivery и @lst-c4-demo-delivery).
#figure(image("img/continent-ids-current.png", width: 100%), caption: [«Континент»: текущий ограниченный тест из WAN]) <fig-c4-ids-current>
#figure(image("img/continent-events-current.png", width: 100%), caption: [«Континент»: текущие нативные блокировки и проверка доставки уведомлений]) <fig-c4-events-current>
#listing([«Континент»: полный контрольный IDS/IPS-прогон 13.11.2026], read("outputs/continent-demo-ids-wan.txt")) <lst-c4-demo-ids>
#listing([«Континент»: доставка четырёх текущих AV-уведомлений], read("outputs/continent-demo-av-delivery.txt")) <lst-c4-demo-av-delivery>
#listing([«Континент»: доставка трёх текущих IPS-уведомлений], read("outputs/continent-demo-ips-delivery.txt")) <lst-c4-demo-delivery>
GeoIP при включённом правиле повторно даёт HTTP 200 для эмулированного RU-источника и таймаут для US. После повторного US-запроса получена нативная блокировка BKS4-GeoIP-Block-US-to-DMZ. В этом контрольном прогоне правило не отключалось; сравнение off/on относится к сохранённому эксперименту 07.11 в разделе индивидуального задания.

== Kerio Control
Итоговые проверки 13.11.2026 выполнены после нативного восстановления и удаления временного SSH-доступа. HTTP/HTTPS и DNS/NTP разрешены, запрещённые SSH-соединения и управление вне Management блокируются. EICAR и ZIP получают HTTP 200: антивирус лицензирован, но не работает без первоначальной базы. Результаты показаны на рисунках @fig-kerio-lan, @fig-kerio-wan, @fig-kerio-dmz и @fig-kerio-admin.
#listing([Kerio: проверки из LAN], read("outputs/kerio-final-lan.txt")) <lst-kerio-lan>
#figure(image("img/kerio-tests-lan.png", width: 100%), caption: [Kerio: LAN, EICAR, ограничение управления, DNS и NTP]) <fig-kerio-lan>
#listing([Kerio: проверки из WAN], read("outputs/kerio-final-wan.txt")) <lst-kerio-wan>
#figure(image("img/kerio-tests-wan.png", width: 100%), caption: [Kerio: публикация DMZ и фильтрация внешних портов]) <fig-kerio-wan>
#listing([Kerio: изоляция DMZ], read("outputs/kerio-final-dmz.txt")) <lst-kerio-dmz>
#figure(image("img/kerio-tests-dmz.png", width: 100%), caption: [Kerio: запрещённое соединение DMZ → LAN]) <fig-kerio-dmz>
#listing([Kerio: разрешённый доступ администратора], read("outputs/kerio-final-admin.txt")) <lst-kerio-admin>
#figure(image("img/kerio-tests-admin.png", width: 100%), caption: [Kerio: доступ из Management к DMZ и управлению шлюзом]) <fig-kerio-admin>

= Отчётность и мониторинг
== Доставка оповещений
После итогового прогона проверка доставки сопоставила записи монитора с payload, принятыми snmptrapd: восемь AV-уведомлений (EICAR и ZIP на DMZ и WAN для гостя и администратора) и пять IPS-уведомлений (SID 3900001, 3900002, 4109359, 4149401) найдены точно (листинги @lst-c4-av-alerts и @lst-c4-ips-alerts).
#listing([Доставка AV-уведомлений], read("outputs/continent-final-av-alerts.txt")) <lst-c4-av-alerts>
#listing([Доставка IPS-уведомлений], read("outputs/continent-final-ips-alerts.txt")) <lst-c4-ips-alerts>

Для Kerio включена штатная отправка connection/filter/security/error/alert через syslog на 10.1.99.10:514; APP-NAME имеет вид `kerio-*`, facility Local0. Старый файловый агент отключён и исключён из автозапуска. Получены нативные решения DPI с пользователем и приложением, события IPS Alert/Packet drop и записи межсетевого экрана (листинг @lst-kerio-events, рисунок @fig-kerio-events). Выборка содержит представительные записи, статистика ниже подсчитана по всему интервалу.
Внешний монитор ADMIN-LINUX преобразует реальные IPS-события Kerio в SNMP-уведомления с лабораторным OID 1.3.6.1.3.9999.4.0.1. Точное совпадение JSON-пейлоада монитора и snmptrapd проверено (листинг @lst-k-delivery). Это уведомления внешнего монитора 10.1.99.10, а не нативные Kerio SNMP traps. AV-уведомления Kerio не проверены: исходного вирусного детекта нет.
#listing([Kerio: полученные нативные события], read("outputs/kerio-events-final.txt")) <lst-kerio-events>
#figure(image("img/kerio-events.png", width: 100%), caption: [Kerio: реальные решения DPI и IPS в syslog АРМ]) <fig-kerio-events>
#listing([Kerio: доставка IPS-уведомлений внешнего монитора], read("outputs/kerio-ips-delivery.txt")) <lst-k-delivery>

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
Управленческие выводы: записи без имени пользователя (трафик до входа через портал и внешние источники) требуют сопоставления с данными аутентификации; распределение по приложениям показывает, что ограничение для гостей реально срабатывает, а не остаётся декларацией; большинство блокировок приходится на завершающий запрет — их следует регулярно разбирать по адресам и сервисам, чтобы отличать ожидаемое отбрасывание от пробелов политики.

Для Kerio сформированы представления по пользователям, распознанному содержимому и правилам (таблица @tab-kerio-stats). Единица учёта — запись журнала: пакетная блокировка, решение DPI, событие IPS и завершённое соединение считаются раздельно; сумма не равна числу соединений. Приложения взяты из нативного поля Content, а не угаданы по портам. Полная статистика, включая сервисы и источники, сохранена в JSON.
#let kstats = json("outputs/kerio-statistics-final.json")
#figure({set text(size: 9pt); table(columns: (1fr, 2.5fr, 0.6fr), align: left,
table.header([Представление], [Значение], [Записей]),
..kstats.by_user.pairs().map(((k,v)) => ([Пользователь], [#k], [#v])).flatten(),
..kstats.by_detected_content.pairs().map(((k,v)) => ([Content], [#k], [#v])).flatten(),
..kstats.by_rule.pairs().slice(0, 12).map(((k,v)) => ([Правило, первые 12], [#k], [#v])).flatten()
)}, caption: [Kerio: статистические представления после 15:57 UTC 13.11.2026]) <tab-kerio-stats>
Практические выводы: именованные решения позволяют проверить разделение Guests/Administrators; распознанные IRC и BitTorrent подтверждают работу AppID на нестандартных портах; частые WebAdmin и пакетные записи нельзя трактовать как активность обычных пользователей. Low Alert при сканировании требует отдельной реакции администратора, поскольку выбранный режим лишь регистрирует это событие.

== Разбор инцидента
По метке времени итогового IPS-теста в журнале (листинг @lst-c4-events) событие `2026-11-07 13:38:27 МСК`: источник 192.168.100.1, порт 2224, цель 10.1.50.10:80 (адрес после DNAT публикации 192.168.100.2:8080), сигнатура 3900002 «BKS4 TCP SYN port scan to DMZ», действие blocked; через 0,4 с — 3900001 «SYN flood», blocked. Соответствующие SNMP-уведомления получены на АРМ (листинг @lst-c4-ips-alerts). Запись содержит все данные для реагирования: время, адреса, сигнатуру и действие.

== Ложное срабатывание и исключение
Учебная страница документации на DMZ принимает параметр `topic`; легитимный запрос `/docs?topic=/etc/passwd` с АРМ блокировался сигнатурой 4149401 (листинги @lst-c4-docs-before и @lst-c4-docs-before-event). Добавлено правило BKS4-Admin-Docs-IPS-Exception: только 10.1.99.10 → 192.168.100.2:8080 без передачи в СОВ (листинг @lst-c4-docs-rule). После установки запрос с АРМ получает HTTP 200, из WAN — таймаут и blocked по той же сигнатуре (листинги @lst-c4-docs-after-admin, @lst-c4-docs-after-wan). Блокировка без исключений недопустима в эксплуатации: одна сигнатура по строке в URI останавливает легитимный сервис; исключение сужено до доверенного АРМ, сигнатура глобально не отключена.
#listing([Документация до исключения], read("outputs/continent-docs-exception-before.txt")) <lst-c4-docs-before>
#listing([Сигнатура ложного срабатывания], read("outputs/continent-docs-exception-before-event.txt")) <lst-c4-docs-before-event>
#listing([Параметры исключения для доверенного АРМ], read("configs/continent-docs-ips-exception.json")) <lst-c4-docs-rule>
#listing([Документация с АРМ после исключения], read("outputs/continent-docs-exception-after-admin.txt")) <lst-c4-docs-after-admin>
#listing([Защита для WAN сохранена], read("outputs/continent-docs-exception-after-wan.txt")) <lst-c4-docs-after-wan>

Для Kerio легитимный IRC на нестандартном порту 16667 блокировался SID 1:2000345 «ET TROJAN IRC Nick change on non-standard port». Добавлено исключение только для этой сигнатуры в штатный список IPS. После него администратор проходит проверку IRC, гость остаётся заблокирован ContentFilter (листинг @lst-k-falsepositive). Исключение глобально для SID, а не только для адреса администратора; это ограничение следует учитывать перед эксплуатацией.
#listing([Kerio: ложное срабатывание и точечное исключение сигнатуры], read("outputs/kerio-ips-false-positive-exception.txt")) <lst-k-falsepositive>

== Резервное копирование и восстановление
Через API ЦУС создана зашифрованная нативная резервная копия (листинг @lst-c4-native-backup; файл и пароль хранятся вне репозитория). Сохранены описание объекта BKS4_WAN_TEST и контрольные хеши правил, адресов и сервисов, затем изменено только описание, и из копии восстановлен компонент CDC. Задача завершилась успешно, описание вернулось, четыре контрольных хеша совпали (листинг @lst-c4-native-restore); после переустановки политики сетевые и антивирусные проверки повторены успешно.
#listing([Создание нативной резервной копии], read("outputs/continent-native-backup.txt")) <lst-c4-native-backup>
#listing([Проверка восстановления], read("outputs/continent-native-restore.txt")) <lst-c4-native-restore>

Для Kerio выполнен штатный Configuration.exportConfig, архив сохранён с правами 600 вне Git на ADMIN-LINUX и на хосте PNETLab. Изменено только описание правила BKS4-LAN-DMZ-Web. Проверка импорта не выявила ошибок; все четыре интерфейса сопоставлены по MAC/IP. Свежая загрузка архива и Configuration.apply(fullImport=true) запустили нативное восстановление. API временно пропал; для завершения импорта потребовалось остановить вспомогательный GFI AppManager agent. После возврата API исходное описание восстановлено, семантические хеши семи разделов полностью совпали (листинги @lst-kerio-backup и @lst-kerio-restore-verify). Лицензия осталась зарегистрированной. Испытание не включало откат диска ВМ; архив содержит параметры и сертификаты, а не базы AV.
#listing([Kerio: нативная копия и процедура контрольного восстановления], read("outputs/kerio-native-backup-final.txt")) <lst-kerio-backup>
#listing([Kerio: проверка семи восстановленных разделов], read("outputs/kerio-native-restore-verify.txt")) <lst-kerio-restore-verify>
После удаления временного SSH-правила отдельно сохранена актуальная нативная копия; её метаданные приведены в листинге @lst-k-export-current. Сетевые проверки выполнены уже на этой итоговой политике из 22 правил.
#listing([Kerio: актуальная копия итоговой конфигурации], read("outputs/kerio-final-export.txt")) <lst-k-export-current>

= Индивидуальное задание варианта 6
Веб-сервер DMZ опубликован на обеих платформах (тест 2). Запрет мессенджеров и файлообменных сервисов для группы «Гости» реализован на «Континенте» правилом контроля приложений с категориями Chat и FileSharing и приложениями IRC, Jabber, BitTorrent; его независимость от порта подтверждена на стандартных и нестандартных портах (листинг @lst-c4-apps-guest), исключение администратора — листингом @lst-c4-apps-admin.

Географическое ограничение: правило BKS4-GeoIP-Block-US-to-DMZ запрещает опубликованные сервисы источникам из региона «Соединённые Штаты». На изолированном WAN эмулируются источники с адресами 5.255.255.5 (база узла относит к RU) и 8.8.8.8 (US). Без ограничения оба получают HTTP 200 (листинг @lst-c4-geo-off); с ограничением RU-источник получает 200, US — таймаут, в журнале `src_country=US`, action=blocked, правило GeoIP (листинг @lst-c4-geo-on). Это проверка классификации префиксов базой GeoIP, а не физического расположения; актуальность базы на стенде обновлениями не подтверждена.
#listing([GeoIP: ограничение выключено], read("outputs/continent-geoip-disabled.txt")) <lst-c4-geo-off>
#listing([GeoIP: ограничение включено], read("outputs/continent-geoip-enabled.txt")) <lst-c4-geo-on>

На Kerio вариант реализован нативными группами и ContentFilter (листинги @lst-k-app-admin и @lst-k-app-guest). GeoIP включён глобально для входящего WAN, заблокирована страна US; это не отдельное правило только для DMZ. В текущей политике разрешённые входящие сервисы — публикации DMZ. С теми же изолированными источниками при выключенном GeoIP оба запроса дают HTTP 200, при включённом RU получает 200, US — таймаут. Временное диагностическое журналирование подтвердило классификацию US (Country 6252001); после проверки оно выключено. Адреса 5.255.255.5 и 8.8.8.8 используются только как эмулированные источники на WAN-TEST, назначение всегда собственное 192.168.100.2:8080.
#listing([Kerio GeoIP: выключено], read("outputs/kerio-geoip-disabled.txt")) <lst-k-geo-off>
#listing([Kerio GeoIP: включено], read("outputs/kerio-geoip-enabled.txt")) <lst-k-geo-on>
#listing([Kerio: нативная классификация источника GeoIP], read("outputs/kerio-geoip-events.txt")) <lst-k-geo-event>

= Сравнительный анализ
#figure({set text(size: 8.5pt); table(columns: (1.2fr, 2.4fr, 2.4fr), align: left,
table.header([Критерий], [«Континент 4»], [Kerio Control]),
[Надёжность и отказоустойчивость], [Конфигурация хранится в ЦУС; штатные резервная копия и восстановление CDC проверены; установка политики — отдельная задача с терминальным статусом; после восстановления и перезагрузок политика сохранялась], [Изменения применяются мгновенно, но без подтверждения меток времени откатываются при завершении сессии; штатный экспорт и восстановление проверены по хешам семи разделов; при импорте потребовалась остановка вспомогательного AppManager agent],
[Информационная безопасность], [Управление только из Management (ГОСТ TLS, 444), контроль по пользователям и группам, DPI независимо от порта, IPS с пользовательскими сигнатурами, антивирус по ICAP, GeoIP; выявлены особенности: порядок DPI/прокси и прохождение handshake до классификации], [Проверены МЭ/NAT, DPI по группам, GeoIP и IPS веб-сигнатур из WAN; сканирование обнаруживается без подтверждённого подавления; AV не готов без первоначальной базы],
[Быстродействие], [Установка политики 3–5 мин; событие IPS появляется в syslog АРМ через единицы секунд после пакета; HTTP через AV-прокси — десятки мс на запрос по измерениям curl], [Правила применяются без отдельной задачи установки; на стенде измерены ответы curl и протокольных тестов; пропускная способность и отказоустойчивость не измерялись],
[Трудоёмкость сопровождения], [Требует АРМ на Windows с CSP, два уровня (ЦУС и узел), каждое изменение — установка политики; зато подробные структурированные события и API для автоматизации], [Один веб-интерфейс и JSON-RPC API, быстрый цикл изменений; активация успешно завершена, однако загрузка первоначальной AV-базы и свежих обновлений IPS не удалась],
)}, caption: [Сравнение платформ по результатам стенда]) <tab-compare>

= Заключение
На стенде развёрнуты обе платформы с общей адресацией и тестовыми машинами. На «Континенте 4» выполнены все этапы методички и индивидуальное задание варианта 6: политика с запретом по умолчанию, NAT и публикация DMZ, антивирус через ICAP, группы пользователей с порталом аутентификации, контроль приложений для гостей независимо от порта с исключением администратора, IDS → IPS с вендорскими и пользовательскими сигнатурами, разбор ложного срабатывания, syslog и SNMP-оповещения, три статистических представления, резервное копирование и восстановление, GeoIP-ограничение с контрольным сравнением. Результаты применимых тестов сохранены вместе с нативными событиями; отдельная фильтрация URL-категорий вариантом 6 не задана.

На Kerio Control активирован trial; проверены МЭ/NAT и публикация DMZ, управление из Management, группы с DPI на стандартных и нестандартных портах, IPS в режимах обнаружения и предотвращения для веб-сигнатур WAN, исключение ложного срабатывания, GeoIP off/on, штатный syslog, внешние SNMP-оповещения IPS, статистические представления и нативное резервное копирование с контрольным восстановлением. Ограничения: антивирус без первоначальной базы не обнаруживает EICAR, свежие обновления IPS не получены, подавление сканирования IPS и веб-детекты на прямом пути LAN → DMZ не подтверждены. Для полного закрытия соответствующих пунктов нужны работоспособные обновления и повторные тесты либо конкретная замена, согласованная с преподавателем (методичка, стр. 33). Выполненные проверки МЭ и других модулей автоматически заменой не считаются.

Ограничения решения и рекомендации: HTTPS без TLS-инспекции не проверяется антивирусом; правило контроля приложений «любой сервис» пропускает первые пакеты неизвестного протокола, поэтому его следует сочетать с явными запретами по сервисам; пороги пользовательских сигнатур сканирования подобраны под стенд и в эксплуатации требуют настройки под реальную нагрузку; узел агрегирует повторяющиеся события, что надо учитывать при подсчётах по журналу.
