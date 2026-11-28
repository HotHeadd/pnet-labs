#import "@local/mephi-lab:0.1.0": lab-report
#show: lab-report.with(
  lab-number: 6,
  topic: "Инструменты пассивного и активного анализа сетевого трафика и информационных систем",
  discipline: "Безопасность компьютерных сетей",
  student: ("Доценко В. А.", "Дзюба С. Д.", "Мартюшев В. А.", "Горячев М. А."),
  group: "Б23-505",
  teacher: "Басыня Е. А.",
  section-pagebreaks: false,
)

#let listing(caption, body) = figure(
  { set text(size: 8pt); raw(body.trim(), block: true) },
  caption: caption,
  kind: raw,
)
#let shot(file, caption, ratio: none, width: 100%) = figure(
  block(width: width)[#layout(size => {
    let full-ratio = if file.ends-with("-rtt.png") or file.ends-with("-throughput.png") { 760 / 960 } else { 950 / 1440 }
    let picture = if ratio == none { image("img/" + file, width: size.width) } else {
      image("img/" + file, width: size.width, height: size.width * full-ratio, fit: "contain")
    }
    if ratio == none { picture } else {
      block(width: size.width, height: size.width * ratio, clip: true, above: 0pt, below: 0pt, place(top + left, picture))
    }
  })],
  caption: caption,
)

= Цель работы
Исследовать сетевой обмен при передаче файлов по FTP и SFTP, сопоставить состояния портов по Nmap с записанными пакетами и измерить влияние задержки и потерь на передачу по TCP.

= Стенд и методика
Две ВМ Ubuntu Server 22.04 в PNETLab соединены через внутренний мост BKS6-ISOLATED. У клиента и сервера есть только маршрут в общую подсеть. На сервере развёрнуты vsftpd и OpenSSH. Для диагностики портов временно запущены HTTP на TCP 8080 и учебный DNS на UDP 53. Схема приведена на рисунке @topology.

#figure(image("img/topology.svg", width: 100%), caption: [Схема стенда BKS6 в PNETLab]) <topology>

Захват выполнен с помощью `tcpdump` на интерфейсе `ens3` клиента. Адресный фильтр ограничивает запись обменом между двумя ВМ. В опытах FTP, SFTP и Nmap использовался захват полной длины. Для передач файла 64 МиБ добавлен фильтр `tcp port 22` и установлена длина захвата 128 байт. Этого достаточно для анализа заголовков TCP и расчёта скорости по длинам сегментов. Команда захвата приведена в листинге @capture-cmd.

#listing([Захват трафика FTP], "sudo tcpdump -i ens3 -nn -U -s 0 -w ftp.pcap \\" + "\n  'host 192.168.106.20 and host 192.168.106.10'") <capture-cmd>

= Анализ FTP и SFTP
Один и тот же 51-байтный файл скачан с сервера по FTP в двоичном режиме и по SFTP. Для FTP использовалась отдельная учебная учётная запись. Пароль передаётся открытым текстом в команде `PASS`, поэтому этот кадр исключён из снимка фильтром Wireshark, а пароль после записи сменён. В листинге @capture-result приведены счётчики захвата. Нулевой счётчик `dropped by kernel` относится к захвату на клиенте.

#listing([Счётчики tcpdump для FTP и SFTP], ("ftp.pcap", "sftp.pcap").map(name => {
  let log = read("outputs/" + name.replace(".pcap", ".tcpdump.txt")).trim().split("\n")
  name + "\n" + log.slice(-3).join("\n")
}).join("\n")) <capture-result>

Управляющий обмен на TCP 21 показан на рисунке @ftp-control. В ответ на `EPSV` сервер вернул код `229` и порт 41007. Клиент сам открыл отдельное TCP-соединение к этому порту. Команда `TYPE I` задала двоичный режим, `RETR control.txt` запустила скачивание, а ответ `226` подтвердил завершение передачи.

#shot("ftp-control.png", [Управляющее соединение FTP], ratio: 0.282) <ftp-control>

