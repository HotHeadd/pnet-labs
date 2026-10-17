// Логические схемы поверх img/topology.png (2144×963 px; 1 px = 1pt).
#let tier-stroke = (paint: black, thickness: 4pt, dash: (24pt, 12pt))
#let tier-color = rgb("#c0392b")
#let zone-color = rgb("#1f6fb2")

// Фрагмент топологии [x0, x1] × [y0, y1] с линиями уровней, подписями, тегами и боковой панелью.
#let logic-scheme(
  src,
  x0, x1, y0, y1,
  bounds, // y границ между уровнями (на одну меньше, чем уровней)
  tiers, // ((имя, описание), ...) сверху вниз
  tags: (), // ((x, y, текст), ...) — подписи на схеме, x — центр подписи
  zones: (), // ((x, y, w, h, имя), ...) — пунктирные зоны
  patches: (), // ((x, y, w, h, dy), ...) — закрыть лишнее куском той же картинки со сдвигом dy (кратно шагу сетки 9,18 px)
  links: (), // ((x1, y1, x2, y2), ...) — дорисовать линии связей
  line-x1: none, // где обрывать линии уровней (array по числу bounds или none)
  panel: 430,
) = {
  let w = x1 - x0
  let h = y1 - y0
  let ys = (y0, ..bounds, y1)
  set text(font: "Times New Roman")
  box(width: (w + panel) * 1pt, height: h * 1pt, {
    // картинка
    place(top + left, box(clip: true, width: w * 1pt, height: h * 1pt,
      place(top + left, dx: -x0 * 1pt, dy: -y0 * 1pt,
        box(width: 2144pt, height: 963pt, align(top + left, image(src, width: 2144pt, height: 963pt))))))
    for (x, y, pw, ph, sdy) in patches {
      place(top + left, dx: (x - x0) * 1pt, dy: (y - y0) * 1pt, box(clip: true, width: pw * 1pt, height: ph * 1pt,
        place(top + left, dx: -x * 1pt, dy: -(y + sdy) * 1pt,
          box(width: 2144pt, height: 963pt, align(top + left, image(src, width: 2144pt, height: 963pt))))))
    }
    for (ax, ay, bx, by) in links {
      place(top + left, line(start: ((ax - x0) * 1pt, (ay - y0) * 1pt), end: ((bx - x0) * 1pt, (by - y0) * 1pt),
        stroke: 2pt + rgb(36, 88, 158)))
    }
    for (x, y, zw, zh, name) in zones {
      place(top + left, dx: (x - x0) * 1pt, dy: (y - y0) * 1pt,
        rect(width: zw * 1pt, height: zh * 1pt, stroke: (paint: black, thickness: 4pt, dash: (24pt, 12pt)), radius: 8pt))
      place(top + left, dx: (x - x0 + zw / 2 - 50) * 1pt, dy: (y - y0 + zh - 40) * 1pt, text(size: 26pt, weight: "bold", fill: black, name))
    }
    // линии уровней
    for (i, b) in bounds.enumerate() {
      let short = line-x1 != none and line-x1.at(i) < x1
      let lx = if short { line-x1.at(i) - x0 } else { w + panel }
      place(top + left, dy: (b - y0) * 1pt, line(length: lx * 1pt, stroke: tier-stroke))
      if short {
        place(top + left, dx: w * 1pt, dy: (b - y0) * 1pt, line(length: panel * 1pt, stroke: tier-stroke))
      }
    }
    // имена уровней слева
    for (i, t) in tiers.enumerate() {
      place(top + left, dx: 8pt, dy: (ys.at(i) - y0 + 8) * 1pt,
        box(fill: white.transparentize(15%), inset: 3pt, text(size: 28pt, weight: "bold", fill: black, t.at(0))))
    }
    // теги на схеме
    for (x, y, body) in tags {
      place(top + left, dx: (x - x0 - 150) * 1pt, dy: (y - y0) * 1pt, box(width: 300pt, align(center,
        box(fill: white, stroke: 0.8pt + gray, inset: (x: 2pt, y: 3pt), radius: 3pt, {
          set par(leading: 0.3em)
          text(size: 15pt, body)
        }))))
    }
    // боковая панель: функции уровней
    place(top + left, dx: w * 1pt, line(angle: 90deg, length: h * 1pt, stroke: 1pt + gray))
    for (i, t) in tiers.enumerate() {
      place(top + left, dx: (w + 16) * 1pt, dy: (ys.at(i) - y0 + 10) * 1pt,
        block(width: (panel - 28) * 1pt, height: (ys.at(i + 1) - ys.at(i) - 16) * 1pt, {
          set par(justify: false, leading: 0.45em)
          text(size: 23pt, t.at(1))
        }))
    }
  })
}

