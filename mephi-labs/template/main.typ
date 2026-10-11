#import "@local/mephi-lab:0.1.0": lab-report, appendixes, device-config, cli-output

#show: lab-report.with(
  lab-number: 1,
  topic: "Тема лабораторной работы",
  discipline: "Безопасность компьютерных сетей",
  student: "Доценко В. А.",
  group: "Б23-505",
  teacher: "Фамилия И. О.",
  // student: ("Доценко В. А.", "Дзюба С. Д."),  // несколько → «Выполнили:»
  // show-outline: false,
  // section-pagebreaks: false,
)

= Цель работы

Текст цели работы.

= Задание

+ первый пункт задания;
+ второй пункт задания.

= Ход работы

== Топология сети

Схема сети приведена на рисунке @fig-topology.

#figure(
  rect(width: 100%, height: 5cm)[Здесь будет #raw("img/topology.png")],
  // image("img/topology.png", width: 100%),
  caption: [Топология сети],
  kind: image,
) <fig-topology>

== Настройка устройств

Конфигурация маршрутизатора R1 приведена в листинге @lst-r1.

#device-config("R1", read("configs/R1.txt")) <lst-r1>

== Проверка работоспособности

#cli-output("R1", "show ip interface brief", read("outputs/R1-ip-brief.txt")) <lst-r1-brief>

= Заключение

Выводы по работе.
