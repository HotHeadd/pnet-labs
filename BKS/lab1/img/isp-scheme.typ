// Схема подключения к провайдерам для HUMAN.md.
// Сборка: typst compile img/isp-scheme.typ img/isp-scheme.svg
#set page(width: 760pt, height: 430pt, margin: 0pt, fill: white)
#set text(font: "Times New Roman", size: 13pt)

#let P(x, y) = (x * 1pt, y * 1pt)
#let link(a, b, ..style) = place(top + left, line(start: P(..a), end: P(..b), stroke: (thickness: 1.6pt, ..style.named())))
#let label(x, y, body, w: 220) = place(top + left, dx: (x - w / 2) * 1pt, dy: (y - 10) * 1pt,
  box(width: w * 1pt, align(center, box(fill: white, inset: 2pt, body))))
#let node(x, y, name, sub: none, color: rgb("#dbe8f7")) = place(top + left, dx: (x - 70) * 1pt, dy: (y - 26) * 1pt,
  box(width: 140pt, height: 52pt, fill: color, stroke: 1.2pt + rgb("#2c4a6e"), radius: 6pt,
    align(center + horizon, {
      text(size: 15pt, weight: "bold", name)
      if sub != none { linebreak(); text(size: 11pt, sub) }
    })))
// точка на отрезке a→b с долей t
#let at(a, b, t) = (a.at(0) + (b.at(0) - a.at(0)) * t, a.at(1) + (b.at(1) - a.at(1)) * t)

#let isp1 = (230, 110)
#let isp2 = (630, 110)
#let hq = (110, 330)
#let br = (490, 330)

// линки
#link(isp1, isp2)
#link(isp1, hq)
#link(isp1, br)
#link(isp2, br)
#link((hq.at(0), hq.at(1) + 26), (hq.at(0), 395), dash: (8pt, 5pt), paint: rgb("#8a2b2b"))
#link((hq.at(0), 395), (br.at(0), 395), dash: (8pt, 5pt), paint: rgb("#8a2b2b"))
#link((br.at(0), 395), (br.at(0), br.at(1) + 26), dash: (8pt, 5pt), paint: rgb("#8a2b2b"))

// подсети на линках
#label(..at(isp1, isp2, 0.5), [*203.0.113.248/30* \ стык провайдеров])
#label(..at(isp1, hq, 0.5), [*203.0.113.0/30*], w: 130)
#label(..at(isp1, br, 0.5), [*198.51.100.0/30* \ основной канал], w: 140)
#label(..at(isp2, br, 0.5), [*192.0.2.0/30* \ резервный канал], w: 130)
#label((hq.at(0) + br.at(0)) / 2, 395, text(fill: rgb("#8a2b2b"))[VPN: Tunnel0 через ISP-1, Tunnel1 через ISP-2 и стык], w: 340)

// порты и адреса у концов
#label(isp1.at(0) + 115, 88, [e0/1 .249], w: 80)
#label(isp2.at(0) - 115, 88, [e0/1 .250], w: 80)
#label(..at(isp1, hq, 0.2), [e0/2 .1], w: 60)
#label(..at(isp1, hq, 0.8), [e0/0 .2], w: 60)
#label(..at(isp1, br, 0.2), [e0/0 .1], w: 60)
#label(..at(isp1, br, 0.8), [e0/0 .2], w: 60)
#label(..at(isp2, br, 0.2), [e0/0 .1], w: 60)
#label(..at(isp2, br, 0.8), [e0/3 .2], w: 60)

// узлы
#node(..isp1, [ISP-1], sub: [Loopback0 8.8.8.8], color: rgb("#e8eef5"))
#node(..isp2, [ISP-2], sub: [Loopback0 1.1.1.1], color: rgb("#e8eef5"))
#node(..hq, [HQ-EDGE], sub: [ГО, 203.0.113.2])
#node(..br, [BR-EDGE], sub: [филиал])

// подпись «интернет»
#place(top + left, dx: 140pt, dy: 30pt, rect(width: 580pt, height: 140pt, radius: 14pt,
  stroke: (paint: gray, thickness: 1.2pt, dash: (10pt, 6pt))))
#place(top + left, dx: 625pt, dy: 38pt, text(fill: gray.darken(30%), style: "italic")[«интернет»])
