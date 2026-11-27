#import "@local/mephi-lab:0.1.0": lab-report

#show: lab-report.with(
  lab-number: 6,
  topic: "Централизованная работа пользователей",
  discipline: "Системное администрирование",
  student: "Доценко В. А.",
  group: "Б23-505",
  teacher: "Басыня Е. А.",
  section-pagebreaks: false,
)

= Цель работы

Приобрести практические навыки централизованного доступа пользователей
к приложениям и сетевым ресурсам, настройки каталогов, аутентификации
и разграничения доступа.

= Задание

Вариант 6: развернуть OpenLDAP, Linux-сервер с Xpra и графическим
приложением; обеспечить вход через каталог, публикацию приложения
в режиме seamless по SSH и повторное подключение к сохраняемому сеансу.
Настроить NFS и файловые права, LDAP-федерацию Keycloak и OIDC-вход
в Vaultwarden и отдельное веб-приложение; показать SSO и проверки доступа.

= Ход работы

== Подготовка виртуальных машин

В PNETLab создана лаборатория SA6. Для узлов подготовлены отдельные
диски на основе Ubuntu Server 22.04 и начальные настройки cloud-init.
Команды подготовки приведены в листинге @lst-platform.

#block(breakable: false)[
#figure(
  raw(read("commands/prepare-platform.txt"), block: true, lang: "sh"),
  caption: [Подготовка дисков и создание топологии],
  kind: raw,
) <lst-platform>
]

Рабочие интерфейсы объединены сетью 10.60.0.0/24. Вторые интерфейсы
подключаются к служебной сети pnet0 для установки пакетов и администрирования.

#figure(
  table(
    columns: (1.2fr, 1.5fr, 2fr),
    inset: 6pt,
    table.header([*Узел*], [*Рабочий адрес*], [*Назначение*]),
    [DIRECTORY], [10.60.0.10/24], [Каталог пользователей, NFS],
    [APPS], [10.60.0.20/24], [Сервер Xpra и приложение],
    [WEB], [10.60.0.30/24], [Keycloak, Vaultwarden, Gitea],
    [WORKSTATION], [10.60.0.100/24], [Xpra-клиент и браузер],
  ),
  caption: [Адресация и назначение узлов],
) <tab-addresses>

Адресация и роли узлов приведены в таблице @tab-addresses,
схема инфраструктуры — на рисунке @fig-topology.

#figure(
  image("img/topology.svg", width: 100%),
  caption: [Инфраструктура централизованного доступа],
) <fig-topology>

Все четыре узла используют Ubuntu Server 22.04.5. Версии пакетов DIRECTORY
и APPS и компонентов WEB приведены в листинге @lst-versions.
В WEB используются Keycloak 26.8.2, Vaultwarden 1.37.5 и Gitea 28.4.0.

#figure(
  raw(read("outputs/directory-versions.txt") + "\n"
    + read("outputs/apps-versions.txt") + "\n"
    + read("outputs/web-versions.txt"), block: true),
  caption: [Версии программного обеспечения],
  kind: raw,
) <lst-versions>

== Проверка базовой сети

На DIRECTORY проверены завершение cloud-init, адреса интерфейсов,
маршруты, доступное место и состояние SSH (листинг @lst-directory-platform).
Аналогичные проверки выполнены на остальных трёх узлах.

#figure(
  raw(read("outputs/directory-platform.txt"), block: true),
  caption: [Проверка начального состояния DIRECTORY],
  kind: raw,
) <lst-directory-platform>

С WORKSTATION выполнены команды #raw("ping -c 2 -W 2") к каждому
из трёх серверов по рабочим адресам. Каждый узел вернул два ответа
без потерь (листинг @lst-platform-network).

#figure(
  raw(read("outputs/workstation-network.txt"), block: true),
  caption: [Проверка связи рабочей станции с серверами],
  kind: raw,
) <lst-platform-network>

== Каталог пользователей и файловый ресурс