#let logic-branch(src) = logic-scheme(
  src,
  0, 960, 160, 925,
  (292, 405, 520, 670),
  (
    ([Интернет], [ISP-1 — основной провайдер, ISP-2 — резервный; канал между ними — межпровайдерский стык]),
    ([Граница], [BR-EDGE: NAT, IP SLA + track (переключение провайдера), VPN в ГО — Tunnel0/Tunnel1 (GRE over IPsec)]),
    ([Ядро], [BR-CORE, BR-CORE-2: только L3-каналы /30, OSPF area 0, ECMP; без ACL и NAT]),
    ([Распределение], [DSW-1/2: SVI — граница L2/L3, HSRP, ACL, DHCP relay; MSTP: корень MST1 (VLAN 10, 30, 50, 70) — DSW-1, MST2 (20, 40, 60, 99) — DSW-2; Po1 — LACP]),
    ([Доступ], [ASW-1…3: VLAN, Port Security, DHCP Snooping, DAI, BPDU Guard; аплинки к обоим DSW, резервный — Alternate]),
  ),
  tags: (
    (84, 870, [VLAN 10]),
    (240, 872, [VLAN 20]),
    (310, 872, [VLAN 20]),
    (384, 872, [VLAN 20 \ 10.2.20.42]),
    (523, 872, [VLAN 30]),
    (590, 872, [VLAN 40]),
    (662, 872, [VLAN 50 \ 10.2.50.10]),
    (792, 866, [VLAN 60]),
    (924, 870, [VLAN 70]),
    (790, 300, [публичные адреса: \ 198.51.100.2 (ISP-1) \ 192.0.2.2 (ISP-2)]),
  ),
  patches: ((748, 155, 212, 51, 138), (748, 226, 212, 38, 138), (774, 205, 186, 22, 138), (770, 222, 6, 5, 138)),
  links: ((773, 215.1, 960, 196),),
)

#let logic-hq(src) = logic-scheme(
  src,
  1110, 2144, 80, 940,
  (205, 380, 530, 670),
  (
    ([Граница], [HQ-EDGE: публичный адрес, NAT и публикация серверов, VPN-шлюз, шлюз DMZ (VLAN 100, ACL DMZ-IN, IPv6 + SLAAC)]),
    ([МЭ], [HQ-FW-1/2 (pfSense): прозрачный L2-мост в разрыве «граница — ядро», HQ-FW-2 — также «граница — DMZ»]),
    ([Ядро], [HQ-CORE-1/2: OSPF area 0, ECMP, L3 EtherChannel между ядрами]),
    ([Распределение], [HQ-DSW-1/2: SVI, VRRP, ACL, DHCP relay; корни MSTP — HQ-DSW-1 (VLAN 10, 50, 55), HQ-DSW-2 (20, 60, 70, 99); LACP]),
    ([Доступ], [HQ-ASW-1/2: VLAN, Port Security, DHCP Snooping, DAI; аплинки — LACP по 2 линка к каждому DSW]),
  ),
  tags: (
    (1400, 100, [публичный адрес 203.0.113.2]),
    (1170, 878, [VLAN 10]),
    (1290, 878, [VLAN 20]),
    (1416, 866, [VLAN 60]),
    (1644, 886, [VLAN 50 \ 10.1.50.10]),
    (1764, 886, [VLAN 55 \ 10.1.55.10]),
    (1884, 878, [VLAN 70]),
    (2040, 146, [VLAN 100 \ 10.1.100.10]),
    (2046, 288, [VLAN 100 \ 10.1.100.11]),
  ),
  zones: ((1720, 90, 410, 255, [DMZ]),),
  line-x1: (1712, 2144, 2144, 2144),
)

// Вписать схему в ширину текста.
#let fit(body) = layout(size => {
  let m = measure(body)
  scale(size.width / m.width * 100%, reflow: true, body)
})
