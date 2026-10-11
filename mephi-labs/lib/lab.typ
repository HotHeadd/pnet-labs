// Отчёт по лабораторной: титульник из parprog_typst_mephi,
// остальное оформление — как в отчёте по НИР (modern-g7-32, ГОСТ 7.32-2017).
#import "@preview/modern-g7-32:0.2.0": abstract, appendixes, gost
#import "title-lab.typ": lab-titlepage

#let lab-report(
  // Титульник
  lab-number: none,
  topic: none,
  discipline: none,
  subtitle: auto,
  student: none,
  group: none,
  teacher: none,
  university: [Национальный исследовательский ядерный университет «МИФИ»],
  institute: [Институт интеллектуальных кибернетических систем],
  department: [Кафедра № 42 «Криптология и кибербезопасность»],
  logos: true,
  city: "Москва",
  year: auto,
  // Оформление
  font: "Times New Roman",
  show-outline: true,
  section-pagebreaks: true,
  body,
) = {
  set text(font: font, lang: "ru")

  lab-titlepage(
    lab-number: lab-number,
    topic: topic,
    discipline: discipline,
    subtitle: subtitle,
    student: student,
    group: group,
    teacher: teacher,
    university: university,
    institute: institute,
    department: department,
    logos: logos,
    city: city,
    year: year,
  )

  // Титульник свёрстан отдельно, у gost свой отключаем.
  // Нумерация страниц продолжается: содержание — стр. 2.
  show: gost.with(hide-title: true, add-pagebreaks: section-pagebreaks)

  // Дальше — настройки из отчёта по НИР.
  set text(size: 14pt)
  set enum(numbering: "1)")
  show outline.entry.where(level: 2): set block(above: 1em, below: 1em)
  show outline.entry.where(level: 3): set block(above: 1em, below: 1em)
  show figure.caption: it => text(size: 12pt)[#it]

  // Листинги: код слева, мелким шрифтом, могут переходить на след. страницу.
  show figure.where(kind: raw): set block(breakable: true)
  show raw.where(block: true): set align(left)
  show raw.where(block: true): set text(size: 11pt)
  show raw.where(block: true): set par(justify: false)

  if show-outline { outline() }

  body
}

// Конфигурация устройства как листинг. read() работает относительно файла,
// который его вызывает, поэтому текст читается в самом отчёте:
//   #device-config("R1", read("configs/R1.txt"))
#let device-config(name, body, lang: none) = figure(
  raw(body.trim(), lang: lang, block: true),
  caption: [Конфигурация устройства #name],
  kind: raw,
)

// Вывод команды на устройстве:
//   #cli-output("R1", "show ip route", read("outputs/R1-route.txt"))
#let cli-output(name, cmd, body, size: 9pt) = figure(
  {
    show raw: set text(size: size)
    raw(name + "# " + cmd + "\n" + body.trim(), block: true)
  },
  caption: [Вывод команды #raw(cmd) на #name],
  kind: raw,
)