На DIRECTORY настроен каталог OpenLDAP с базой #raw("dc=sa6,dc=test").
Пользователи Alice и Bob имеют POSIX-атрибуты UID/GID для согласования
учётных записей Linux и файловых прав. Группы employees и guests
разделяют права на документы, xpra-users предназначена для доступа к приложениям.
Для LDAP выпущен серверный сертификат собственного CA и включён LDAPS.

Настройка выполнена командами из листинга @lst-configure-directory.

#figure(
  raw("python3 SA/lab6/tools/run.py directory --file SA/lab6/commands/configure-directory.sh --background", block: true, lang: "sh"),
  caption: [Применение конфигурации каталога и NFS],
  kind: raw,
) <lst-configure-directory>

Каталог #raw("/srv/nfs/team") экспортирован по NFS для APPS и WORKSTATION.
Его владелец имеет UID 10001, группа имеет GID 10000; доступ остальных
пользователей запрещён. Используются setgid, наследуемые ACL и root_squash.
При #raw("sec=sys") сервер доверяет UID/GID клиентов; аутентификацию
пользователей с помощью Kerberos данная настройка не выполняет.

Поиск пользователей по LDAPS и параметры экспорта проверены
в листинге @lst-directory-services. Клиентские проверки доступа выполняются отдельно.

#block(breakable: false)[
#figure(
  raw(read("outputs/directory-services.txt"), block: true),
  caption: [Поиск пользователей и состояние LDAP/NFS на DIRECTORY],
  kind: raw,
) <lst-directory-services>
]

== Подключение Linux-клиентов и разграничение файлового доступа

APPS и WORKSTATION подключены к каталогу через SSSD. NSS получает
сведения о пользователях и группах, PAM обеспечивает проверку учётных данных
и создание домашних каталогов. Соединение с каталогом использует LDAPS
с проверкой сертификата по установленному CA (листинг @lst-sssd).

#block(breakable: false)[
#figure(
  raw(read("configs/sssd.conf"), block: true, lang: "ini"),
  caption: [Конфигурация SSSD на Linux-клиентах],
  kind: raw,
) <lst-sssd>
]

На обоих узлах пользователи имеют одинаковые UID/GID, а ресурс смонтирован
в #raw("/mnt/team"). Результаты APPS приведены в листинге @lst-apps-ldap-nfs,
WORKSTATION — в листинге @lst-workstation-ldap-nfs.

#figure(
  raw(read("outputs/apps-ldap-nfs.txt"), block: true),
  caption: [Проверка LDAP-идентичностей и монтирования NFS на APPS],
  kind: raw,
) <lst-apps-ldap-nfs>

#figure(
  raw(read("outputs/workstation-ldap-nfs.txt"), block: true),
  caption: [Проверка LDAP-идентичностей и монтирования NFS на WORKSTATION],
  kind: raw,
) <lst-workstation-ldap-nfs>

Alice создала документ на WORKSTATION и дополнила его с APPS. Оба клиента
увидели общее содержимое; владельцем файла является Alice, группой — employees,
права — 660 (листинг @lst-nfs-shared-write).

#figure(
  raw(read("outputs/apps-nfs-write.txt"), block: true),
  caption: [Запись в общий файл с другого клиента NFS],
  kind: raw,
) <lst-nfs-shared-write>

Bob не входит в employees и получает отказ при чтении. Проверка от имени
root клиента также завершается отказом: NFS применяет root_squash.
В листинге @lst-nfs-rights приведены выводы чтения и коды завершения:
#raw("bob_exit=1") и #raw("root_exit=1"); перед проверкой root показан UID 0.

#figure(
  raw(read("outputs/workstation-nfs-rights.txt"), block: true),
  caption: [Положительная и отрицательные проверки доступа к общему файлу],
  kind: raw,
) <lst-nfs-rights>

Те же проверки выполнены в терминале рабочей станции
(рисунок @fig-nfs-rights).

#figure(
  image("img/nfs-rights.png", width: 100%),
  caption: [Чтение файла Alice и отказы Bob и root клиента NFS],
) <fig-nfs-rights>

