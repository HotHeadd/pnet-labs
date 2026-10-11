#let lab-titlepage(
  lab-number: none,
  topic: none,
  discipline: none,
  // Заголовок под «ОТЧЕТ»; auto — «О выполнении лабораторной работы № N»
  subtitle: auto,
  // Строка или массив строк (несколько исполнителей → «Выполнили:»)
  student: none,
  group: none,
  teacher: none,
  university: [Национальный исследовательский ядерный университет «МИФИ»],
  institute: [Институт интеллектуальных кибернетических систем],
  department: [Кафедра № 42 «Криптология и кибербезопасность»],
  logos: true,
  city: "Москва",
  year: auto,
) = {
  if year == auto { year = datetime.today().year() }
  if subtitle == auto {
    subtitle = [О выполнении лабораторной работы № #lab-number]
  }
  let students = if type(student) == array { student } else { (student,) }
  let students = students.filter(s => s != none)

  page(margin: 2cm, numbering: none, header: none, footer: none)[
    #set text(size: 12pt)
    #set par(first-line-indent: 0pt, justify: false)

    #align(center)[
      #text(size: 13pt, university)
      #v(0.25cm)
      #if institute != none [
        #text(size: 13pt, institute)
        #v(0.25cm)
      ]
      #text(size: 13pt, department)
      #v(1cm)

      #if logos {
        grid(
          columns: 3,
          gutter: 17mm,
          image("assets/logo_university.jpg", width: 5cm),
          image("assets/logo_institute.png", width: 5cm),
          image("assets/kaf42.png", width: 5cm),
        )
      }

      #v(16mm)
      #text(size: 26pt, weight: "bold")[ОТЧЕТ]
      #v(3mm)
      #text(size: 13pt, weight: "bold")[
        #subtitle
        #if topic != none [\ «#topic»]
        #if discipline != none [\ по дисциплине «#discipline»]
      ]

      #v(1fr)

      #align(right)[
        #if students.len() > 0 [
          #text(weight: "bold")[#if students.len() > 1 [Выполнили:] else [Студент:]]
          #students.join(", ") \
        ]
        #if group != none [#text(weight: "bold")[Группа:] #group \ ]
        #if teacher != none [#text(weight: "bold")[Преподаватель:] #teacher]
      ]

      #v(0.5cm)
      #city — #year
    ]
  ]
}
