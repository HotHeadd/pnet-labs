#!/usr/bin/env python3
from pathlib import Path
from html import escape
OUT=Path(__file__).resolve().parents[1]/'img'
def render(name,title,boxes,lines,notes):
 s=['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="670" viewBox="0 0 1100 670">','<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#526b85"/></marker></defs>','<rect width="1100" height="670" fill="white"/>',f'<text x="550" y="35" text-anchor="middle" font-family="Arial" font-size="23" font-weight="bold" fill="#18344f">{escape(title)}</text>']
 for pts,label,lx,ly,dash,color in lines:
  s.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="3" marker-end="url(#a)"'+(' stroke-dasharray="8,5"' if dash else '')+'/>')
  s.append(f'<text x="{lx}" y="{ly}" text-anchor="middle" font-family="Arial" font-size="16" fill="{color}">{escape(label)}</text>')
 for x,y,w,h,title,body in boxes:
  s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="#eff5fa" stroke="#526b85" stroke-width="2"/>')
  s.append(f'<text x="{x+w/2}" y="{y+28}" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#18344f">{escape(title)}</text>')
  for i,t in enumerate(body):s.append(f'<text x="{x+w/2}" y="{y+54+i*23}" text-anchor="middle" font-family="Arial" font-size="16" fill="#18344f">{escape(t)}</text>')
 for i,t in enumerate(notes):s.append(f'<text x="35" y="{605+i*24}" font-family="Arial" font-size="16" fill="#40576a">{escape(t)}</text>')
 s.append('</svg>');(OUT/name).write_text('\n'.join(s))
render('topology.svg','Стенд БКС3: защищённая связь ГО и филиала',[
 (45,220,270,125,'BR-GW',['WAN 203.0.113.20/24','LAN 10.2.20.1/24','tun0 172.16.0.2/30']),
 (425,220,270,125,'HQ-GW',['WAN 203.0.113.10/24','LAN 10.1.50.1/26','tun0 172.16.0.1/30']),
 (785,220,270,125,'XRAY-RELAY',['WAN 203.0.113.30/24','VLESS + TLS 1.3','Промежуточный узел']),
 (45,435,270,110,'BR-CLIENT',['10.2.20.42/24','SOCKS5 127.0.0.1:1080']),
 (425,435,270,110,'HQ-SRV',['10.1.50.10/26','HTTP TCP/8080']),
], [('180,220 180,100 560,100 560,220','GRE / IPsec / OSPF',370,88,False,'#247b63'),
 ('315,280 425,280','WAN',370,267,False,'#526b85'),
 ('785,280 695,280','TLS',740,267,False,'#526b85'),
 ('180,435 180,345','BR-LAN',245,395,False,'#526b85'),
 ('560,345 560,435','HQ-LAN',625,395,False,'#526b85'),
 ('315,480 350,480 350,565 920,565 920,345','Xray: клиент → relay → HQ → сервер',730,585,True,'#94662f')],
 ['WAN — изолированный Ethernet-сегмент эмулятора, сеть 203.0.113.0/24.',
 'Служебное pnet0 (192.168.15.211–215) подключено отдельно и не участвует в передаче между LAN.',
 'Серверная сеть ГО и LAN филиала сохранены из адресного плана БКС1.'])
render('architecture.svg','Вариант 6: проект распределённой корпоративной сети',[
 (80,80,350,130,'ЦОД-1 / ГО',['Нижний Новгород · 10.1.0.0/16','Шлюзы SD-WAN / МЭ / DMZ','Основные сервисы и контроллер']),
 (670,80,350,130,'ЦОД-2',['Другая площадка · 10.3.0.0/16','Резервные шлюзы и сервисы','Независимый канал и питание']),
 (30,385,310,140,'20 пунктов выдачи',['Оптика и/или LTE','CPE с Zero-Touch Provisioning','Зашифрованный SD-WAN overlay']),
 (395,385,310,140,'Лаборатория',['Соседнее здание','Направленный радиомост','Защита канала и сегментация']),
 (760,385,310,140,'Подрядчик',['HTTPS с аутентификацией','Прокси в DMZ → один сервис','Остальные сети закрыты']),
], [('430,145 670,145','Защищённая межЦОД-связь',550,130,False,'#526b85'),
 ('185,385 185,210','Основной overlay',103,300,False,'#247b63'),
 ('260,385 785,210','Резервный overlay',625,316,True,'#247b63'),
 ('550,385 550,260 330,260 330,210','Радиоканал',460,249,False,'#526b85'),
 ('915,385 915,275 850,275 850,210','Только веб-сервис',935,259,False,'#94662f')],
 ['Архитектурный проект: SD-WAN и физический радиоканал описаны и обоснованы теоретически.',
 'Практическая часть: отдельный Linux Site-to-Site стенд и каскад Xray (см. схему стенда).',
 'Резервирование сервисов требует репликации данных и проверки переключения приложений.'])