== Правила SSH-доступа к серверу приложений

На APPS включены PAM и парольный вход, разрешены группы xpra-users
и sudo (листинг @lst-apps-ssh-config). Служебная учётная запись labadmin
используется для администрирования; пользовательский доступ регулируется
группами каталога. Для служебных консолей ВМ включён вход labadmin через
авторизованную сессию PNETLab; он не является проверкой LDAP-аутентификации.

#block(breakable: false)[
#figure(
  raw(read("configs/ssh-apps.conf"), block: true),
  caption: [Правила SSH-доступа на APPS],
  kind: raw,
) <lst-apps-ssh-config>
]

С отдельной WORKSTATION проверены пароли обоих пользователей LDAP,
затем SSH-вход на APPS с принудительным методом password и отключённым
PubkeyAuthentication. Alice успешно выполнила #raw("id") на сервере;
Bob, чей пароль принят каталогом, получил отказ SSH
(листинг @lst-ssh-auth).

#figure(
  raw(read("outputs/workstation-ssh-auth.txt"), block: true),
  caption: [Проверка LDAP-паролей и SSH-доступа с рабочей станции],
  kind: raw,
) <lst-ssh-auth>

Журнал sshd подтверждает успешную парольную аутентификацию Alice
и отклонение Bob именно по AllowGroups (листинг @lst-ssh-auth-log).

#figure(
  raw(read("outputs/apps-ssh-auth-log.txt"), block: true),
  caption: [Причина отказа Bob в журнале сервера приложений],
  kind: raw,
) <lst-ssh-auth-log>

== Графическая рабочая станция

На WORKSTATION установлены XFCE, LightDM, клиент Xpra и браузер.
Для служебной учётной записи labadmin настроен автоматический запуск XFCE.
LightDM активен, процесс графического сеанса запущен
(листинг @lst-workstation-gui).

#figure(
  raw(read("outputs/workstation-gui.txt"), block: true),
  caption: [Настройка и запуск графического сеанса WORKSTATION],
  kind: raw,
) <lst-workstation-gui>

== Прикладная аутентификация Tryton

Использована трёхзвенная архитектура: Tryton Desktop Client обращается
к серверу Tryton по HTTPS, сервер выполняет прикладную логику и работает
с PostgreSQL через локальный Unix-сокет. В режиме Xpra клиент приложения
также выполняется на APPS, а WORKSTATION получает его окна по SSH.

На APPS настроены сервер Tryton, база PostgreSQL sa6 и модуль
ldap_authentication. Приложение проверяет пароль по LDAP самостоятельно.
Для Alice создана учётная запись приложения с правами работы со справочником
Party; автоматическое создание учётных записей отключено. Bob учётной записи
Tryton не имеет.

Итоговая конфигурация сервера приведена в листинге @lst-tryton-config.

#block(breakable: false)[
#figure(
  raw(read("configs/trytond.conf"), block: true, lang: "ini"),
  caption: [Настройки Tryton, PostgreSQL и модуля LDAP],
  kind: raw,
) <lst-tryton-config>
]

С WORKSTATION выполнены HTTPS-запросы входа и чтения справочника.
Alice получила HTTP 200 и прочитала запись SA6 Project; вход Bob с действующим
LDAP-паролем отклонён с HTTP 401 (листинг @lst-tryton-auth).
Клиент проверял сертификат HTTPS по системному хранилищу CA и имени узла.

#figure(
  raw(read("outputs/workstation-tryton-auth.txt"), block: true),
  caption: [Проверка входа и чтения данных в Tryton],
  kind: raw,
) <lst-tryton-auth>

== Публикация приложения и повторное подключение Xpra

Tryton Desktop Client выполняется на APPS от имени Alice в сеансе Xpra
#raw(":100"). WORKSTATION подключается по SSH с отдельным ключом Alice.
Публикуется окно приложения, рабочий стол APPS не запускается.

После входа Alice открыт справочник Party с записью SA6 Project
(рисунок @fig-xpra-tryton). Панель XFCE принадлежит WORKSTATION;
сам Tryton выполняется на APPS.

