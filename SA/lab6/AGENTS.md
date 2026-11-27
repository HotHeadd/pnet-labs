# СА, лабораторная работа №6

## 2026-11-27 — исправление титульного листа

В main.typ указан состав команды, как в остальных отчётах проекта:
Доценко В. А., Дзюба С. Д., Мартюшев В. А., Горячев М. А.
Подпись титула теперь «Выполнили». PDF пересобран (26страниц), титульная
страница визуально проверена. Общий шаблон и содержательная часть отчёта
не менялись; стенд не затрагивался, commit/staging не менялись.

## Последняя правка — 2026-11-27, команды в одну строку

Пользователь попросил убрать артефакты вставки в терминал: не использовать
обратные слеши и дополнительные приглашения продолжения. Пересняты
12 затронутых терминальных кадров, команды вводились одной физической
строкой. В механизме ввода проверялось отсутствие обратного слеша и
встроенного перевода строки; длинные команды переносятся только самим
терминалом по ширине окна. Изображения не ретушировались.

- Снимки LDAP/TLS, Trytonconfig, SSHpolicy, SSOevents, LDAP-идентичностей,
  SSH-аутентификации, NFS, curlTryton, HTTPS, Xpra reconnect и VaultAPI
  заменены новыми оригинальными кадрами машин. Кадры без указанных
  артефактов и прежние GUI-снимки не менялись. Предыдущие версии 12 кадров
  для сравнения сохранены вне репозитория в /tmp/sa6-before-oneline/.
- commands/check-nfs.txt также переписан в однострочном виде: echo вместо
  printf с escape-последовательностями. Результаты проверок те же.
- При проверке reconnect после остановки клиента надо дождаться фактического
  clients=0 на сервере: значение обновляется асинхронно. Итоговый снимок
  показывает1→0→1, неизменные PID19494/19522 и UUID прежнего сеанса.
- VaultAPI вернул Shared200, Private400 и запрет PUT400; revisionDate не
  изменилась. Временные файлы токена/тела запроса удалены, браузер Bob
  перезагружен, временные JS-переменные токена очищены.
- Временные tty2 закрыты, три сервера возвращены на tty1, root-терминал
  WORKSTATION закрыт. Xpra client/lightdm/оба WebDriver active; на переднем
  плане вновь Tryton. SSH master /tmp/sa6-oneline.sock закрыт. Маршруты,
  службы и основные настройки не менялись; сессия и ВМ оставлены включёнными.
- get_lab MCP в этой попытке возвращал timeout/error. list_running_labs
  подтвердил session15/pod7 и4 работающих узла; действия продолжены через
  SSH к прежним гостям с проверкой hostname. Топология не пересоздавалась.
- main.pdf пересобран,26страниц. Все страницы визуально проверены;
  источников, вызовов скриптов и блочных листингов по-прежнему нет.
  git diff --check и bash -n check-nfs.txt прошли, staging/commit не менялись.

## Актуальное состояние — 2026-11-27, отчёт переработан под снимки

По прямой просьбе пользователя удалены источники, вызовы вспомогательных
скриптов и все блочные листинги. Пользователь предпочёл реальные снимки
машин с обычными командами. Это указание заменяет прежнее требование
сохранять раздел источников в этой версии отчёта.

- main.typ переписан: 23 настоящих снимка терминалов/GUI и схема SVG,
  пояснения к каждому рисунку, архитектура, параметры аутентификации,
  положительные/отрицательные проверки и заключение. main.pdf собран:
  26страниц, визуально проверены все страницы и ключевые снимки при
  увеличении. Источников, Листингов, имён run.py/prepare-hosts.py и вызовов
  configure-directory.sh в PDF нет. Все ссылки на изображения разрешаются.
- Пользователь сам закоммитил предыдущий результат c7d125a complete;
  его изменения сохранены. Ассистент не менял staging и не делал commit.
- get_lab подтвердил прежнюю session15 и4 работающих узла. Для съёмки
  открывались отдельные tty2 DIRECTORY/APPS/WEB через openvt и временный
  root xfce-terminal WORKSTATION (transient sa6-report-terminal).
  Команды вводились в настоящие терминалы через TIOCSTI; картинки получены
  из framebuffer QEMU, без имитации вывода и редактирования пикселей.
- Повторены обычные ldapsearch/getent/id/ldapwhoami/ssh/curl/stat/getfacl,
  проверены действующие SSSD/NSS/PAM и Trytonconfig, SSHpolicy и журнал.
  Пароли вводились только внутри WORKSTATION при ECHO=off и проверенном
  foreground ssh/ldapwhoami/curl, на Mac не передавались и в кадры не попали.
- Tryton проверен прямым curl с интерактивной HTTP Basic-аутентификацией:
  model.party.party.search_read вернул Alice SA6 Project/HTTP200, BobHTTP401.
  Сертификат проверялся штатно, -k не использовался.
- По NFS создан sa6-report.txt от Alice WORKSTATION и дописан через SSH
  Alice APPS. На одном настоящем снимке видны обе записи, alice/employees660,
  отказ Bob/exit1 и отказ rootклиента/exit1. Старый alice.txt сохранён.
  commands/check-nfs.txt и NFS-команды demo-checks.md обновлены под новый файл.
- Полный reconnect Xpra повторён: на WORKSTATION systemctl stop/start
  только sa6-xpra-client; три xpra info на APPS показали clients1→0→1,
  PID19494, тот же UUIDed20d3ed33a34431ab3784f31e867ed4 и TrytonPID19522.
  apps-xpra-reconnect-terminal.png и новый кадр окна Tryton после возврата
  включены в отчёт. Сервер Xpra/приложение не перезапускались.
- События SSO показаны настоящим SELECT из event_entity/user_entity
  Keycloak PostgreSQL. Последние две строки Alice gitea13:56:30UTC и
  vaultwarden14:00:34UTC имеют общий session_id knvQTC6v2XCKDUv7E+P5wb2g.
  Старые успешные браузерные снимки сохранены и используются; новую
  последовательность SSO при переработке не заявляем.