На рисунке @ftp-follow виден поток `tcp.stream eq 1`. В кадре 26 сервер передал все 51 байт файла с порта 41007. Файл сохранён через Follow TCP Stream в режиме Raw. SHA-256 исходного файла, обеих копий и файла из дампа совпал (листинг @transfer-hashes).

#shot("ftp-follow.png", [Содержимое файла в отдельном TCP-потоке FTP]) <ftp-follow>

#let control-hash = read("outputs/ftp-restored-sha256.txt").split(" ").first()
#listing([Общий SHA-256 исходного и трёх проверенных файлов], control-hash + "\nИсходник: control.txt\nКопии: control-ftp.txt, control-sftp.txt, control-restored.txt") <transfer-hashes>

На рисунке @sftp видны строки идентификации OpenSSH, согласование ключей и сообщения New Keys. Последующие запросы SFTP, имя файла и его содержимое защищены шифрованием SSH. По заголовкам TCP/IP и меткам захвата видны адреса, порты, направления, размеры пакетов и длительность сеанса.

#shot("sftp.png", [Установление защищённого SSH-соединения для SFTP], ratio: 0.224) <sftp>

В листинге @transfer-frames приведены поля выбранных кадров из обоих дампов. В SFTP после сообщения `New Keys` декодер помечает пакеты как `Encrypted packet`. Для этих кадров по-прежнему известны адреса, порты, время и длина.

#block(breakable: false)[
#listing([Поля кадров из дампов FTP и SFTP], "ftp.pcap\n" +
  "16  0.050996 s  192.168.106.20:21 -> 192.168.106.10:49168  114 B\n" +
  "26  0.053464 s  192.168.106.20:41007 -> 192.168.106.10:33370  117 B\n" +
  "    FTP Data: 51 bytes\n" +
  "sftp.pcap\n" +
  "4   0.004574 s  192.168.106.10:55892 -> 192.168.106.20:22  108 B\n" +
  "12  0.034631 s  192.168.106.10:55892 -> 192.168.106.20:22  82 B\n" +
  "    Client: New Keys\n" +
  "14  0.077464 s  192.168.106.10:55892 -> 192.168.106.20:22  110 B\n" +
  "    Client: Encrypted packet (len=44)") <transfer-frames>
]

В таблице @ftp-sftp-comparison сопоставлены сведения, полученные из двух дампов.

#block(breakable: false)[
#set par(justify: false)
#figure(table(
  columns: (.95fr, 1.5fr, 1.55fr),
  align: left,
  table.header([Сведения], [FTP], [SFTP]),
  [Адреса, порты, время и длины],
  [Видны в кадрах управления и данных. Порты сервера 21 и 41007 (листинг @transfer-frames).],
  [Видны до и после смены ключей. Порт сервера 22 (листинг @transfer-frames).],
  [Начало обмена],
  [Виден ответ сервера `220` (рисунок @ftp-control).],
  [Видны строки OpenSSH и согласование ключей (рисунок @sftp).],
  [Команда и имя файла],
  [Видна команда `RETR control.txt` (рисунок @ftp-control).],
  [После `New Keys` декодер показывает зашифрованные пакеты (листинг @transfer-frames). Команда и имя файла в дампе не читаются.],
  [Содержимое файла],
  [Все 51 байт восстановлены из потока данных. SHA-256 совпал (рисунок @ftp-follow, листинг @transfer-hashes).],
  [Содержимое защищено шифрованием SSH (листинг @transfer-frames). SHA-256 проверен по скачанной копии (листинг @transfer-hashes).],
), caption: [Сравнение сведений, доступных в дампах FTP и SFTP]) <ftp-sftp-comparison>
]

= Диагностика портов
Временный HTTP-сервис запущен на TCP 8080, TCP 8081 оставлен без службы. DNS слушал UDP 53, UDP 5300 оставлен без службы. Для TCP 8080 проверены исходное состояние и два правила для адреса клиента. Правило `REJECT --reject-with tcp-reset` возвращало RST, а `DROP` отбрасывало запрос. `ss -lntu` подтверждал, что HTTP продолжал слушать TCP 8080 при обоих правилах.

