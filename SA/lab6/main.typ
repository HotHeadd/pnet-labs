#import "@local/mephi-lab:0.1.0": lab-report

#show: lab-report.with(
  lab-number: 6,
  topic: "Централизованная работа пользователей",
  discipline: "Системное администрирование",
  student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."),
  group: "Б23-505",
  teacher: "Басыня Е. А.",
  section-pagebreaks: false,
)

= Цель работы

Получить практические навыки централизованного доступа к приложениям
и сетевым ресурсам, подключения Linux к каталогу пользователей
и разграничения прав в операционной системе и приложениях.

= Задание

Вариант 6. Развернуть OpenLDAP, сервер приложений Linux с Xpra
и графическим клиентом Tryton. Настроить вход пользователей Linux
через каталог и отдельную аутентификацию в Tryton. Подключиться
с отдельной рабочей станции по SSH в режиме seamless, проверить
сохранение сеанса после отключения. Настроить NFS, LDAP-федерацию
Keycloak, OIDC-вход в Gitea и Vaultwarden и проверить единый вход
и права доступа.

= Ход работы

== Схема и адресация

В PNETLab созданы четыре виртуальные машины с Ubuntu Server 22.04.5.
DIRECTORY обслуживает каталог и общий файловый ресурс, APPS запускает
Tryton и Xpra, WEB содержит веб-сервисы. На WORKSTATION установлен
XFCE, клиент Xpra и браузер. Схема с версиями основных компонентов
приведена на рисунке @fig-topology.

#figure(
  image("img/topology.svg", width: 100%),
  caption: [Схема инфраструктуры и версии программного обеспечения],
) <fig-topology>

Рабочие интерфейсы объединены сетью 10.60.0.0/24
(таблица @tab-addresses). Вторые интерфейсы подключены к служебной сети
192.168.15.0/24 для администрирования и установки пакетов.

#figure(
  table(
    columns: (1.2fr, 1.5fr, 2fr),
    inset: 6pt,
    table.header([*Узел*], [*Рабочий адрес*], [*Назначение*]),
    [DIRECTORY], [10.60.0.10/24], [OpenLDAP, NFS],
    [APPS], [10.60.0.20/24], [Xpra, Tryton, PostgreSQL],
    [WEB], [10.60.0.30/24], [Keycloak, Vaultwarden, Gitea],
    [WORKSTATION], [10.60.0.100/24], [Xpra-клиент, браузер],
  ),
  caption: [Адресация узлов],
) <tab-addresses>

На APPS используются Tryton Server 6.0.12, Tryton Desktop Client 6.0.10
и PostgreSQL 14.24. На WEB работают Keycloak 26.8.2, Gitea 28.4.0,
Vaultwarden 1.37.5 и PostgreSQL 17.12; HTTPS обслуживает nginx 1.18.0.

== Каталог OpenLDAP

На DIRECTORY создан каталог с базой #raw("dc=sa6,dc=test").
В подразделении People находятся Alice и Bob с POSIX-атрибутами
для Linux. Alice имеет UID 10001 и основную группу employees с GID 10000;
Bob имеет UID 10002 и группу guests с GID 10001. Отдельная группа
xpra-users содержит Alice и разрешает ей доступ к серверу приложений.

Пользователи и состав xpra-users проверены командами #raw("ldapsearch")
по LDAPS. На рисунке @fig-directory-ldap видны DN пользователей,
числовые идентификаторы, членство Alice в группе и состояние служб.

#figure(
  image("img/directory-ldap-terminal.png", width: 100%),
  caption: [Проверка пользователей и группы доступа на DIRECTORY],
) <fig-directory-ldap>

Для LDAP установлен серверный сертификат собственного центра
сертификации. В действующей конфигурации slapd указаны сертификат CA,
серверный сертификат и закрытый ключ. Сервер слушает рабочий адрес
10.60.0.10, в том числе по LDAPS. Значения прочитаны из #raw("cn=config")
и файла #raw("/etc/default/slapd") на рисунке @fig-directory-tls.

#figure(
  image("img/directory-tls-terminal.png", width: 100%),
  caption: [Параметры TLS и адреса прослушивания OpenLDAP],
) <fig-directory-tls>

== Подключение Linux к каталогу

На APPS и WORKSTATION настроен SSSD. NSS получает из LDAP сведения
о пользователях и группах, PAM проверяет пароль и создаёт домашний каталог
при первом входе. В #raw("/etc/nsswitch.conf") добавлен источник sss,
а в PAM подключён #raw("pam_sss.so"). В SSSD выбран LDAP-провайдер,
указаны базы поиска People и Groups, схема RFC2307 и LDAPS с обязательной
проверкой сертификата по лабораторному CA.