- Права Vaultwarden повторно проверены прямо curl в терминале WORKSTATION
  с токеном Bob из защищённого файла: профиль bob@sa6.test, SharedHTTP200,
  PrivateHTTP400/Cipher is not owned by user, PUT SharedHTTP400/Cipher is
  not write accessible. Запрос содержал прежние зашифрованные данные;
  revisionDate до/после совпала. Новый vault-rights-terminal.png в отчёте.
- Временные API-файлы bob-vault.curl/shared-unchanged.json/revision и
  подготовительные tryton-*.curl на WORKSTATION удалены. Браузер Bob
  перезагружен, временные JS-переменные токена очищены, vault разблокирован.
  Первые пробы curl без tty не показывали успешного входа и в отчёт не вошли;
  окончательные кадры получены с обычными парольными запросами в терминале.
- Временные root-консоли закрыты, DIRECTORY/APPS/WEB возвращены на tty1,
  ps по tty2 не показывает оставшихся процессов. sa6-report-terminal
  WORKSTATION inactive; lightdm/sa6-xpra-client/оба WebDriver active.
  На переднем плане вновь Tryton. Временный Mac SSH master
  /tmp/sa6-report.sock закрыт; маршруты Mac не менялись.
- capture.py получил необязательный --ssh-socket для уже открытого SSH-
  соединения. Новые снимки имеют отдельные имена, старые изображения не
  перезаписывались. Дублирующий промежуточный кадр Tryton после reconnect
  сравнен с итоговым и исключён; окончательный кадр сохранён отдельно.
- Python AST capture.py, bash -n check-nfs.txt, git diff --check прошли.
  Общий mephi-labs не менялся. Сессия и все ВМ оставлены включёнными;
  настроенные QEMU-образы не публиковались, ZIP содержит только топологию.

## Предыдущая сборка отчёта — 2026-11-27, до переработки под снимки

Пользователь возобновил работу. Лаба `/SA labs/SA6.unl`, session15/pod7,
аккаунт vlad_pc; get_lab подтвердил четыре работающих QEMU, id1–4,
node sessions26–29. Чужие сессии и общие образы не менялись.

- DIRECTORY: LDAPS OpenLDAP и NFS работают. APPS/WORKSTATION используют
  SSSD и общий ресурс. Реально проверены парольный SSH Alice/отказ Bob,
  общий файл Alice с двух клиентов, отказ Bob и root клиента NFS.
- APPS: Tryton/PostgreSQL, отдельная прикладная LDAP-аутентификация.
  Alice читает SA6 Project, Bob HTTP401. Xpra публикует только Tryton;
  reconnect clients1→0→1 сохранил UUID и PID приложения19522.
- WEB: четыре контейнера работают, nginx active; LDAPS-федерация,
  конфиденциальные OIDC-клиенты Gitea/Vaultwarden и браузерный SSO проверены.
  Общий sessionId подтверждён реальными событиями LOGIN обоих клиентов.
- Vaultwarden: SA6 Team, Alice Owner; Bob подтверждённый User с просмотром
  только Shared. Private не назначена. Из отдельного приватного браузера
  Bob реально прочитал Shared HTTP200, получил HTTP400 при чтении Private
  (Cipher is not owned by user) и записи Shared (Cipher is not write accessible).
  Версия записи не изменилась. outputs/vaultwarden-rights.txt включён в отчёт.
- В текущем web-vault2026.10.1 списки выбора участников/коллекций показывали
  No items found, хотя API возвращал HTTP200 с2 элементами. Приглашение и
  подтверждение Bob выполнены через GUI, назначение Shared/View items —
  штатным PUT коллекции от Alice с сохранением её прежних прав и encrypted name.
  Members GUI после этого показал Bob/Shared/User; фактические права проверены
  браузером Bob и API. Прямых записей в БД не было. Этот инцидент в отчёт не включён.
- Все обязательные изображения получены из настоящего GUI: Tryton/Xpra,
  NFS-терминал, LDAP/READ_ONLY/OIDC Keycloak, Gitea/Vaultwarden, Members и Bob.
  Снимок Vault после загрузки заменил прежний кадр со spinner.
- main.typ дополнен архитектурой, разделением проверок аутентификации,
  заключением/источниками. Схема включает версии ПО. main.pdf собран;
  финальная сборка22страницы визуально проверена; конфиги не разорваны
  между страницами. Python AST,
  bash -n и git diff --check прошли. Общий mephi-labs не менялся.
- demo-checks.md содержит краткую повторную демонстрацию. Конфиденциальные
  данные остаются только root private на ВМ, токены на Mac не копировались.
  Сеансы браузера после API-проверок перезагружены (временные JS-переменные
  удалены), оба vault разблокированы и показали ожидаемые записи. На переднем
  плане WORKSTATION активировано окно Alice SA6 - Tryton; тестовый NFS-терминал
  закрыт остановкой только своего sa6-nfs-demo. Основные службы active.
- Топология повторно выгружена в stand/pnetlab_export-20261127.zip,
  stand/README.md обновлён. Диски гостевых ОС остаются в рабочей сессии15;
  QEMU-образы не публиковались. Никаких stop_lab/delete/wipe/commit/git add.
- Временный маршрут Mac к46.61.242.181 через192.168.1.1 подтверждён.
  После проверок пользователю отправлен запрос удалить его командой
  sudo route -n delete -host 46.61.242.181; пользователь подтвердил удаление.
  route-get подтвердил отсутствие прежнего host-маршрута.
  У ассистента нет sudo на Mac. SSH временами reset/timeout; --tailscale-nc
  помогал коротким операциям. Не повторять изменения вслепую после обрыва.
- tty1 WORKSTATION: ps показал login/labadmin bash и foreground sudo-i15449.
  После старого неудачного VNC push перед новым вводом в tty1 сначала Ctrl-C;
  содержимое старых частичных файлов не выполнять. Графический DISPLAY0 работает.