#figure(
  image("img/xpra-tryton.png", width: 100%),
  caption: [Окно Tryton, опубликованное через Xpra],
) <fig-xpra-tryton>

Клиент отключён и повторно запущен. Между подключениями сервер сохранил UUID
сеанса, PID Xpra и PID авторизованного процесса Tryton; число клиентов
изменилось с 1 на 0 и снова на 1 (листинг @lst-xpra-reconnect).

#figure(
  raw(read("outputs/xpra-reconnect.txt"), block: true),
  caption: [Отключение и возврат в тот же сеанс приложения],
  kind: raw,
) <lst-xpra-reconnect>

== Сервисы веб-доступа

На WEB запущены контейнеры PostgreSQL, Keycloak, Vaultwarden и Gitea
(листинг @lst-web-containers). Nginx завершает TLS и передаёт запросы
в контейнеры через порты, привязанные к loopback-интерфейсу.

#figure(
  raw(read("outputs/web-containers.txt"), block: true),
  caption: [Запущенные контейнеры WEB],
  kind: raw,
) <lst-web-containers>

С WORKSTATION проверены HTTPS-адреса трёх веб-сервисов. Системное хранилище
CA содержит сертификат лабораторного центра; проверка имени и цепочки
сертификата не отключалась (листинг @lst-web-https).

#figure(
  raw(read("outputs/workstation-web-https.txt"), block: true),
  caption: [Доступность веб-сервисов по HTTPS с рабочей станции],
  kind: raw,
) <lst-web-https>

== Федерация каталога и единый вход

Keycloak использует OpenLDAP как источник пользователей в режиме READ_ONLY.
Созданы два конфиденциальных OIDC-клиента с Authorization Code flow:
Gitea и Vaultwarden. Проверены адреса обратного вызова и принадлежность
Alice и Bob к LDAP-федерации (листинг @lst-keycloak-sso).

Настройки LDAP и список клиентов в административном интерфейсе Keycloak
показаны на рисунках @fig-keycloak-ldap, @fig-keycloak-search
и @fig-keycloak-clients.

#figure(
  image("img/keycloak-ldap.png", width: 100%),
  caption: [LDAP-провайдер sa6-ldap и подключение к каталогу],
) <fig-keycloak-ldap>

#figure(
  image("img/keycloak-ldap-search.png", width: 100%),
  caption: [Режим READ_ONLY и параметры поиска LDAP-пользователей],
) <fig-keycloak-search>

#figure(
  image("img/keycloak-clients.png", width: 100%),
  caption: [OIDC-клиенты Gitea и Vaultwarden в realm sa6],
) <fig-keycloak-clients>

Alice выполнила вход в Gitea через Keycloak, затем вошла в Vaultwarden
без повторного ввода LDAP-пароля. В событиях Keycloak оба клиента связаны
с одним сеансом пользователя. Мастер-пароль Vaultwarden используется
отдельно для разблокировки зашифрованных данных (листинг @lst-browser-sso).

#figure(
  raw(read("outputs/keycloak-sso.txt"), block: true),
  caption: [Федерация, OIDC-клиенты и общий сеанс SSO],
  kind: raw,
) <lst-keycloak-sso>

#block(breakable: false)[
#figure(
  raw(read("outputs/browser-sso.txt"), block: true),
  caption: [Браузерная проверка входа во второе приложение],
  kind: raw,
) <lst-browser-sso>
]

Результаты последовательных входов приведены на рисунках
@fig-sso-gitea и @fig-sso-vaultwarden.

#figure(
  image("img/sso-gitea.png", width: 100%),
  caption: [Первое приложение: Gitea, пользователь Alice],
) <fig-sso-gitea>

#figure(
  image("img/sso-vaultwarden.png", width: 100%),
  caption: [Второе приложение: Vaultwarden после SSO и разблокировки],
) <fig-sso-vaultwarden>

== Права коллекций Vaultwarden

