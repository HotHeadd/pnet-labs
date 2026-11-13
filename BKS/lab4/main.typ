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
Kerio Control 10.0.1 build 9439 развёрнут из официального QEMU-образа. Заменён пароль Admin, интерфейсам назначены адреса таблицы @tab-addressing. NTP использует 192.168.100.1, часовой пояс — Москва; аппаратные часы QEMU читаются и записываются как UTC. Официальная trial-лицензия на 25 пользователей импортирована; API показывает срок до 06.12.2026, но продукт остаётся в режиме `LoginReactivation` с `licenseSet=false`. Проверка 13.11.2026 подтверждает `AntivirusNotActive`, отказ IPS и части административных API с кодом 1004 (листинг @lst-kerio-status и рисунок @fig-kerio-status). Значение remainingDays отражает срок импортированного файла, а не успешную активацию модулей.
#listing([Состояние продукта и доступность модулей Kerio, 13.11.2026], read("outputs/kerio-status-final.txt")) <lst-kerio-status>
#figure(image("img/kerio-status.png", width: 100%), caption: [Сводка статуса Kerio на АРМ администратора; полные ответы приведены в листинге]) <fig-kerio-status>

Онлайн-регистрация не завершилась и после проверки DNS, NTP и правил HTTP/HTTPS самого шлюза: повтор 13.11.2026 закончился ошибкой обмена после 300 секунд (листинг @lst-kerio-registration). Отказ модуля не подменяется успешным испытанием МЭ: антивирус, IPS, групповые ограничения приложений и GeoIP Kerio остаются невыполненными. Методичка допускает замену недоступного модуля эквивалентным заданием только по согласованию с преподавателем; такое согласование на момент оформления не подтверждено.
#listing([Штатная попытка регистрации после проверки сетевых условий], read("outputs/kerio-registration-final.txt")) <lst-kerio-registration>
Повторно проверена офлайн-установка имеющегося `license.key`: Base-ID совпал с сохранённым trial-номером, импорт завершился без ошибки, установленный файл совпал с исходным по SHA256 (рисунок @fig-kerio-license-file). Подтверждены оставшиеся шаги мастера, включая centralManagementSet; выполнена штатная перезагрузка. Тем не менее в новой сессии licenseSet остаётся false, IPS возвращает1004, EICAR скачивается сHTTP200 (листинг @lst-kerio-offline). Следовательно, наличие и успешный импорт файла на этом экземпляре не подтвердили активацию; точная причина расхождения не установлена.
#listing([Повторный офлайн-импорт и проверка после перезагрузки], read("outputs/kerio-offline-license-summary.txt")) <lst-kerio-offline>
#figure(image("img/kerio-license-engine.png", width: 100%), caption: [Установленный файл лицензии Kerio: хеш и запись о принятом trial]) <fig-kerio-license-file>
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
На Kerio встроенный антивирус недоступен до активации лицензии: EICAR по HTTP из LAN проходит (листинг @lst-kerio-lan).

== Пользователи, группы и контроль приложений («Континент»)
Созданы локальные пользователи labguest и lab-admin в группах BKS4 Guests и BKS4 Administrators. Идентификация на LAN — штатный портал аутентификации auth.bks4.test на 10.1.10.1 с отдельным RSA-сертификатом; до входа HTTP гостя перенаправляется на портал. Вход гостя и администратора выполняется с разных адресов (10.1.10.42 и 10.1.99.10), так как смена пользователя на одном адресе без выхода оставляет прежнюю привязку (листинги @lst-c4-guest-login и @lst-c4-admin-login).
#listing([Аутентификация гостя через портал], read("outputs/continent-guest-login.txt")) <lst-c4-guest-login>
#listing([Аутентификация администратора], read("outputs/continent-admin-login.txt")) <lst-c4-admin-login>
Правило BKS4-Guests-Block-Messengers-P2P запрещает группе Guests приложения IRC, Jabber, BitTorrent и категории Chat и FileSharing для любых получателей и любых портов; выше него стоит исключение BKS4-Administrators-Lab-Protocol-Exception для группы администраторов. Отдельные ограничения по URL-категориям и типам файлов вариантом 6 не заданы.

