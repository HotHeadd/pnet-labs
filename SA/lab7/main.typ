#import "@local/mephi-lab:0.1.0": lab-report, device-config, cli-output

#show: lab-report.with(
  lab-number: 7,
  topic: "Инфраструктура корпоративных коммуникаций: системы обмена сообщениями и видеоконференцсвязи",
  discipline: "Системное администрирование",
  student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."),
  group: "Б23-505",
  teacher: "Басыня Е. А.",
)

= Цель работы

Получить практические навыки развёртывания серверов корпоративных сообщений
и видеоконференцсвязи, публикации через обратный прокси и интеграции с
централизованным каталогом и поставщиком идентификации.

= Задание

Вариант 1: Openfire и Synapse с единым входом. Развернуть независимые XMPP-
и Matrix-сервисы, OpenLDAP, Keycloak, PostgreSQL, LiveKit и клиент LiveKit Meet.
Проверить сообщения и файлы, конференцию трёх участников, демонстрацию экрана,
data-канал, единый вход, TLS и отказы доступа. Сопоставить XMPP и Matrix.

= Ход работы

== Схема и параметры стенда

Предусмотрены внешний сегмент клиентов, DMZ и внутренняя сеть сервисов.
GW публикует сервисы через HTTPS; медиапакеты передаются от клиентов
непосредственно RTC. Управление гостями выполняется с хоста PNETLab по SSH.

Схема выбранного размещения показана на рисунке @fig-topology.

#figure(image("img/topology.svg", width: 100%), caption: [Сегменты и назначение узлов СА7]) <fig-topology>

План ресурсов: GW 2 ГиБ, IM 6 ГиБ, RTC 4 ГиБ, WORKSTATION 3 ГиБ.
Уменьшенные относительно таблицы методички ресурсы IM/RTC требуют
проверки при работе трёх участников. Фактические результаты будут внесены
после развёртывания; выделенная память не является измерением потребления.

== Подготовка виртуальных машин

Для всех узлов выбран официальный cloud-образ Ubuntu Server 24.04 LTS.
Его SHA-256 сверена с SHA256SUMS: #raw("04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94").
Отдельные диски и параметры cloud-init не изменяют общие образы других лаб.
Сессия PNETLab 16 содержит GW, IM, RTC и WORKSTATION.

После загрузки на каждом госте проверены имя, завершение cloud-init,
адреса интерфейсов и SSH. Ожидаются status: done, заданные адреса и active.
Фактические выводы приведены в листингах @lst-gw-platform, @lst-im-platform,
@lst-rtc-platform и @lst-ws-platform.

#cli-output("GW", "hostname; cloud-init status; ip -br -4 addr; systemctl is-active ssh", read("outputs/gw-platform.txt")) <lst-gw-platform>
#cli-output("IM", "hostname; cloud-init status; ip -br -4 addr; systemctl is-active ssh", read("outputs/im-platform.txt")) <lst-im-platform>
#cli-output("RTC", "hostname; cloud-init status; ip -br -4 addr; systemctl is-active ssh", read("outputs/rtc-platform.txt")) <lst-rtc-platform>
#cli-output("WORKSTATION", "hostname; cloud-init status; ip -br -4 addr; systemctl is-active ssh", read("outputs/workstation-platform.txt")) <lst-ws-platform>

Установка прикладных пакетов запущена. Конфигурация и проверки служб ещё не завершены.