Ниже — журнал промежуточных состояний. Старые «ещё не настроено» относятся
к своему времени и заменены итогами выше. Сессию и узлы оставить работающими.

### 18:10 МСК — повторный аудит по методичке

- Повторно прочитаны вариант6 и структура отчёта (стр18 методички),
  теория и границы остальных вариантов. Практические пункты варианта6
  и обязательный состав отчёта закрыты. Kerberos/NFSkrb5/Guacamole и
  проверка offline-login SSSD к варианту6 не относятся. Отдельных письменных
  ответов на14 контрольных вопросов нет; структура отчёта их не требует.
- get_lab снова подтвердил session15 и все4 status2, прежние интерфейсы.
  Заново выполнены LDAPbind Alice/Bob (оба0), парольный SSH Alice0/Bob255,
  Tryton AliceHTTP200 с чтением SA6 Project и BobHTTP401, проверка HTTPS CA.
- Текущий Xpra: clients1, PID19494, тот же UUIDed20d3ed33a34431ab3784f31e867ed4,
  окно Alice SA6 - Tryton, PID19522. Полный reconnect не повторяли:
  его результат сохранён в outputs/xpra-reconnect.txt и сверен с живым сеансом.
- Повторное чтение NFS: Alice0, Bob1, rootклиента1; файлUID10001/GID10000 mode660.
  Приложения, SSSD, nginx и4контейнера active/Up, Vaultwarden/Postgres healthy.
  HTTPS git/vault200; auth200 после2 штатных перенаправлений, проверкаTLS
  не отключалась.
- Повторный Keycloak APIcheck подтвердил LDAPS/READ_ONLY, федерацию обоих
  пользователей,2 конфиденциальных OIDC-клиента и корректные callbackURI.
  Сохранённая пара LOGIN13:56:30/14:00:34UTC с общим sessionId по-прежнему
  читается из Keycloak. Новую браузерную SSO-последовательность не запускали.
- Vaultwarden SQLite открыт mode=ro: AliceOwner/confirmed/access_all1,
  BobUser/confirmed/access_all0, единственное назначение Bob — Shared,
  read_only1/hide_passwords0/manage0; Private не назначена. Права совпали
  с сохранёнными реальными HTTP200/400/400 и неизменной revisionDate.
- Проверены22страницы PDF и9 настоящих PNG+схема SVG. Обязательные снимки,
  схема с версиями, архитектура, разделение аутентификации, результаты,
  заключение и источники присутствуют. git diff --check чистый.
- Стенд не перенастраивался, сеансы не останавливались, коммитов/staging нет.
  ВыгрузкаZIP содержит топологию; перенос настроенных дисков в новые pod
  потребует отдельно запрошенной публикации образов, это не пункт методички.

### 17:30 МСК — проверка SSO/Xpra, коллекции в работе

- Полный reconnect Xpra выполнен tools/check-xpra.py: clients1→0→1,
  serverPID19494, TrytonPID19522, UUIDed20d3ed33a34431ab3784f31e867ed4
  совпали. В отчёт добавлены outputs/xpra-reconnect.txt и реальный кадр
  img/xpra-tryton.png с Alice SA6 и записью SA6 Project. Ничего не перезапускалось
  на сервере для проверки; останавливался только клиент WORKSTATION.
- Первое очищение WebDriver DELETE /cookie сбросило SSO, поэтому тот неудачный
  вывод удалён из outputs. Затем выполнен нормальный выход только из Vaultwarden
  и новый OIDC-вход после Gitea. В событиях Keycloak реально найден общий
  sessionId: LOGIN gitea13:56:30UTC и vaultwarden14:00:34UTC. Второй LDAP-пароль
  не вводился. outputs/keycloak-sso.txt, browser-sso.txt и screenshots sso-*.png
  включены в отчёт. Мастер-пароль отдельно разблокировал vault Alice.
- Согласно официальной документации Vaultwarden поправлен lifespan access token
  realm sa6 с300 на900с (состояние подтверждено API); без этого был warning
  про5min. Источник tools/configure-keycloak.py также исправлен.
- Создана организация SA6 Team id4e49c2e5-9658-4f16-9a50-6070d4c9301d,
  Alice owner. Default collection переименована Shared, создана Private.
  В обеих через GUI сохранены Login-записи Shared demo account/demo-shared
  и Private demo account/demo-private. Пароли случайные, НЕ используются для
  входа ни в какую службу; хранятся только в root private demo-records.json WS
  и зашифрованном vault. Не выдавать эти демонстрационные пароли за LDAP.
- Bob зарегистрирован через LDAP/OIDC в отдельном PRIVATE MiniBrowser на4445,
  master=vault_master_bob из browser-credentials.json. sa6-sa6-register-bob success,
  onboarding закрыт. Его browser-session-4445.json600 на WS. Alice живёт на4444
  в прежнем browser-session.json600. При переключении установить SA6_BROWSER_PORT
  ДО import browser. У Bob пока нет членства в SA6 Team: приглашение/права/проверки
  коллекций ЕЩЁ НЕ выполнены. Следующий шаг — Alice Members -> invite Bob,
  User, только Shared View items, затем confirm (SMTP отключён, уже существующие
  пользователи автоматически Accepted, это подтверждено исходником1.37.5).
- На WS создан /var/swap.sa6 1ГБ и запись fstab, чтобы два браузера не вызвалиOOM
  приRAM2ГБ. /etc/systemd/system/sa6-webdriver-bob.service — копия основного с4445.
  Vendor args заменяют defaultargs WebKit, поэтому Bob args ОБЯЗАТЕЛЬНО
  ['--automation','--private']; без --automation было session not created.
- browser.py теперь поддерживает PORT4445, CSS/XPath и короткий retry только
  для element-click-intercepted/stale-reference. GUI асинхронен: после Save
  открывается View login с отдельным Close; закрыть его перед навигацией.
  Add в AdminCollections имеет Login/Card/.../Collection, а Add item сразуLogin.