Первоначально правило контроля приложений стояло выше правил с HTTP-профилем антивируса, и после входа гостя любой HTTP зависал: запрос перехватывался прокси, а классификатор приложений удерживал поток (захват на хосте показал только TCP-handshake наружу без GET и без обращения к ICAP). Перенос веб-правил LAN выше правила DPI устранил проблему. Второе наблюдение: при правиле контроля приложений «любой сервис» TCP-handshake и первые байты неизвестного протокола (баннер SSH) проходят до классификации, после чего поток молча прерывается без записи в журнал; поэтому добавлен явный запрет BKS4-Deny-LAN-to-DMZ-Other до правила DPI — теперь SSH из LAN в DMZ отбрасывается на первом пакете с событием журнала (листинг @lst-c4-events).

Результат: гость получает таймаут на IRC 6667/16667 и BitTorrent 6881/16881, администратор проходит все четыре проверки; при этом обычный HTTP гостя работает, а EICAR блокируется (листинги @lst-c4-apps-guest и @lst-c4-apps-admin). На Kerio контроль приложений недоступен без активации: IRC из LAN проходит (листинг @lst-kerio-lan).
#listing([Гость: IRC и BitTorrent заблокированы независимо от порта], read("outputs/continent-final-apps-guest.txt")) <lst-c4-apps-guest>
#listing([Администратор: исключение разрешает те же приложения], read("outputs/continent-final-apps-admin.txt")) <lst-c4-apps-admin>

== IDS/IPS («Континент»)
Профиль BKS4-IDS-Alert создан из вендорской базы (33 964 сигнатуры) сначала в режиме обнаружения (рисунок @fig-ids-settings); HOME_NET задан как сеть DMZ 10.1.50.0/26. В режиме обнаружения из WAN зарегистрированы Nmap User-Agent (SID 4109359) и `/etc/passwd` в URI (SID 4149401) с действием allowed (листинг @lst-c4-ids-events).
#figure(image("img/continent-ids-alert-settings.png", width: 100%), caption: [Профиль СОВ в режиме обнаружения]) <fig-ids-settings>
#listing([События в режиме обнаружения], read("outputs/continent-ids-events.txt")) <lst-c4-ids-events>
Для режима предотвращения выбран оптимальный вендорский набор (6794 сигнатуры в alert) и восемь сигнатур в drop: подтверждённые веб-сигнатуры 4109359, 4149401, 4106447, 4111038, 4110964 и три пользовательские сигнатуры (листинг @lst-c4-user-sigs). Вендорские сигнатуры сканирования имеют высокие пороги и `noalert`, поэтому сканирование и SYN-поток обнаруживаются пользовательскими правилами по частоте SYN от одного источника; XMAS-пакеты описаны отдельной сигнатурой. Пользовательские сигнатуры загружены через API `/ipssignature` и проверены узлом.
#listing([Пользовательские сигнатуры СОВ], read("configs/continent-ips-user-signatures.txt")) <lst-c4-user-sigs>

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
[4], [Антивирус], [EICAR и ZIP — 403, события appfilter blocked (@lst-c4-av-guest)], [недоступен без активации, EICAR 200 (@lst-kerio-lan)],
[5], [Веб-фильтр], [не задан вариантом; HTTP гостя проходит только через AV-прокси], [недоступен без активации],
[6], [Исключение для администратора], [IRC/BitTorrent разрешены lab-admin (@lst-c4-apps-admin)], [—],
[7], [Контроль приложений], [IRC и BitTorrent заблокированы гостю на 6667/16667/6881/16881 (@lst-c4-apps-guest)], [недоступен без активации (@lst-kerio-lan)],
[8], [IDS/IPS: сканирование], [SID 3900002 и 3900001 blocked, 8 из 120 SYN прошли (@lst-c4-ids-wan, @lst-c4-events)], [нет IPS; nmap видит только опубликованные порты (@lst-kerio-wan)],
[9], [IDS/IPS: веб-атака], [SID 4109359, 4149401 blocked, таймаут клиента (@lst-c4-ids-wan)], [Nmap UA — HTTP 200 (@lst-kerio-wan)],
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
Проверки 13.11.2026 выполнены после восстановления файловой копии конфигурации. HTTP/HTTPS и DNS/NTP разрешены, запрещённые SSH-соединения и управление из недоверенных сегментов блокируются. EICAR и ZIP получают HTTP 200: это отрицательный результат проверки защиты, соответствующий неактивному антивирусу. Результаты видны на рисунках @fig-kerio-lan, @fig-kerio-wan, @fig-kerio-dmz и @fig-kerio-admin.
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