Команды исходного прогона приведены в листинге @nmap-cmd. После изменения правил команды TCP повторены с тем же набором портов. Дополнительные проверки UDP выполнены для порта 5300.

#listing([Команды Nmap для исходного состояния], "nmap -n -Pn -sT -p 21,22,8080,8081 192.168.106.20\nsudo nmap -n -Pn -sS -p 21,22,8080,8081 192.168.106.20\nsudo nmap -n -Pn -sU -p 53,5300 192.168.106.20") <nmap-cmd>

#listing([Сокет TCP 8080 и активное правило сервера], ("reject", "drop").map(mode => {
  let lines = read("outputs/server-scan-" + mode + ".txt").split("\n")
  mode + "\n" + lines.filter(line =>
    (line.starts-with("tcp") and line.contains("192.168.106.20:8080")) or
    line.starts-with("-A BKS6SCAN")).map(line => line.trim()).join("\n")
}).join("\n")) <tcp-server-state>

В таблице @tcp-results сопоставлены результаты двух способов TCP-сканирования и ответы в дампах.

#block(breakable: false)[
#set par(justify: false)
#figure(table(
  columns: (1.15fr, .85fr, .8fr, 2fr),
  table.header([Порт и условие], [Connect], [SYN], [Наблюдение]),
  [21, 22, 8080 без правила], [open], [open], [SYN/ACK от сервера],
  [8081 без службы], [closed], [closed], [RST/ACK от сервера],
  [8080 с REJECT], [closed], [closed], [RST/ACK при работающей службе],
  [8080 с DROP], [filtered], [filtered], [На SYN не пришло ответа],
), caption: [Состояния портов при TCP Connect- и SYN-сканировании]) <tcp-results>
]

В исходном захвате TCP Connect завершил рукопожатие пакетом ACK (кадры 1, 5 и 9), затем закрыл соединение пакетом RST/ACK. При SYN-сканировании после SYN/ACK клиент отправил RST без завершения рукопожатия (кадры 17, 21 и 25). Эти последовательности показаны на рисунке @tcp-initial. От порта 8081 без службы пришли RST/ACK в кадрах 8 и 24. При REJECT порт 8080 также ответил RST/ACK (рисунок @tcp-reject), хотя сокет оставался в LISTEN (листинг @tcp-server-state). При DROP два метода вместе отправили четыре SYN, на которые за время наблюдения ответа не было (рисунок @tcp-drop).

#shot("scan-tcp-initial.png", [Два способа проверки открытого TCP 8080], ratio: 0.175) <tcp-initial>
#shot("scan-tcp-reject.png", [Ответы RST/ACK при REJECT на TCP 8080], ratio: 0.15) <tcp-reject>
#shot("scan-tcp-drop.png", [Исходящие SYN без ответов при DROP на TCP 8080], ratio: 0.15) <tcp-drop>

UDP 53 ответил сообщением DNS с кодом `Not implemented`. Прикладного ответа достаточно для определения порта как `open`. Для UDP 5300 сервер вернул ICMP Port Unreachable (тип 3, код 3). Правило `REJECT --reject-with icmp-admin-prohibited` заменило ответ на ICMP 3/13. При `DROP` ответ исчез, поэтому Nmap указал `open|filtered`: по отсутствию ответа нельзя отличить фильтрацию от открытого порта со службой, которая не отвечает на пробу. Наблюдения показаны на рисунках @udp-initial, @udp-filtered и @udp-drop.

В таблице @udp-results ответ каждого порта сопоставлен с состоянием, которое указал Nmap.

#block(breakable: false)[
#set par(justify: false)
#figure(table(
  columns: (1.25fr, 1fr, 2fr),
  table.header([Порт и условие], [Nmap], [Ответ сервера]),
  [53 с DNS], [open], [Ответ UDP от службы DNS],
  [5300 без службы], [closed], [ICMP 3/3 Port Unreachable],
  [5300 с REJECT], [filtered], [ICMP 3/13 Administratively Filtered],
  [5300 с DROP], [open|filtered], [Ответа на два запроса нет],
), caption: [Состояния портов при UDP-сканировании]) <udp-results>
]