На рисунке @fig-sssd показаны действующий файл #raw("sssd.conf"),
источники NSS и подключение PAM на APPS.

#figure(
  image("img/apps-sssd-terminal.png", width: 100%),
  caption: [Конфигурация SSSD и её связь с NSS и PAM],
) <fig-sssd>

Команды #raw("getent passwd"), #raw("id") и #raw("findmnt") на WORKSTATION
подтвердили получение учётных записей и групп из каталога и монтирование
общего ресурса. Alice входит в employees и xpra-users, Bob только в guests.
У обоих клиентов используются одинаковые UID/GID
(рисунок @fig-workstation-ldap).

#figure(
  image("img/workstation-ldap-terminal.png", width: 100%),
  caption: [LDAP-идентичности и общий ресурс на WORKSTATION],
) <fig-workstation-ldap>

== Общий файловый ресурс NFS

На DIRECTORY каталог #raw("/srv/nfs/team") экспортирован для APPS
и WORKSTATION. Владельцем назначен UID 10001, группой GID 10000.
Каталог имеет setgid и наследуемые ACL: владелец и группа получают
чтение, запись и проход, остальные пользователи доступа не имеют.
Параметр root_squash ограничивает права root удалённого клиента.
Экспорт, ACL и владельцы файлов проверены на рисунке @fig-directory-nfs.

#figure(
  image("img/directory-nfs-terminal.png", width: 100%),
  caption: [Экспорт NFS, владельцы и наследуемые права каталога],
) <fig-directory-nfs>

Оба клиента монтируют ресурс в #raw("/mnt/team"). С WORKSTATION от имени
Alice создан файл #raw("sa6-report.txt"), затем через SSH от той же
учётной записи на APPS в него добавлена вторая строка. После возврата
на WORKSTATION прочитаны обе строки. У файла владелец alice,
группа employees и права 660.

Bob не входит в employees и получает Permission denied; код завершения
чтения равен 1. Чтение от root клиента с UID 0 также завершается отказом.
Все команды и результаты приведены на рисунке @fig-nfs-rights.

#figure(
  image("img/nfs-rights-terminal.png", width: 100%),
  caption: [Запись с двух клиентов NFS и проверка файловых прав],
) <fig-nfs-rights>

Использован #raw("sec=sys"): NFS доверяет переданным клиентом UID/GID.
Такая настройка предназначена для доверенных клиентских машин
и не выполняет криптографическую аутентификацию пользователей NFS.

== Парольный вход на сервер приложений

На APPS включены PAM и парольная аутентификация SSH. Доступ разрешён
группам sudo и xpra-users. Учётная запись labadmin служит для
администрирования; пользовательский вход проверяется отдельно.

На WORKSTATION команда #raw("ldapwhoami") с запросом пароля подтвердила
действительность LDAP-паролей Alice и Bob. Затем выполнен SSH-вход
с отключённой аутентификацией по ключу. Alice успешно выполнила #raw("id")
на APPS и получила код завершения 0, Bob получил отказ и код 255
(рисунок @fig-ssh-auth).

#figure(
  image("img/workstation-ssh-auth-terminal.png", width: 100%),
  caption: [Проверка LDAP-паролей и SSH-доступа с WORKSTATION],
) <fig-ssh-auth>

Вывод #raw("sshd -T") показывает действующие правила. Журнал SSH
подтверждает парольный вход Alice и отказ Bob по AllowGroups
(рисунок @fig-ssh-policy).

#figure(
  image("img/apps-ssh-policy-terminal.png", width: 100%),
  caption: [Правила SSH и причина отказа Bob на APPS],
) <fig-ssh-policy>

== Tryton и отдельная прикладная аутентификация

Использована трёхзвенная архитектура: Tryton Desktop Client обращается
к серверу Tryton по HTTPS, сервер выполняет прикладную логику и работает
с PostgreSQL через локальный Unix-сокет. При публикации через Xpra
графический клиент также выполняется на APPS, а WORKSTATION получает
только его окно.

В базе sa6 активирован модуль ldap_authentication. Для Alice создана
учётная запись Tryton с правами Party Administration; автоматическое
создание пользователей отключено. Bob учётной записи приложения не имеет.
На рисунке @fig-tryton-config показаны настройки HTTPS, PostgreSQL и LDAP,
а также результат запроса к таблице пользователей приложения.

#figure(
  image("img/apps-tryton-config-terminal.png", width: 100%),
  caption: [Настройки Tryton и учётная запись Alice в прикладной базе],
) <fig-tryton-config>