В организации SA6 Team Alice имеет роль Owner. Bob добавлен с ролью User
и правом View items только для коллекции Shared; коллекция Private ему
не назначена. В коллекциях находятся демонстрационные записи, не используемые
для входа в службы.

Из отдельного браузерного сеанса Bob проверены чтение общей записи,
отказ чтения закрытой записи и отказ изменения общей записи
(листинг @lst-vault-rights). В PUT передано прежнее зашифрованное содержимое;
сервер отклонил запрос по правам, версия записи сохранилась.

#figure(
  raw(read("outputs/vaultwarden-rights.txt"), block: true),
  caption: [Проверка прав Bob на сервере Vaultwarden],
  kind: raw,
) <lst-vault-rights>

Назначение Shared участнику Bob показано на рисунке @fig-vault-members.
В его хранилище видна только общая запись (рисунок @fig-vault-bob),
тогда как Alice видит обе коллекции.

#figure(
  image("img/vault-members.png", width: 100%),
  caption: [Роли и назначение коллекции участникам SA6 Team],
) <fig-vault-members>

#figure(
  image("img/vault-bob-shared.png", width: 100%),
  caption: [Хранилище Bob: доступна только коллекция Shared],
) <fig-vault-bob>

== Разделение аутентификации и авторизации

При парольном входе Linux sshd передаёт проверку PAM и SSSD, а AllowGroups
ограничивает доступ к APPS. Для соединения Xpra применён SSH-ключ Alice;
прикладной вход в Tryton выполняется отдельно по LDAP и требует учётной
записи приложения. Наличие пользователя в каталоге само по себе не даёт
доступа к Tryton, что показано отказом Bob.

В веб-приложениях Keycloak проверяет LDAP-пароль и возвращает клиенту
код авторизации. Клиент обменивает код на токены; зарегистрированный
Redirect URI определяет разрешённый адрес возврата. Сеанс Keycloak
обеспечивает повторный вход во второе приложение без нового LDAP-пароля.
Мастер-пароль Vaultwarden отдельно разблокирует зашифрованное хранилище,
а роли организации и права коллекций определяют доступ к общим записям.

Файловые права NFS проверяются по согласованным UID/GID. В этом варианте
использован sec=sys с root_squash; поэтому проверка относится к доверенным
клиентским машинам и не подтверждает криптографическую аутентификацию NFS.

= Заключение

Выполнен вариант 6: пользователи Linux подключены к OpenLDAP, окно Tryton
опубликовано через Xpra по SSH с отдельной рабочей станции. После отключения
клиента сохранены сеанс и авторизованный процесс приложения. Проверены
разрешённый вход Alice, отказы Bob в SSH и Tryton, файловые права NFS,
LDAP-федерация Keycloak и единый вход в Gitea и Vaultwarden. Для Bob
подтверждены чтение Shared, отказ доступа к Private и запрет изменения
общей записи на сервере Vaultwarden.

#block(breakable: false)[
= Источники

+ Лабораторная работа №6 (СА). «Централизованная работа пользователей»,
  вариант 6 и требования к отчёту.
+ #link("https://www.openldap.org/doc/admin25/")[OpenLDAP 2.5 Administrator’s Guide].
+ #link("https://manpages.ubuntu.com/manpages/jammy/man5/sssd-ldap.5.html")[SSSD LDAP provider, Ubuntu 22.04].
+ #link("https://docs.tryton.org/6.0/server/topics/configuration.html")[Tryton 6.0: Server configuration].
+ #link("https://manpages.ubuntu.com/manpages/jammy/man1/xpra.1.html")[Xpra 3.1: руководство по командам].
+ #link("https://www.keycloak.org/docs/latest/server_admin/index.html")[Keycloak: Server Administration Guide].
+ #link("https://github.com/dani-garcia/vaultwarden/wiki/Enabling-SSO-support-using-OpenId-Connect")[Vaultwarden: OpenID Connect SSO].
+ #link("https://docs.gitea.com/administration/authentication/")[Gitea: Authentication].
]