Для Kerio журналы connection/filter/security/error/alert пересылает отдельный агент на самом appliance: он читает реальные файлы Kerio и отправляет строки через UDP/514 с адреса 10.1.99.1. В приёмнике используется отдельный APP-NAME `kerio-*`, поэтому эти данные отделяются от событий «Континента». Приём записей о тестовых соединениях и блокировках подтверждён листингом @lst-kerio-events и рисунком @fig-kerio-events. Это пересылка файлов журналов, а не штатная настройка syslog через WebAdmin: API Logs в текущем режиме недоступен. Оповещения о детектах AV/IPS Kerio не проверены, поскольку сами модули неактивны.
#listing([Kerio: полученные записи соединений и блокировок], read("outputs/kerio-events-final.txt")) <lst-kerio-events>
#figure(image("img/kerio-events.png", width: 100%), caption: [Реальные записи Kerio, полученные сервером syslog в Management]) <fig-kerio-events>

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

Для Kerio из того же файла приёмника сформированы три представления: по правилам, по сетевым сервисам и по исходным IPv4-адресам (таблица @tab-kerio-stats). Сетевой сервис здесь определяется полями нативной записи и не является доказательством DPI-классификации приложения. Пакетная блокировка и завершённое соединение считаются раздельно; их сумма не равна числу попыток соединения. Выборка включает служебные обращения API администратора.
#let kstats = json("outputs/kerio-statistics-final.json")
#figure({set text(size: 9pt); table(columns: (1fr, 2.5fr, 0.6fr), align: left,
table.header([Представление], [Значение], [Записей]),
..kstats.by_rule.pairs().map(((k,v)) => ([Правило], [#k], [#v])).flatten(),
..kstats.by_network_service.pairs().map(((k,v)) => ([Сетевой сервис], [#k], [#v])).flatten(),
..kstats.by_source_ipv4.pairs().map(((k,v)) => ([Источник IPv4], [#k], [#v])).flatten()
)}, caption: [Kerio: три статистических представления записей после 12:45 UTC 13.11.2026]) <tab-kerio-stats>
Практические выводы: явное правило защиты управления фиксирует обращения из недоверенных сегментов; записи DMZ → LAN подтверждают изоляцию; заметная доля WebAdmin объясняется работой АРМ и должна отделяться от пользовательского трафика. Подсчёт по портам и сервисам не заменяет проверку пользовательских групп и приложений.

== Разбор инцидента
По метке времени итогового IPS-теста в журнале (листинг @lst-c4-events) событие `2026-11-07 13:38:27 МСК`: источник 192.168.100.1, порт 2224, цель 10.1.50.10:80 (адрес после DNAT публикации 192.168.100.2:8080), сигнатура 3900002 «BKS4 TCP SYN port scan to DMZ», действие blocked; через 0,4 с — 3900001 «SYN flood», blocked. Соответствующие SNMP-уведомления получены на АРМ (листинг @lst-c4-ips-alerts). Запись содержит все данные для реагирования: время, адреса, сигнатуру и действие.

== Ложное срабатывание и исключение
Учебная страница документации на DMZ принимает параметр `topic`; легитимный запрос `/docs?topic=/etc/passwd` с АРМ блокировался сигнатурой 4149401 (листинги @lst-c4-docs-before и @lst-c4-docs-before-event). Добавлено правило BKS4-Admin-Docs-IPS-Exception: только 10.1.99.10 → 192.168.100.2:8080 без передачи в СОВ (листинг @lst-c4-docs-rule). После установки запрос с АРМ получает HTTP 200, из WAN — таймаут и blocked по той же сигнатуре (листинги @lst-c4-docs-after-admin, @lst-c4-docs-after-wan). Блокировка без исключений недопустима в эксплуатации: одна сигнатура по строке в URI останавливает легитимный сервис; исключение сужено до доверенного АРМ, сигнатура глобально не отключена.
#listing([Документация до исключения], read("outputs/continent-docs-exception-before.txt")) <lst-c4-docs-before>
#listing([Сигнатура ложного срабатывания], read("outputs/continent-docs-exception-before-event.txt")) <lst-c4-docs-before-event>
#listing([Параметры исключения для доверенного АРМ], read("configs/continent-docs-ips-exception.json")) <lst-c4-docs-rule>
#listing([Документация с АРМ после исключения], read("outputs/continent-docs-exception-after-admin.txt")) <lst-c4-docs-after-admin>
#listing([Защита для WAN сохранена], read("outputs/continent-docs-exception-after-wan.txt")) <lst-c4-docs-after-wan>

== Резервное копирование и восстановление
Через API ЦУС создана зашифрованная нативная резервная копия (листинг @lst-c4-native-backup; файл и пароль хранятся вне репозитория). Сохранены описание объекта BKS4_WAN_TEST и контрольные хеши правил, адресов и сервисов, затем изменено только описание, и из копии восстановлен компонент CDC. Задача завершилась успешно, описание вернулось, четыре контрольных хеша совпали (листинг @lst-c4-native-restore); после переустановки политики сетевые и антивирусные проверки повторены успешно.
#listing([Создание нативной резервной копии], read("outputs/continent-native-backup.txt")) <lst-c4-native-backup>
#listing([Проверка восстановления], read("outputs/continent-native-restore.txt")) <lst-c4-native-restore>

Для Kerio штатный `Configuration.exportConfig` возвращает код 1004. Поэтому при остановленной службе создана файловая копия параметров `winroute.cfg`, `UserDB.cfg`, `logs.cfg`, лицензии и локальных служебных сценариев. Архив с правами 600 хранится вне Git на самом appliance, в `/root/bks4-private/kerio-config-20261113.tgz`; SHA256 `7a82f5470c1b9fe67d17eed4b7bce8711547632dda804bc02c216354cd58b0e5`. Дополнительная копия перенесена на хост PNETLab в `/root/bks4-backups-private/`, её SHA256 совпал с исходным (листинг @lst-kerio-backup). Это не штатный переносимый экспорт и не резервная копия диска ВМ; копия на хосте защищает от потери диска appliance, но не от потери самого хоста.
После создания копии через API изменено только описание правила BKS4-LAN-DMZ-Web и подтверждено чтением новой сессии. Затем служба остановлена, `winroute.cfg` восстановлен из архива, служба запущена. Описание вернулось; SHA256 семантического представления всех правил и default-rule совпал до изменения и после восстановления (листинги @lst-kerio-restore-change, @lst-kerio-restore-verify). Из хеша исключено только динамическое поле lastUsed. Сетевые проверки раздела тестирования выполнены после восстановления.
#listing([Kerio: копия вне диска appliance и проверка хеша], read("outputs/kerio-backup-final.txt")) <lst-kerio-backup>
#listing([Kerio: подтверждённое контрольное изменение], read("outputs/kerio-restore-change.txt")) <lst-kerio-restore-change>
#listing([Kerio: проверка восстановления всей политики], read("outputs/kerio-restore-verify.txt")) <lst-kerio-restore-verify>

= Индивидуальное задание варианта 6
Веб-сервер DMZ опубликован на обеих платформах (тест 2). Запрет мессенджеров и файлообменных сервисов для группы «Гости» реализован на «Континенте» правилом контроля приложений с категориями Chat и FileSharing и приложениями IRC, Jabber, BitTorrent; его независимость от порта подтверждена на стандартных и нестандартных портах (листинг @lst-c4-apps-guest), исключение администратора — листингом @lst-c4-apps-admin.

Географическое ограничение: правило BKS4-GeoIP-Block-US-to-DMZ запрещает опубликованные сервисы источникам из региона «Соединённые Штаты». На изолированном WAN эмулируются источники с адресами 5.255.255.5 (база узла относит к RU) и 8.8.8.8 (US). Без ограничения оба получают HTTP 200 (листинг @lst-c4-geo-off); с ограничением RU-источник получает 200, US — таймаут, в журнале `src_country=US`, action=blocked, правило GeoIP (листинг @lst-c4-geo-on). Это проверка классификации префиксов базой GeoIP, а не физического расположения; актуальность базы на стенде обновлениями не подтверждена. На Kerio географическая фильтрация без активации недоступна.
#listing([GeoIP: ограничение выключено], read("outputs/continent-geoip-disabled.txt")) <lst-c4-geo-off>
#listing([GeoIP: ограничение включено], read("outputs/continent-geoip-enabled.txt")) <lst-c4-geo-on>

= Сравнительный анализ
#figure({set text(size: 8.5pt); table(columns: (1.2fr, 2.4fr, 2.4fr), align: left,
table.header([Критерий], [«Континент 4»], [Kerio Control]),
[Надёжность и отказоустойчивость], [Конфигурация хранится в ЦУС; штатные резервная копия и восстановление CDC проверены; установка политики — отдельная задача с терминальным статусом; после восстановления и перезагрузок политика сохранялась], [Изменения применяются мгновенно, но без подтверждения меток времени откатываются при завершении сессии; файловая копия параметров и восстановление политики проверены по хешу; штатный экспорт недоступен],
[Информационная безопасность], [Управление только из Management (ГОСТ TLS, 444), контроль по пользователям и группам, DPI независимо от порта, IPS с пользовательскими сигнатурами, антивирус по ICAP, GeoIP; выявлены особенности: порядок DPI/прокси и прохождение handshake до классификации], [Проверены только межсетевой экран и NAT: запрет по умолчанию, публикация, изоляция DMZ, администрирование только из Management; антивирус, IPS и контроль приложений недоступны без онлайн-активации],
[Быстродействие], [Установка политики 3–5 мин; событие IPS появляется в syslog АРМ через единицы секунд после пакета; HTTP через AV-прокси — десятки мс на запрос по измерениям curl], [Применение правил — секунды; задержек на трафике не замечено; защитные модули не измерялись],
[Трудоёмкость сопровождения], [Требует АРМ на Windows с CSP, два уровня (ЦУС и узел), каждое изменение — установка политики; зато подробные структурированные события и API для автоматизации], [Один веб-интерфейс и JSON-RPC API, быстрый цикл изменений; зависимость от облачной активации производителя, которая на стенде не завершилась],
)}, caption: [Сравнение платформ по результатам стенда]) <tab-compare>

= Заключение
На стенде развёрнуты обе платформы с общей адресацией и тестовыми машинами. На «Континенте 4» выполнены все этапы методички и индивидуальное задание варианта 6: политика с запретом по умолчанию, NAT и публикация DMZ, антивирус через ICAP, группы пользователей с порталом аутентификации, контроль приложений для гостей независимо от порта с исключением администратора, IDS → IPS с вендорскими и пользовательскими сигнатурами, разбор ложного срабатывания, syslog и SNMP-оповещения, три статистических представления, резервное копирование и восстановление, GeoIP-ограничение с контрольным сравнением. Результаты применимых тестов сохранены вместе с нативными событиями; отдельная фильтрация URL-категорий вариантом 6 не задана.

На Kerio Control проверены МЭ, NAT, публикация, управление из Management, пересылка реальных журналов, три статистических представления и файловое восстановление политики. Антивирус, IPS, групповой контроль приложений и GeoIP остаются невыполненными из-за незавершённой активации. Полная сдача этих пунктов требует работоспособной лицензии либо согласованной преподавателем замены; испытания МЭ автоматически такой заменой не считаются.

Ограничения решения и рекомендации: HTTPS без TLS-инспекции не проверяется антивирусом; правило контроля приложений «любой сервис» пропускает первые пакеты неизвестного протокола, поэтому его следует сочетать с явными запретами по сервисам; пороги пользовательских сигнатур сканирования подобраны под стенд и в эксплуатации требуют настройки под реальную нагрузку; узел агрегирует повторяющиеся события, что надо учитывать при подсчётах по журналу.