#shot("scan-udp-initial.png", [Ответ DNS и ICMP Port Unreachable], ratio: 0.15) <udp-initial>
#shot("scan-udp-filtered.png", [ICMP 3/13 при явном запрете UDP 5300], ratio: 0.15) <udp-filtered>
#shot("scan-udp-open-filtered.png", [Два запроса UDP 5300 без ответов], ratio: 0.15) <udp-drop>

В листинге @nmap-result приведены строки из сохранённых запусков Nmap для портов, на которые действовали тестовые правила.

#let scan-line(file, port) = read("outputs/scan-" + file + ".txt").split("\n").find(line => line.starts-with(port + " "))
#block(breakable: false)[
#listing([Состояния TCP 8080 и UDP 5300 в выводе Nmap], (
  ("initial", "reject", "drop").map(mode => mode + " (-sT)  " + scan-line("connect-" + mode, "8080/tcp")),
  ("initial", "reject", "drop").map(mode => mode + " (-sS)  " + scan-line("syn-" + mode, "8080/tcp")),
  ("udp", "udp-reject", "udp-drop").map(file => file + " (-sU)  " + scan-line(file, "5300/udp")),
).flatten().join("\n")) <nmap-result>
]

После опытов `iptables -S INPUT` снова содержал только `-P INPUT ACCEPT`. В списке сокетов исчезли TCP 8080 и тестовый DNS на `192.168.106.20:53`. DNS на `127.0.0.53:53` остался доступен только на loopback. Сокеты FTP и SSH остались в состоянии LISTEN, как видно в листинге @firewall-restored. Доступ с клиента по SFTP отдельно подтверждён следующей серией передач (листинг @performance-hash).

#block(breakable: false)[
#let cleanup-lines = read("outputs/server-udp-cleanup.txt").split("\n")
#let sockets = cleanup-lines.filter(line => line.starts-with("tcp") or line.starts-with("udp")).map(line => {
  let fields = line.split(regex("\\s+"))
  (fields.at(0), fields.at(1), fields.at(4)).join("  ")
})
#listing([Локальные сокеты и политика INPUT после испытаний], ("Netid  State  Local Address:Port", ..sockets, cleanup-lines.find(line => line.starts-with("-P INPUT"))).join("\n")) <firewall-restored>
]

= Влияние задержки и потерь
Один случайный файл размером 67 108 864 байта передан с клиента на сервер по SFTP девять раз. Во всех повторах использована команда `sftp` с пакетным заданием `put`. Время измерено от запуска до завершения команды через `/usr/bin/time -f '%e'` и включает установление SSH-соединения. Для первой передачи каждого режима сохранён отдельный PCAP. Задержка и потери применялись только к исходящему трафику `ens3` клиента, по отдельности. Команды и фактические состояния очереди приведены в листингах @netem и @qdisc-states.

#listing([Исходное состояние очереди, применение и снятие netem], "tc qdisc show dev ens3\nsudo tc qdisc replace dev ens3 root netem delay 50ms\nsudo tc qdisc replace dev ens3 root netem loss 1%\nsudo tc qdisc del dev ens3 root\ntc qdisc show dev ens3") <netem>

#listing([Фактические состояния очереди перед каждой серией], ("before", "delay", "loss").map(mode => read("outputs/qdisc-" + mode + ".txt").split("\n").first().trim()).join("\n")) <qdisc-states>

В таблице @transfer-results полезная скорость рассчитана как 64 МиБ, делённые на медиану времени. Если разделить общий объём 192 МиБ на суммарное время трёх передач, получаются 37,94 МиБ/с в исходном режиме, 15,34 МиБ/с с задержкой и 45,61 МиБ/с с потерями. Эти значения зависят от всех трёх замеров, включая самый медленный.