- В main.typ добавлены схема SVG и версии из реально запрошенных dpkg/docker,
  преподаватель взят как в остальных BKS-отчётах БасыняЕ.А. Последний PDF до
  схемы14страниц, собранные новые страницы ещё проверить финально.
- Осталось: права коллекций и проверки Bob; настоящие Keycloak admin screenshots
  (LDAPprovider+OIDCclients), NFS screenshot; финальная сверка методички,
  заключение/источники/demo-checks, текущая выгрузка топологии, визуальнаяQA.
  Сессии не закрывать, образы не публиковать, коммит/staging не трогать.

### 16:48 МСК — продолжение после перерыва

- Пользователь закоммитил промежуточные материалы (442a7e0, сдох лимит);
  ассистент не делал коммит. Перед продолжением git status был чистым.
- get_lab подтвердил прежнюю session15 и четыре работающих узла.
  Tryton/Xpra активны, PID19494/UUIDed20d3ed33a34431ab3784f31e867ed4
  сохранились с13:49, в GUI авторизован Alice SA6 (пароль введён предыдущим
  запросом до перерыва). Gitea браузер также открыт под Alice после OIDC.
- Wi-Fi Mac изменился: en0 gateway192.168.1.1, оставшийся /32 маршрут PNET
  указывал на10.188.130.1. Пользователь выполнил sudo route change к192.168.1.1,
  route-get это подтвердил. До исправления связь шла DERPams129мс. Первый
  прямой ping после change timeout; устойчивость пока не подтверждена.
- Открыт Vaultwarden в том же браузере. Из-за перерыва SSO Keycloak истёк,
  понадобился новый вход Alice, он прошёл. Vaultwarden показал настройку
  master password (Join organization / Create account). Это отдельно от LDAP.
  Запрошено создание с vault_master_alice из private browser-credentials.json.
  Проверку внешних breaches отключили, секрет на Mac не передавался.
- Для чистого доказательства SSO после создания/входа Vault очистить только
  cookies Gitea через WebDriver на git-origin, затем Sign in with Keycloak:
  не должно быть повторного запроса LDAP-пароля. Проверить события Keycloak
  и общий sessionId клиентов. На13:53 eventsEnabled уже включён configure-keycloak.py.
- Tryton URI-команда не создала второго процесса (только19522), но завершилась
  SSHreset. Для раскрытия Party запрошен X11 клик по реальному окну
  xid0x200e03=2100739. Старый Login2097155 уже уничтожен, BadWindow по нему
  ничего не изменил. Перед дальнейшими кликами снова смотреть кадр.

### 13:49 МСК — прикладные службы и проверки

- APPS: python3-psycopg2 установлен; повтор sa6-configure-tryton success.
  Tryton6.0.12/PostgreSQL14: Alice в группе Party Administration, Bob без
  прикладной учётки. tools/check-tryton.py реально выполнен с WORKSTATION:
  Alice HTTP200, чтение SA6 Project; Bob с действующим LDAP-паролем HTTP401.
  HTTPS проверялся по системному CA и hostname. Выводы/реальный trytond.conf
  включены в main.typ, без утверждений о строгой проверке CA старым LDAP-модулем.
- Xpra3.1 запущен как Alice на :100. Дополнительные зависимости python3-pil
  на обоих узлах и python3-gi-cairo на WORKSTATION понадобились реально
  (первое подключение отклонялось из-за PIL, затем окна были чёрными из-за cairo).
  Исправлены install-apps/workstation. Сейчас изображение Tryton Login читается.
- Для исключения лишнего xterm добавлен ~/.xpra/xpra.conf Alice со start=/bin/true,
  отключающий стандартный /etc/X11/Xsession true. Новый сеанс после исправления:
  server.pid19494, uuid ed20d3ed33a34431ab3784f31e867ed4; Tryton pid19522,
  одно окно Login xid0x200003 (2097155), clients=1. Это исходная точка для
  будущей проверки reconnect, пока сам reconnect НЕ выполнен.
- SSH-ключ WORKSTATION sa6-alice создан, tools/authorize-xpra.py успешно передал
  ТОЛЬКО публичный ключ в authorized_keys Alice APPS. Приватные ключи не копировались.
  configure-xpra-client.sh создаёт permanent unit sa6-xpra-client, не включает
  автозапуск. Он подключает через SSH URL /100. Есть Desktop/sa6-tryton.desktop.
- Tryton GUI пока на первом окне Profile/Host/Database/username Alice, пароль
  ещё не введён. Первое xdotool Enter не изменило окно; запрошен клик Connect.
  Вход GUI НЕ считать подтверждённым. /root/sa6-private/alice-type на APPS
  создан 600 без вывода пароля, предназначен для xdotool --file только после
  появления настоящего password prompt; пароль на Mac не передавался.
- WEB: нативный mirror-pull упал. На PNET доставлен официальный Docker tar:
  /tmp/sa6-official-web-images.tar544363008 bytes, SHA256
  e8223edd6bb7e299c20f9f2a4adf237e0392fc7f7a3fbbfe258385422183e20e.
  SCP останавливался из-за зависания; rsync --append --inplace --bwlimit512
  завершился0. Host unit sa6-load-web-images проверил SHA256 и загрузил
  все4образа непосредственно в WEB Docker29.1.3 (хост Docker20.10 не трогали).
- На WEB успешно выполнен sa6-sa6-web-deploy: применены compose/nginx,
  проверены все4configID образов, подняты4контейнера, HTTPS Keycloak ready.
  Realm sa6, READ_ONLY OpenLDAP svc-keycloak LDAPS, fullsyncadded2/failed0,
  Alice/Bob federationLink проверен. EmailVerified отмечен администратором для
  фиктивных lab-адресов. OIDC confidential clients vaultwarden/gitea созданы.
  tools/configure-gitea.py успешно создал labadmin и источник Keycloak,
  Gitea перезапущен. Не печатать аргументы subprocess с secret при ошибках.
