#import "@local/mephi-lab:0.1.0": lab-report

#show: lab-report.with(
  lab-number: 6,
  topic: "Централизованная работа пользователей",
  discipline: "Системное администрирование",
  student: "Доценко В. А.",
  group: "Б23-505",
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

Адресация и запланированные роли узлов приведены в таблице @tab-addresses.
Настройка прикладных служб и проверки задания выполняются на следующих этапах.

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

#figure(
  raw(read("outputs/directory-services.txt"), block: true),
  caption: [Поиск пользователей и состояние LDAP/NFS на DIRECTORY],
  kind: raw,
) <lst-directory-services>

== Подключение Linux-клиентов и разграничение файлового доступа

APPS и WORKSTATION подключены к каталогу через SSSD. NSS получает
сведения о пользователях и группах, PAM обеспечивает проверку учётных данных
и создание домашних каталогов. Соединение с каталогом использует LDAPS
с проверкой сертификата по установленному CA (листинг @lst-sssd).

#figure(
  raw(read("configs/sssd.conf"), block: true, lang: "ini"),
  caption: [Конфигурация SSSD на Linux-клиентах],
  kind: raw,
) <lst-sssd>

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

На APPS настроены сервер Tryton, база PostgreSQL sa6 и модуль
ldap_authentication. Приложение проверяет пароль по LDAP самостоятельно.
Для Alice создана учётная запись приложения с правами работы со справочником
Party; автоматическое создание учётных записей отключено. Bob учётной записи
Tryton не имеет.

Итоговая конфигурация сервера приведена в листинге @lst-tryton-config.

#figure(
  raw(read("configs/trytond.conf"), block: true, lang: "ini"),
  caption: [Настройки Tryton, PostgreSQL и модуля LDAP],
  kind: raw,
) <lst-tryton-config>

С WORKSTATION выполнены HTTPS-запросы входа и чтения справочника.
Alice получила HTTP 200 и прочитала запись SA6 Project; вход Bob с действующим
LDAP-паролем отклонён с HTTP 401 (листинг @lst-tryton-auth).
Клиент проверял сертификат HTTPS по системному хранилищу CA и имени узла.

#figure(
  raw(read("outputs/workstation-tryton-auth.txt"), block: true),
  caption: [Проверка входа и чтения данных в Tryton],
  kind: raw,
) <lst-tryton-auth>

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