Для RTT использована медиана интервалов от сегмента сервера до соответствующего ACK клиента. Повторные передачи посчитаны по меткам Wireshark для сегментов от клиента к серверу. Файл передавался в потоке 0 для исходного режима и задержки, в потоке 1 для потерь. Короткое соединение из `loss.pcap` исключено из расчётов по TCP.

#block(breakable: false)[
#set par(justify: false)
#figure(table(
  columns: (1.15fr, 1.4fr, .8fr, .95fr, .65fr, .85fr),
  table.header([Режим], [Замеры, с], [Медиана, с], [МиБ/с], [RTT, мс], [Повторы]),
  [Исходный], [1,44 / 2,32 / 1,30], [1,44], [44,44], [0,085], [4],
  [Задержка 50 мс], [3,55 / 5,36 / 3,61], [3,61], [17,73], [50,469], [0],
  [Потери 1%], [1,55 / 1,43 / 1,23], [1,43], [44,76], [0,120], [16],
), caption: [Время передачи SFTP, полезная скорость и показатели TCP]) <transfer-results>
]

При задержке медиана времени передачи выросла в 2,51 раза. Очередь задерживала данные, запросы SSH и подтверждения, выходившие с клиента. RTT для сегментов сервера включает время, проведённое подтверждениями клиента в netem. Исходящие сегменты клиента видны в захвате уже после очереди, поэтому для них медианы TCP ACK RTT составили 0,482, 1,160 и 0,509 мс соответственно.

В захваченном сеансе с потерями Wireshark отметил 16 повторных передач с клиента, а в захваченном исходном сеансе — четыре. Счётчик отбрасываний netem вырос с 0 до 105 за три передачи и учитывал весь исходящий трафик интерфейса (листинг @netem-drops). Дампы содержат обмен между узлами по TCP 22, поэтому по ним нельзя подтвердить отсутствие другого трафика на интерфейсе.

#block(breakable: false)[
#listing([Счётчик отбрасываний netem до и после серии с потерями], (
  "До серии\n" + read("outputs/qdisc-loss.txt").split("\n").find(line => line.contains("(dropped ")).trim(),
  "После серии\n" + read("outputs/qdisc-loss-after.txt").split("\n").find(line => line.contains("(dropped ")).trim(),
).join("\n")) <netem-drops>
]

Графики Round Trip Time для сегментов сервера приведены на рисунках @baseline-rtt, @delay-rtt и @loss-rtt. На графиках Throughput (@baseline-rate, @delay-rate и @loss-rate) кривая показывает скорость TCP в битах в секунду в скользящем окне 1 с по правой шкале. Точки показывают длины сегментов в захвате на ВМ по левой шкале. По этим длинам нельзя судить о размерах кадров за пределами ВМ. В таблице скорость рассчитана по размеру файла и полному времени команды, поэтому она отличается от пика на графике.

#block(breakable: false)[
#shot("baseline-rtt.png", [RTT в исходном режиме], ratio: 0.654, width: 81%) <baseline-rtt>

В исходном режиме после первых 0,25 с большинство замеров лежит около нуля на шкале графика. Медиана RTT составила 0,085 мс. Начальный всплеск до 40,5 мс был кратковременным.
]
#block(breakable: false)[
#shot("delay-rtt.png", [RTT при задержке исходящего трафика клиента на 50 мс], ratio: 0.654, width: 81%) <delay-rtt>

При добавленной задержке основная группа замеров сместилась к 50 мс, а медиана выросла до 50,469 мс. График показывает устойчивую прибавку к RTT на протяжении сеанса.
]
#block(breakable: false)[
#shot("loss-rtt.png", [RTT при потерях исходящего трафика клиента], ratio: 0.654, width: 81%) <loss-rtt>

При потерях медиана RTT осталась близкой к исходной (0,120 мс), хотя в начале сеанса виден отдельный всплеск до 204 мс. График показывает редкие задержки подтверждений. Число потерь оценивалось отдельно по счётчику netem.
]
#block(breakable: false)[
#shot("baseline-throughput.png", [Throughput в исходном режиме], ratio: 0.654, width: 81%) <baseline-rate>