- Реальные configs/docker-compose.yaml и nginx-sa6.conf теперь ПРИМЕНЕНЫ.
  С WORKSTATION HTTPS auth/git/vault все200 с CA/hostname verification.
  web-containers.txt, workstation-web-https.txt добавлены в main.typ.
- WEB секреты /root/sa6-private/web-credentials.json и /opt/sa6/.env600;
  включает vault_master_alice/bob для будущего зашифрованного vault UI.
  Доступ по SSO и права коллекций пока НЕ проверены, сами vault-учётки не созданы.
- На WORKSTATION установлен webkit2gtk-driver2.50.4 и xdotool. sa6-webdriver
  слушает loopback4444 от labadmin на DISPLAY0. tools/browser.py скопирован
  /opt/sa6-tools/browser.py, сессия сохранена в /root/sa6-private/browser-session.json600.
  MiniBrowser запущен с acceptInsecureCerts=False, страница Gitea login открыта,
  кнопка Sign in with Keycloak видна, href/user/oauth2/Keycloak. SSO ещё НЕ выполнен.
- tools/capture.py получает реальные кадры без VNC; удачный desktop/окно Tryton
  в /tmp/sa6-tryton-login-ready.png. До wake xset dpms force on кадр мог быть
  Guest disabled display. Кадры в tmp пока не включены в отчёт как финальные.
- SSH всё ещё иногда timeout/reset даже после route. Большой SCP больше
  не работает; Docker tar уже завершён. Коммиты/staging не трогались.

### 13:28 МСК — после временного маршрута

- Пользователь выполнил `sudo route -n add -host 46.61.242.181 10.188.130.1`.
  route-get подтвердил en0/gateway10.188.130.1. Tailscale direct ping стал19мс;
  обычный SSH снова выполнил uptime. Проверка устойчивости продолжается.
  После завершения теста/работы напомнить удалить временный маршрут командой
  `sudo route -n delete -host 46.61.242.181` (если не решено оставить его).
- WORKSTATION: sa6-configure-workstation success/active(exited), LightDM active,
  XFCE pid15781. Реальный framebuffer показал рабочий стол XFCE. Конфиг/вывод
  сохранён outputs/workstation-gui.txt и добавлен в main.typ.
- APPS: range-install завершился, sa6-applications был запущен после него,
  но упал на missing psycopg2 (при --no-install-recommends драйвер не поставился).
  Добавлен python3-psycopg2 в install-apps.sh; установка драйвера запрошена.
  Повтор конфигурации безопасен: созданные role/db не удаляются. Tryton/Xpra
  ещё не считать рабочими до следующей проверки.
- WEB: sa6-pull-images-verified реально запущен, Docker начал получать слои
  Keycloak через m.daocloud.io по официальному digest. Остальные образы/контейнеры
  пока не подтверждены.
- tools/capture.py читает framebuffer QEMU через host monitor.sock, сжимает PPM
  в stdout SSH и удаляет временный PPM на хосте; PNG собирается на Mac.
  Сессия15/node sessions26-29 зафиксированы в коде; перед использованием позже
  проверить актуальные id. Успешно получен /tmp/sa6-workstation-desktop.png.

### 13:24 МСК — диагностика доступа

- `tailscale nc` как процесс-локальный SSH ProxyCommand один раз успешно
  выполнил uptime/sshd-T, затем снова timeout. В run.py добавлен необязательный
  --tailscale-nc. Это пока НЕ подтверждённое решение проблемы.
- sshd MaxStartups10:30:100, MaxSessions10, LoginGraceTime120; нагрузка хоста
  около0.24. Доказательств перегрузки sshd нет.
- route-get: 100.100.57.19 идёт через utun4 (MTU1280), внешний endpoint PNET
  46.61.242.181 через второй default tunnel utun5 (MTU1400). Физический en0
  имеет gateway10.188.130.1. Вложенный VPN — гипотеза причины сбоев.
- Для узкой временной проверки подготовлена команда
  `sudo route -n add -host 46.61.242.181 10.188.130.1` (удаление:
  `sudo route -n delete -host 46.61.242.181`). Маршрут НЕ добавлен:
  sudo-n сообщил password required. Не запрашивать и не сохранять sudo-пароль.
  Перед применением позже снова проверить текущий endpoint/gateway.
- Повторный Ctrl-C в консоли WORKSTATION не подтвердился (API read timeout).
  Перед любым новым консольным вводом обязательно прервать частичный heredoc.

## Предыдущая точка остановки — 2026-11-27, пауза отменена

ВМ и сессию не останавливать; уже запущенные фоновые установки могут
продолжать работу. Состояние ниже дополнено новым checkpoint выше.

**Рабочий стенд:** `/SA labs/SA6.unl`, session15/pod7/vlad_pc, четыре QEMU.
Топология и адреса остались прежними; опубликованных настроенных образов нет.

**Достоверно готово:**

- DIRECTORY: OpenLDAP2.5.20 с LDAPS, собственный CA, Alice/Bob и группы employees/guests/xpra-users; NFS `/srv/nfs/team` для APPS/WORKSTATION, sec=sys/root_squash. Службы active и выводы сохранены.
- APPS и WORKSTATION: SSSD/NSS/PAM настроены, getent/id получают одинаковые LDAP UID/GID, NFS смонтирован. Это пока НЕ доказывает парольную аутентификацию через PAM.
- NFS проверен с двух клиентов: Alice создала файл с WORKSTATION и дописала с APPS; alice/employees, mode660. Bob получает Permission denied/exit1. Root клиента с UID0 также получает Permission denied/exit1.
- APPS: SSH drop-in реально применён через консоль, `sshd -T` подтвердил usepam/passwordauthentication=yes и allowgroups sudo/xpra-users. Парольный вход Alice и отказ Bob ещё НЕ проверены.
- Служебный автологин labadmin на tty1 подтверждён скриншотами APPS и WORKSTATION. Скрипт хоста был запущен для четырёх ВМ, но результат DIRECTORY/WEB отдельно не проверен. Доступ к консоли идёт через авторизованную сессию PNET.