С WORKSTATION обычным #raw("curl") выполнены HTTPS-запросы к Tryton
с запросом пароля в терминале. Метод #raw("model.party.party.search_read")
вернул Alice запись SA6 Project и HTTP 200. Аналогичный запрос Bob
с действующим LDAP-паролем отклонён с HTTP 401
(рисунок @fig-tryton-auth). Проверка сертификата HTTPS не отключалась.

#figure(
  image("img/tryton-auth-terminal.png", width: 100%),
  caption: [Положительная и отрицательная проверки доступа к Tryton],
) <fig-tryton-auth>

== Публикация окна через Xpra

На APPS от имени Alice запущен сохраняемый сеанс Xpra #raw(":100")
с Tryton Desktop Client. WORKSTATION подключается командой
#raw("xpra attach") к #raw("ssh://alice@apps.sa6.test/100") по отдельному
SSH-ключу Alice. Параметр #raw("--exit-with-client=no") сохраняет серверный
сеанс после отключения клиента.

После прикладного входа Alice открыт справочник Party с записью
SA6 Project (рисунок @fig-xpra-tryton). Полный рабочий стол APPS
не передаётся; панель XFCE на снимке принадлежит WORKSTATION.

#figure(
  image("img/xpra-tryton-after-reconnect.png", width: 100%),
  caption: [Окно Tryton в режиме seamless на WORKSTATION],
) <fig-xpra-tryton>

Для проверки на WORKSTATION остановлен клиент #raw("sa6-xpra-client"),
затем запущен снова. До отключения, без клиента и после подключения
на APPS выполнена команда #raw("xpra info"). Число клиентов изменилось
с 1 на 0 и снова на 1, UUID сеанса и PID серверного процесса и Tryton
остались прежними (рисунок @fig-xpra-reconnect). Повторный вход
в приложение не потребовался.

#figure(
  image("img/apps-xpra-reconnect-terminal.png", width: 100%),
  caption: [Состояние одного сеанса Xpra до и после переподключения],
) <fig-xpra-reconnect>

== Веб-сервисы и HTTPS

На WEB запущены контейнеры Keycloak, Gitea, Vaultwarden и PostgreSQL.
Nginx принимает HTTPS-запросы к auth.sa6.test, git.sa6.test и
vault.sa6.test и передаёт их на порты контейнеров, доступные через
loopback. Список контейнеров, параметры nginx и сертификат показаны
на рисунке @fig-web-services.

#figure(
  image("img/web-services-terminal.png", width: 100%),
  caption: [Контейнеры, обратный прокси и серверный сертификат WEB],
) <fig-web-services>

На WORKSTATION установлен сертификат лабораторного CA. Команды
#raw("curl") проверили все три адреса с обычной проверкой цепочки
сертификата и имени сервера. Каждый сервис вернул HTTP 200;
для Keycloak выполнен переход по штатным перенаправлениям
(рисунок @fig-web-https).

#figure(
  image("img/workstation-https-terminal.png", width: 100%),
  caption: [Проверка HTTPS веб-сервисов с WORKSTATION],
) <fig-web-https>

== LDAP-федерация Keycloak и OIDC

В realm sa6 подключён LDAP-провайдер sa6-ldap. Для соединения задан
#raw("ldaps://directory.sa6.test:636"), для поиска пользователей
#raw("ou=People,dc=sa6,dc=test"), для имени пользователя атрибут uid.
Используется служебная учётная запись svc-keycloak. Режим READ_ONLY
разрешает читать пользователей из каталога без изменения их записей.
Настройки подключения и поиска показаны на рисунках
@fig-keycloak-ldap и @fig-keycloak-search.

#figure(
  image("img/keycloak-ldap.png", width: 100%),
  caption: [Подключение LDAP-провайдера Keycloak к OpenLDAP],
) <fig-keycloak-ldap>

#figure(
  image("img/keycloak-ldap-search.png", width: 100%),
  caption: [READ_ONLY и параметры поиска пользователей каталога],
) <fig-keycloak-search>

В разделе Clients созданы конфиденциальные OIDC-клиенты gitea
и vaultwarden с Authorization Code flow (рисунок @fig-keycloak-clients).
Для Gitea зарегистрирован адрес возврата
#raw("https://git.sa6.test/user/oauth2/Keycloak/callback"),
для Vaultwarden #raw("https://vault.sa6.test/identity/connect/oidc-signin").
В Gitea подключён источник аутентификации Keycloak, в Vaultwarden
указаны realm sa6, Client ID vaultwarden и соответствующий секрет клиента.