В исходном сеансе скользящая скорость TCP после начала передачи быстро растёт и к концу достигает примерно 500 Мбит/с. Эта кривая служит основой для сравнения с двумя другими режимами.
]
#block(breakable: false)[
#shot("delay-throughput.png", [Throughput при задержке 50 мс], ratio: 0.654, width: 81%) <delay-rate>

При задержке заметный рост скорости начинается только около 1,4 с, а максимум составляет около 300 Мбит/с против 500 Мбит/с в исходном сеансе. Это согласуется со снижением полезной скорости с 44,44 до 17,73 МиБ/с по серии измерений.
]
#block(breakable: false)[
#shot("loss-throughput.png", [Throughput при случайных потерях 1%], ratio: 0.654, width: 81%) <loss-rate>

В захваченном сеансе с потерями скорость растёт менее равномерно, особенно между 0,6 и 0,8 с. К концу она достигает порядка 500 Мбит/с. По трём замерам в каждом режиме медианы времени практически совпали: 1,43 с с потерями и 1,44 с в исходном режиме.
]

На сервере SHA-256 совпал с исходным для каждого из девяти файлов. В листинге @performance-hash приведён общий хеш и результат сверки для каждой серии. После удаления netem команда `tc qdisc show dev ens3` вернула ту же настройку `fq_codel`, что и до опыта (листинги @qdisc-states и @qdisc-restored).

#let performance-hashes = read("outputs/performance-sha256.txt").trim().split("\n")
#let sample-hash = performance-hashes.first().split(" ").first()
#listing([Сверка SHA-256 исходного файла и полученных копий], (sample-hash, "sample.bin (исходный файл)", ..("baseline", "delay", "loss").map(mode => {
  let matches = performance-hashes.filter(line => line.starts-with(sample-hash) and line.contains("  " + mode + "-")).len()
  mode + ": " + str(matches) + " из 3 совпали"
})).join("\n")) <performance-hash>

#listing([Очередь клиента после завершения испытаний], read("outputs/qdisc-after.txt").trim()) <qdisc-restored>

= Сводный анализ и заключение
В таблице @experiment-summary сведены результаты трёх экспериментов и данные, которыми они подтверждаются.

#block(breakable: false)[
#set par(justify: false)
#figure(table(
  columns: (1.05fr, 1.4fr, 1.8fr),
  table.header([Явление], [Данные], [Подтверждение вывода]),
  [Шифрование передачи], [FTP: поток с 51 байтом. SFTP: TCP 22 и обмен ключами (таблица @ftp-sftp-comparison).], [Байты из FTP совпали с файлом по SHA-256. В записи SFTP видны заголовки и начальный обмен SSH.],
  [Фильтрация TCP и UDP], [Состояния Nmap и ответы в дампах (таблицы @tcp-results и @udp-results).], [При REJECT и DROP TCP 8080 оставался в LISTEN. Состояние Nmap описывает ответ на пробу.],
  [Задержка и потери], [Девять замеров, по одному дампу на режим и счётчики очереди (таблица @transfer-results, листинг @netem-drops).], [Задержка увеличила RTT и время передачи. В захваченном сеансе с потерями отмечено больше повторов. SHA-256 всех файлов совпал.],
), caption: [Результаты экспериментов и подтверждающие данные]) <experiment-summary>
]

Первый пример ограничения отдельного источника даёт TCP 8080. Nmap показал `closed` после REJECT. Только проверка сокета и правила на сервере позволила установить, что сервис продолжал слушать, а RST формировал межсетевой экран.

Второй пример дают повторные передачи TCP. По отметке Wireshark и одному дампу на клиенте нельзя определить, где пропал сегмент или подтверждение. Счётчик netem отдельно подтвердил отбрасывание на исходящей очереди. Для доставки файла результат подтвердили контрольные суммы на принимающем узле.

Пассивный анализ показал, что именно прошло через точку захвата. Активные пробы Nmap показали, как службы и правила отвечали на заданные запросы из сети клиента. Совместно с проверкой сокетов, счётчиков и контрольных сумм эти методы подтвердили причины наблюдаемых различий.