**Что проверить первым при продолжении:**

1. Состояния `sa6-sa6-range-install-workstation`, `sa6-sa6-range-install-web`, `sa6-sa6-range-install-apps` и соответствующие `/var/log/<unit>.log`. Запуск WORKSTATION и WEB подтверждён; APPS был not-found, повторный запрос завершился SSHtimeout — результат не подтверждён. Не запускать дубликаты APT. На последней успешной проверке WORKSTATION два пакета уже прошли SHA256, скачивался libavcodec58.
2. Консоль WORKSTATION осталась внутри НЕДОПИСАННОГО heredoc от неудачного push `/tmp/sa6-check-ssh-auth.py` (виден prompt `>` и обрывок base64). Сначала прервать Ctrl-C, убедиться в обычном приглашении. Не выполнять этот файл до нового push и проверки MD5. Если включился графический вход после установки LightDM — перейти на tty1.
3. Перед push отключить echo (`stty -echo`), использовать `tools/console.py` из venv MCP: HTTP/WS timeout45, ping_interval=None. После успешного push вернуть `stty echo`. Это настройки только процесса, не общего MCP. Сложные символы через обычный read_console теряют Shift; простые команды в нём работают.
4. Завершить SSH/PAM-проверки с WORKSTATION: `tools/check-ssh-auth.py` читает только закрытый `directory-credentials.json`, пароли не печатает. Ожидаются LDAP bind обоих пользователей, SSH Alice разрешён, Bob отклонён групповой политикой. Сверить также журнал SSH на APPS.
5. Далее — Tryton/PostgreSQL и Xpra, графическая рабочая станция, затем Keycloak/Gitea/Vaultwarden и SSO/права коллекций. Они пока не настроены и не проверены.

**Артефакты и ограничения:**

- В main.typ включены только подтверждённые LDAP/NFS и настройки SSH. Реальные выводы в outputs/. Короткие выводы findmnt и перенос exportfs через fold заменили нечитаемые длинные строки; файлы конфигураций в configs/sssd.conf и ssh-apps.conf соответствуют применённым сценариям.
- Перед паузой main.pdf пересобран (8страниц), новые страницы с LDAP/NFS и правилами SSH просмотрены после устранения обрезанных строк. git diff --check, Python AST и bash -n прошли. Это черновик, не завершённый отчёт по всему варианту.
- `configs/docker-compose.yaml` и `configs/nginx-sa6.conf` — ПОДГОТОВЛЕННЫЕ, но НЕ применённые конфигурации. Не выдавать их за рабочие службы.
- `tools/apt/*.json` содержат точные SHA256 пакетов, проверенных на Mac. Range-worker качает с mirror.yandex.ru частями256КБ, 4потока, проверяет SHA256 перед заполнением APT-кэша и устанавливает с --no-download. `/tmp/sa6-range-install-*.sh` на Mac — готовые задания. Для APPS осталось33пакета/63.7МиБ, WEB3/70.1МиБ, WORKSTATION4/19.4МиБ по исходным манифестам; фактический остаток уже мог уменьшиться.
- Большие SCP/rsync прерывались; частичные `/tmp/sa6-*-packages.tar` на PNET не распаковывать без SHA256. Локальные передачи и временный HTTP-сервер остановлены/завершились; активных локальных помощников на момент паузы не было.
- На Mac скачаны официальные amd64-образы Keycloak26.8.2, Vaultwarden1.37.5, Gitea28.4.0, Postgres17-alpine; контейнеры на Mac не запускались. DockerHub gitea/gitea:28.4.0 имеет тот же digest, что docker.gitea.com/gitea:28.4.0. Образы на WEB не загружены.
- Нативный pull хоста упал на TLS к quay.io. `tools/pull-mirrored-images.py` подготовлен для загрузки публичных образов через DaoCloud по официальным digest с последующей проверкой config ID; запуск на PNET не подтверждён (SSHtimeout). Глобальная конфигурация Docker/SSH/Tailscale не менялась.
- В фактическом Tryton ldap_authentication6.0.0 из .deb параметр scope разбирается как `base/onelevel/subtree`. Для URI использовать `?uid?subtree`, не `sub`. LDAPS поддержан; не приписывать этому старому модулю проверку CA, которой в его ldap_server() нет.
- Публичный CA сохранён в configs/sa6-ca.crt. Секреты — только /root/sa6-private на гостях. MCP-креды не копировались/не выводились. Коммитов и изменений staging ассистент не делал; общий mephi-labs не менялся.

## 2026-11-27 — оценка выполнимости

- Методичка: `preamble/Лабораторная работа №6 (СА).pdf`, 20 страниц; тема «Централизованная работа пользователей». Варианты 1–6 находятся на страницах 15–18. Вариант пользователя пока не выбран.
- По SSH проверен хост PNETLab `100.100.57.19`: 4 vCPU, около 19 ГиБ RAM (доступно около 16 ГиБ), свободно 145 ГБ на корневом разделе, `/dev/kvm` существует, nested KVM включён. Эти показатели относятся только к моменту проверки.
- Есть базовые образы `linux-debian-13`, `linux-ubuntu-server-22.04`, `winserver-S2019-VL-x64`. Наличие образа не подтверждает настройку нужных служб внутри него.
- Для варианта 6 возможна схема из четырёх Linux-ВМ: каталог и NFS; сервер Xpra и прикладное ПО; Keycloak, Vaultwarden и второе OIDC-приложение; отдельная графическая рабочая станция с Xpra-клиентом и браузером. Оценка памяти 8–10 ГиБ, фактическая нагрузка ещё не проверялась.
- Стенд СА №6 не создавался, службы и проверки задания не выполнялись. Существующие узлы и сессии не изменялись.

## 2026-11-27 — развёртывание (в работе)