#figure(
  image("img/keycloak-clients.png", width: 100%),
  caption: [OIDC-клиенты Gitea и Vaultwarden в Keycloak],
) <fig-keycloak-clients>

== Последовательный вход в Gitea и Vaultwarden

Сначала Alice вошла в Gitea через Sign in with Keycloak. Keycloak
проверил её LDAP-пароль, после возврата в Gitea открылся интерфейс
пользователя alice (рисунок @fig-sso-gitea).

#figure(
  image("img/sso-gitea.png", width: 100%),
  caption: [Первый вход: Gitea под учётной записью Alice],
) <fig-sso-gitea>

Затем в том же браузере открыт Vaultwarden. После указания
#raw("alice@sa6.test") и выбора Use single sign-on повторный LDAP-пароль
не запрашивался. Для расшифровки хранилища отдельно введён мастер-пароль
Vaultwarden (рисунок @fig-sso-vaultwarden).

#figure(
  image("img/sso-vaultwarden.png", width: 100%),
  caption: [Vaultwarden после единого входа и разблокировки хранилища],
) <fig-sso-vaultwarden>

В событиях Keycloak сохранены два входа Alice: gitea в 13:56:30 UTC
и vaultwarden в 14:00:34 UTC 27.11.2026. Оба относятся к одному
sessionId. Это согласуется с использованием общего сеанса Keycloak;
мастер-пароль хранилища выполняет отдельную задачу и не заменяет SSO.
Последние две строки выборки событий имеют одинаковый session_id
(рисунок @fig-keycloak-events).

#figure(
  image("img/keycloak-events-terminal.png", width: 100%),
  caption: [События входа Alice и общий сеанс двух OIDC-клиентов],
) <fig-keycloak-events>

== Права коллекций Vaultwarden

В организации SA6 Team Alice назначена роль Owner. Bob добавлен
как User с доступом View items только к коллекции Shared.
Коллекция Private ему не назначена. На рисунке @fig-vault-members
видны роли участников и назначение Shared.

#figure(
  image("img/vault-members.png", width: 100%),
  caption: [Участники организации и назначенная Bob коллекция],
) <fig-vault-members>

В отдельном приватном браузере Bob видит общую запись Shared demo account,
но не видит Private (рисунок @fig-vault-bob). У Alice доступны обе коллекции.
Пароли демонстрационных записей не используются для входа в службы.

#figure(
  image("img/vault-bob-shared.png", width: 100%),
  caption: [Хранилище Bob с доступом только к Shared],
) <fig-vault-bob>

Серверная проверка от имени Bob подтвердила HTTP 200 для чтения Shared
и отказ HTTP 400 при чтении Private. Попытка передать в Shared прежнее
зашифрованное содержимое также отклонена: Cipher is not write accessible.
Версия общей записи после попытки изменения сохранилась.
Проверки выполнены обычными HTTPS-запросами #raw("curl") с токеном Bob;
адрес электронной почты из профиля подтверждает учётную запись запроса
(рисунок @fig-vault-rights).

#figure(
  image("img/vault-rights-terminal.png", width: 100%),
  caption: [Проверка чтения и запрета изменения через API Vaultwarden],
) <fig-vault-rights>

== Разделение проверок доступа

Парольный вход Linux проходит через PAM и SSSD; группы каталога
ограничивают доступ к APPS через AllowGroups. Для транспорта Xpra
используется SSH-ключ Alice, а пароль Tryton проверяется отдельно
через LDAP и требует учётной записи приложения. Поэтому наличие Bob
в каталоге не даёт ему доступ к серверу приложений и Tryton.

Веб-приложения доверяют Keycloak как поставщику идентификации.
После проверки пользователя клиент получает код авторизации и
обменивает его на токены. Зарегистрированный Redirect URI задаёт
разрешённый адрес возврата. Сеанс Keycloak обеспечивает повторный
вход во второе приложение без нового LDAP-пароля, мастер-пароль
Vaultwarden открывает зашифрованные данные, а права коллекций
определяют доступ к общим записям.

= Заключение

Выполнен вариант 6. Linux-клиенты подключены к OpenLDAP, Tryton
опубликован через Xpra по SSH с отдельной рабочей станции. Проверено
сохранение сеанса при отключении, разрешённый вход Alice и отказы Bob
в SSH и Tryton. NFS обеспечивает общий доступ к файлам с проверенными
правами. Keycloak объединяет LDAP-аутентификацию и OIDC-вход
в Gitea и Vaultwarden. Для Bob подтверждены чтение Shared, отсутствие
доступа к Private и запрет изменения общей записи.