- После согласия пользователя начат вариант 6 с Xpra по предложенной схеме. Рабочая лаба `/SA labs/SA6.unl`, session 15, pod 7, `vlad_pc`. Присоединяться через Join, не создавать вторую работающую копию с pnet0.
- Узлы: DIRECTORY id1/session26, APPS id2/session27, WEB id3/session28, WORKSTATION id4/session29. RAM: 1024/2560/4096/2048 МиБ, всего 9728 МиБ. Диски: 12/16/24/16 ГиБ.
- Все e0 подключены к bridge id1 (`10.60.0.0/24`), e1 к pnet0 id2. ОС: Ubuntu 22.04.5. Рабочие адреса `.10/.20/.30/.100`; служебные `192.168.15.231–234`, шлюз служебной сети `192.168.15.2`.
- Созданы отдельные начальные образы `linux-sa6-directory`, `linux-sa6-apps`, `linux-sa6-web`, `linux-sa6-workstation` с backing file общего Ubuntu-образа. Общий образ не изменялся. Seeds на хосте: `/opt/unetlab/sa6-seeds/`.
- Все 4 ОС загрузились, cloud-init `done`, errors `[]`, SSH `active`. Реальные выводы: `outputs/*-platform.txt`. WORKSTATION пингует три сервера по рабочей сети: по 2/2 ответа, 0% потерь (`outputs/workstation-network.txt`). Это подтверждает базовую сеть, а не службы задания.
- SSH гостевых ОС: `labadmin`, sudo без пароля, ключ на PNET-хосте `/root/.ssh/id_rsa_dy`. Вход в консоль по паролю пока не настроен. `tools/run.py` выполняет команды через хост; `--file --background` создаёт systemd-задание `sa6-<имя файла без расширения>`, журнал `/var/log/sa6-<имя>.log` на соответствующем госте.
- Канал к хосту нестабилен: SSH timeout/reset, Tailscale иногда direct, иногда DERP Paris. Пользователь подтвердил доступность веб-интерфейса. Хост был online и с низкой нагрузкой. Корневая причина не установлена. Временный SSH ControlMaster `/tmp/pnet-sa6-ssh.sock` используется `tools/run.py`, если сокет существует; глобальные настройки SSH/Tailscale не менялись.
- `commands/install-*.sh` переключены на HTTPS/IPv4 и без переводов индексов. Остальные `commands/configure-*.sh` подготовлены, но ещё НЕ запускались и НЕ проверены. Не считать LDAP/NFS/Xpra/SSO настроенными.
- Старые HTTP APT update на DIRECTORY/APPS остановлены (exit0). Новые HTTPS-установки DIRECTORY/APPS запущены как `sa6-install-directory` / `sa6-install-apps`: в последних успешных чтениях обе activating/start. DIRECTORY: последняя проверка показала `apt-get update` PID2179, elapsed06:01; Universe скачивался с повторами. WORKSTATION: передача с SHA256 OK и запуск `sa6-install-workstation` подтвердились exit0. WEB: файл HTTPS-установки передан с SHA256 OK, `systemctl restart --no-block sa6-install-web` подтвердился exit0, затем activating/start. Завершение НИ ОДНОЙ из четырёх установок пока не проверено. Перед повторением читать состояние unit и журнал; не запускать дубли APT.
- `tools/run.py --background` теперь использует `systemd-run --no-block`: без этого Type=oneshot ждал окончания установки и SSH-клиент мог оборваться, хотя гостевая задача продолжалась. Перед запуском переданного файла проверяется SHA256. Содержимое секретов в вывод не попадало.
- Диагностика Tailscale: 20 disco ping, 6 ответов, 14 timeout; ответы direct к PNET-хосту с RTT 10–659 мс. Это измерение данного канала, а не доказательство причины. HTTPS-загрузка Release на WORKSTATION: 255884 байта за 10 секунд и exit28 (неполное тело); не считать это успешной загрузкой файла. Проверка зеркала Yandex завершилась timeout без данных, зеркало не менялось.
- Временно отправлялась проверка MTU1280 только на ens4 DIRECTORY. Из-за обрыва её выполнение не подтверждено; pending SSH-клиент этой проверки завершён локально (exit241). Две попытки возврата MTU1500 завершились локально с SSH exit255, поэтому фактический MTU остаётся НЕ известен. При возобновлении проверить и вернуть1500, если необходимо. Постоянные netplan/cloud-init настройки MTU не менялись. Временный ControlMaster закрыт; глобальная сеть, SSH-конфиг и Tailscale не менялись.
- При возобновлении: проверить ens4 DIRECTORY (MTU1500), затем состояния четырёх `sa6-install-*` и журналы `/var/log/sa6-install-*.log`. Не запускать дубли APT и не считать наличие package name в dpkg-query без версии подтверждением установки. После успешной установки DIRECTORY применить `commands/configure-directory.sh`; до этого LDAP/TLS/NFS не созданы.
- Топология сохранена в `stand/pnetlab_export-20261127.zip`. Настроенные гостевые диски в ZIP не входят. Публикация образов не выполнялась. Чужие лабы/сессии не изменялись, коммитов нет.
- Черновик `main.typ` собирается с `typst compile --package-path /tmp/pnet-typst-packages --font-path mephi-labs/fonts SA/lab6/main.typ SA/lab6/main.pdf`. Пакет временно скопирован из `mephi-labs`, общий шаблон не изменён. Текущий PDF4страницы: подготовка и реальные проверки базовой сети, без утверждений о работающих LDAP/NFS/Xpra/SSO. Преподаватель пока не задан.
- Пользователь попросил промежуточный итог и продолжение позже. Новые этапы сейчас не запускать. Сессия и узлы не останавливались; запущенные systemd-установщики могут продолжить работу и завершиться без SSH. Проверить их актуальное состояние в начале следующего этапа. `git diff --check`, Python AST и `bash -n` прошли; это проверки файлов, а не подтверждение развёртывания служб.

## 2026-11-27 — продолжение, после 10:32 МСК

- Пользователь возобновил работу. Через helper подтверждены session15/pod7 и 4 работающих узла; get_lab вернул ту же топологию. Первый list_running_labs ошибочно вернул пустой список; последующий показал все сессии. Ничего не пересоздавать.
- На DIRECTORY MTU ens4 подтверждён1500. Установка DIRECTORY успешно закончилась: slapd/ldap-utils2.5.20, nfs-kernel-server2.6.1. Применён configure-directory.sh, unit sa6-configure-directory success/active(exited). Созданы CA и сертификаты, LDAPS, пользователи alice UID10001/GID10000 и bob UID10002/GID10001, группы employees/guests/xpra-users. Имя staff заменено на employees, чтобы не пересечься с локальной Ubuntu-группой staff GID50.
- LDAPS-поиск и NFS exportfs проверены, обе службы active. Вывод outputs/directory-services.txt включён в main.typ. Публичный CA: configs/sa6-ca.crt. Клиентские проверки ещё не выполнены.
- Ночные установки APPS/WEB/WORKSTATION закончились с ошибками. APPS: ошибочное имя python3-proteus исправлено на tryton-proteus. WEB и WORKSTATION: не скачались крупные .deb. В APT-кэше WORKSTATION сохранилось139МБ пакетов; они перенесены напрямую внутри PNET в APT-кэш APPS.
- Минимальный LDAP-клиент на APPS установлен из кэша, sa6-install-ldap-client success/active(exited). Первый такой запуск WORKSTATION без --no-install-recommends закончился ошибкой из-за необязательных зависимостей; повторён корректный минимальный запуск как sa6-client-bootstrap, результат проверить.
- Недостающие пакеты скачаны на Mac с проверкой размеров и контрольных сумм из apt-get --print-uris: /tmp/sa6-apps-packages.tar142МБ, web70МБ, workstation19МБ. Root-host transfer SCP/rsync прерывался и пока НЕ завершён; частичные tar на PNET нельзя распаковывать без проверки SHA256. tools/fetch-apt-cache.py готовит архивы; tools/install-apt-cache.py предназначен для root-хоста и проверяет SHA256 перед передачей гостю.
- Python PNET-хоста3.6.9: shlex.join там отсутствует; distribute-directory.py исправлен на join(shlex.quote(...)). Скрипт успешно передал CA, нужные TLS-ключи и directory-credentials.json на APPS/WEB/WORKSTATION, только в /root/sa6-private (700/600). Значения не выводились.
- Для CLI используется постоянная интерактивная SSH-сессия root (IPQoS=ef); серверные сетевые настройки не менялись. Прямой SSH по публичному адресу проверку не прошёл. Временный HTTP-сервер Mac на TailnetIP:18080 не помог и остановлен.
- На Mac скачаны amd64-образы Keycloak26.8.2, Vaultwarden1.37.5, Gitea28.4.0, Postgres17-alpine. На WEB они пока НЕ передавались и НЕ запускались.

- Оба LDAP-клиента APPS и WORKSTATION настроены через configure-client.sh: getent/id возвращают LDAP-идентичности, employees GID10000 и xpra-users GID10010 у Alice; NFS смонтирован с sec=sys. Реальные выводы outputs/apps-ldap-nfs.txt и workstation-ldap-nfs.txt.
- NFS проверен между двумя клиентами: Alice создала файл на WORKSTATION, дописала с APPS; владелец alice/employees, mode660. Bob получает Permission denied/exit1; root на клиенте (UID0) также Permission denied/exit1. Выводы apps-nfs-write.txt, workstation-nfs-rights.txt.
- Служебный автологин labadmin на tty1 включён на четырёх гостях через console-access.sh и enable-consoles.py, unit хоста sa6-enable-consoles. Хост systemd237 не поддерживает StandardOutput=append; для host-задач использовать journal. Не трогать getty занятого человека (скрипт проверяет who). Эти консоли защищены доступом к сессии PNET; пользовательские проверки LDAP выполняются отдельно через SSH.
- На APPS применён configure-apps-access.sh; sshd -T показал usepam/passwordauthentication=yes и allowgroups sudo/xpra-users. CLI SSHPAM-проверка Alice/Bob ещё не выполнена. На консоли APPS открыт root через sudo-i.
- MCP read_console теряет Shift для знаков (двоеточие/вертикальная черта). Ввод сложных команд/файлов — pnet-helper.py с правильным Shift; увеличить open_timeout websockets.connect до45 процесс-локально (functools.partial). Пуш configure-apps-access.sh через консоль успешно проверен MD5 278c2487ef05d7fe20702a76a6596cd8.
- Прямая передача больших tar через SCP/rsync не завершилась (root partial tar не использовать). Загрузка фрагмента262144байт с mirror.yandex.ru на WEB успешно дала HTTP206 за5.15с. Подготовлены tools/guest-apt-range.py, prepare-range-jobs.py и tools/apt/*.json: SHA256 взяты с проверенных Mac-копий пакетов. Worker качает частями256КБ, 4 потока, проверяет SHA256 и запускает apt-get --no-download.
- Range-job WORKSTATION подтвердился как sa6-sa6-range-install-workstation, лог /var/log/sa6-sa6-range-install-workstation.log. APPS запуск получил SSHreset, статус проверить перед повтором. WEB запрос на запуск также отправлен, статус проверить. Сценарии /tmp/sa6-range-install-*.sh созданы на Mac; run.py добавляет sa6- к basename, поэтому двойной префикс unit и /tmp-файлов ожидаем.
- Нативная загрузка Docker-образов на PNET-хосте (sa6-pull-web-images) закончилась TLS handshake timeout к quay.io. Глобальная конфигурация Docker и его работающие контейнеры не менялись. Mac-копии образов: /tmp/sa6-web-images.tar519МБ и .tar.gz515МБ, на хост не переданы. Официальные manifest/config digest записаны в tools/web-image-digests.json.
