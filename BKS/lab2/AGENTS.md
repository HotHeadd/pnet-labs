# ЛР2 БКС — интеграция межсетевого экрана в КВС головного офиса (вариант 6)

## Как читать этот файл

- Стенд `/BKS labs/BKS2.unl` — отдельный фрагмент ГО: Ubuntu-МЭ, Windows Server и внешний клиент Kali, вариант 6.
  Связь с ЛР1 описывать в отчёте; рабочий BKS1 ради этой лабы не менять.
- Последняя запись 2026-10-23 подтверждает состав авторов, вставленную топологию и готовность отчёта к сдаче.
  Ранние указания «уточнить авторов», «нет топологии» и остатки пункта 6 — исторические; сначала сверять артефакты.
- Сценарий защиты — `demo-checks.md`, опубликованные образы и выгрузка — `stand/README.md`.
  Номер рабочей сессии из журнала перед подключением проверять через `sessions`.
- После перезапуска qemu ранее отказывали линки к IOL. Диагностика описана в журнале; не перезапускать устройства
  профилактически и не затрагивать консоли, в которых сейчас работает человек.

Условие — `preamble/Лабораторная работа №2 (БКС).pdf` (42 стр.; теория iptables/xtables-addons/knockd/RDP/PKI/VPN,
задание — стр. 39–42). Для справки там же ЛР3 (site-to-site GRE+IPsec+OSPF на Linux, Xray-каскад) — вероятно, продолжит этот стенд.
Источник условий — Dropbox `/obsvault/mephi/s7/basynya/bks/` (см. корневой `AGENTS.md`). Преподаватель — Басыня Е. А.
Авторы на титуле скопированы из ЛР1 (4 человека) — **уточнить у пользователя**.

## Задание

Общее (стр. 39): в **ранее спроектированную КВС ГО** (ЛР1) интегрировать МЭ (шлюз). Сравнительный анализ — выбор семейства ОС
**и конкретного продукта** по критериям: надёжность/отказоустойчивость, ИБ, быстродействие, трудоёмкость сопровождения.
При первоначальной настройке отработать: 1) резервное копирование и масштабируемость; 2) организация и защита удалённого
доступа (протоколы, технологии, алгоритмы аутентификации); 3) МЭ, включая все разновидности NAT и DMZ; 4) устранение
опубликованных уязвимостей и бэкдоров; 5) дополнительные средства защиты; 6) задание по варианту.

**Вариант 6:** Ubuntu Server (МЭ + VPN-сервер) и Windows Server. Базовый iptables с NAT — Windows выходит в интернет через Ubuntu.
Сервер WireGuard, подключение извне по защищённому RDP к Windows через VPN-туннель. Защита от сканирования портов
средствами **xtables-addons**. **NLA** в Windows.

Отчёт: 1) цель; 2) ТЗ; 3) сравнительный анализ; 4) установка и конфигурирование; 5) комплекс мер ИБ; 6) заключение.

## Связь с ЛР1

ЛР1 (`../lab1`, стенд `/BKS labs/BKS1.unl`) требовала только «интеграцию МЭ, разработка — в следующих ЛР». Там HQ-FW-1/2 —
pfSense прозрачными мостами без фильтрации, в отчёте ЛР1 обещано «политики МЭ — в следующих ЛР». ЛР2 — эта «следующая ЛР».
В `../lab1/AGENTS.md` (конец журнала) уже был согласован «План на ЛР с МЭ»: DMZ — маршрутизируемый интерфейс МЭ, правила DMZ на МЭ
вместо ACL DMZ-IN, маршруты в DMZ на HQ-EDGE через МЭ, e0/3 HQ-EDGE убрать.

**Решения пользователя (2026-10-22):**
- Стенд **с нуля**, лаба **`/BKS labs/BKS2.unl`** (создана через MCP под `vlad_pc` как BKS2-FW; 2026-10-23 по просьбе
  пользователя старая BKS2.unl — один узел HQ-FW, author 6 — удалена вместе с пустыми сессиями, BKS2-FW переименована в BKS2;
  UUID лабы прежний ee755183-…, диски нод сохранились).
  BKS1 не копируем — на стенде фрагмент ГО из ЛР1 (те же адреса: HQ-EDGE 203.0.113.2, ADMIN 10.1.10.0/27, DMZ 10.1.100.0/28),
  в отчёте — как МЭ встраивается в полную схему ЛР1 (pfSense-заглушки → Ubuntu-МЭ на DMZ).
- **HQ-FW (Ubuntu) на DMZ:** HQ-EDGE → публичный транзит → HQ-FW → HQ-DMZ (WIN-SRV).
- **Внешний клиент EXT-CLIENT в «интернете» стенда** за ISP (wg-quick, xfreerdp, nmap) — Kali (всё уже есть) или Ubuntu.

## Окружение (2026-10-22)

MCP `pnetlab` на Mac подключён (аккаунт `vlad_pc`, local scope, см. корневой `AGENTS.md`).
На Mac не установлен шаблон typst (`./new-lab.sh` упал на `@local/mephi-lab`) — собирать с `--package-path`
(копия `mephi-labs/` в `<dir>/local/mephi-lab/0.1.0/`). Папка лабы создана копированием `mephi-labs/template/`.

## PNETLab (проверено 2026-10-22 из Mac, `vlad_pc`)

- Шаблоны qemu: `linux` (по умолчанию `linux-ubuntu-srv-16.04.4-webmin`, есть `linux-ubuntu-server-22.04`), `winserver`
  (`winserver-S2019-VL-x64`, 8 ГБ RAM по умолчанию, nic e1000, консоль VNC), `kali` (`kali-2020-epiol`, 4 ГБ, VNC), `win`, `docker`.
- `list_labs` по подпапкам (`/BKS labs`, `/SA labs`) отдаёт ошибку 60038.
- MCP `add_node` не передаёт qemu-опции шаблона (см. корневой AGENTS.md, проверено в `~/mcp/pnetlab-mcp-server/src/.../client.py`) →
  qemu-узлы и облако добавляет пользователь в веб-морде.

## Состояние (2026-10-23)

Практическая часть выполнена и проверена, стенд работает. Lynis 65 → 71; rkhunter 0 руткитов (ложные предупреждения —
в /etc/rkhunter.conf.local, PermitRootLogin продублирован в основном sshd_config); chkrootkit — только тестовые файлы fail2ban.
Перезагрузка HQ-FW: правила, wg0, маршруты, службы поднимаются сами (`outputs/HQ-FW-after-reboot.txt`). snapd замаскирован.
Отчёт `main.typ` написан целиком (собирается, 27+ стр.). Осталось: скриншот топологии `img/topology.png` (заглушка в отчёте —
просить пользователя), финальная выгрузка `stand/` после изменений.
Kali: туннель поднимается при загрузке (`wg0.service`, `commands/EXT-CLIENT-wg0.service`, с 2026-10-23).
**Сверка 2026-10-23 (повторная):** топология = таблица ниже; startup IOL = `configs/`, running = startup (кроме служебного `length 0` на line con);
HQ-FW iptables/nat = `HQ-FW-iptables.sh` и = rules.v4, sshd/fail2ban/auditd/бэкапы по `HQ-FW-hardening.sh`; сквозные проверки (WG, RDP NLA, DNAT 8080, SNAT .11, ADMIN→DMZ/8.8.8.8) ок. Конфиги IOL — `configs/*.txt` (из выгрузки), HQ-FW — источник `commands/HQ-FW-*.sh`
(сверено md5 по коду без комментариев).

## Стенд BKS2

| id | Узел | Образ | Порты |
|---|---|---|---|
| 1 | ISP | IOL L3 15.4 | e0/0 → HQ-EDGE e0/0; e0/1 → EXT-CLIENT; lo0 8.8.8.8 |
| 2 | HQ-EDGE | IOL L3 15.4 | e0/0 → ISP; e0/1 → HQ-FW e0 (WAN); e0/2 → PC-HQ-ADMIN |
| 3 | HQ-DMZ | IOL L2 15.2 | e0/0 → HQ-FW e1; e0/1 → WIN-SRV; VLAN 100 на всех портах |
| 4 | PC-HQ-ADMIN | VPCS | → HQ-EDGE e0/2 |
| 5 | HQ-FW | linux-ubuntu-server-22.04, 3 NIC, 2 ГБ, 2 CPU, telnet | e0 → HQ-EDGE e0/1; e1 → HQ-DMZ e0/0; e2 → облако NetManagement (net 3) |
| 6 | WIN-SRV | winserver-S2019-VL-x64, 4 ГБ, 2 CPU, vnc | e0 → HQ-DMZ e0/1 |
| 8 | EXT-CLIENT | linux-kali-large-2019.3 (шаблон linux), 2 NIC, 3 ГБ, vnc, GNOME | e0 → ISP e0/1; e1 → облако NetManagement (net 3) |

qemu-узлы и облако созданы `../../tools/pnet-helper.py` (опции шаблона + `networks/add` type pnet0 + `interfaces/edit`), не веб-мордой.

IOL: `push_config` не сработал для L3 (ISP, HQ-EDGE висели в initial dialog; L2 HQ-DMZ загрузился) — конфиги введены консолью
+ `write memory`; файлы — `commands/*-base.txt`. VPCS: `ip 10.1.10.10/27 10.1.10.1`.

**Логины:** HQ-FW root/`Lab2-Fw-2026` (консоль), fwadmin/`Lab2-Fw-2026` (sudo; SSH только по ключу Kali); WIN-SRV Administrator/`Test123`,
rdpuser/`Lab2-Vpn-Win#7` (Remote Desktop Users); EXT-CLIENT root/`toor`.
HQ-FW: образ без известного пароля (cloud-образ, hostname hq-fw) — пароль сброшен загрузкой диска ядром хоста PNETLab:
qemu_options `-kernel /vmlinuz -initrd /initrd.img -append 'root=/dev/vda1 rw init=/bin/bash console=tty0'` (через `pnet-helper.py edit`),
`chpasswd`, `touch /etc/cloud/cloud-init.disabled`, затем qemu_options вернуть. GRUB у cloud-образа не ловится (timeout 0).
Интерфейсы HQ-FW: ens3=e0 WAN, ens4=e1 DMZ, ens5=e2 MGMT. Облако pnet0 на этом хосте — 192.168.15.0/24 (DHCP, шлюз .2):
HQ-FW ens5 .134, Kali eth1 .133. С Mac сеть облака недоступна — всё через консоли.
Kali 2019.3: ядро 5.3 без WireGuard → собран userspace `wireguard-go` 0.0.20230223 (Go 1.22 в /opt/go) и `wireguard-tools`
из GitHub-зеркал (git.zx2c4.com висит), `commands/EXT-CLIENT-wireguard-build.sh`; `wg-quick up wg0` сам берёт wireguard-go.
VNC-ввод: `tools/pnet-helper.py type` (Shift и Unicode-keysym исправлены; кириллица в heredoc шла мусором — комментарии в скриптах для ввода
писать по-английски или сверять md5 без комментариев).

| Сеть | Подсеть | Адреса |
|---|---|---|
| ISP – HQ-EDGE | 203.0.113.0/30 | ISP .1, HQ-EDGE .2 (NAT outside, overload для ADMIN) |
| Транзит HQ-EDGE – HQ-FW (публичная) | 203.0.113.8/29 | HQ-EDGE .9, HQ-FW .10; на ISP маршрут via .2 |
| ADMIN ГО | 10.1.10.0/27 | HQ-EDGE .1, PC-HQ-ADMIN .10 |
| DMZ | 10.1.100.0/28 (+ fd00:1:100::/64 при желании) | HQ-FW .1, WIN-SRV .12 |
| «Интернет» EXT-CLIENT | 203.0.113.16/30 | ISP .17, EXT-CLIENT .18 |
| WireGuard | 10.1.200.0/24 | HQ-FW .1 (udp 51820 на 203.0.113.10), EXT-CLIENT .8 |
| SNAT WIN-SRV | 203.0.113.11 | вторичный адрес на ens3 HQ-FW |
| Управление (облако) | 192.168.15.0/24 DHCP | HQ-FW .134, EXT-CLIENT .133 |

На HQ-EDGE: маршруты 10.1.100.0/28 и 10.1.200.0/24 via 203.0.113.10; транзит не NAT-ится (e0/1 без `ip nat`).
На HQ-FW: SNAT WIN-SRV → .11, MASQUERADE остальной DMZ, DNAT 203.0.113.10:8080 → WIN-SRV:80 (IIS), DNAT DNS из DMZ → 8.8.8.8,
WireGuard на .10. Политика — `commands/HQ-FW-iptables.sh` (rules.v4 через netfilter-persistent).

## План (статус)

0. [x] Контекст: условие из Dropbox, папка лабы, этот файл, заготовка `main.typ`.
1. [x] PNETLab: MCP подключён, образы Ubuntu 22.04 / Windows Server 2019 / Kali есть.
2. [x] Стенд BKS2 собран (2026-10-22): IOL/VPCS — MCP, qemu + облако — `tools/pnet-helper.py`; `start_all`.
3. [x] Адресация/маршрутизация (IOL консолью, HQ-FW netplan `commands/HQ-FW-netplan.yaml`, Kali nmcli `commands/EXT-CLIENT-setup.sh`).
4. [x] HQ-FW базово: `commands/HQ-FW-{install,base,iptables,hardening}.sh`; Lynis до — 65.
5. [x] Вариант 6: WireGuard (`HQ-FW-wireguard.sh`), psd/recent → TARPIT, DELUDE 12345, WIN-SRV NLA (`WIN-SRV-base.ps1`).
6. [x] Проверки сделаны (`outputs/`, скриншоты `img/`): nmap до/после/DELUDE, WG, RDP NLA ок / без NLA отказ / без туннеля нет,
   DNAT 8080, WIN-SRV → 8.8.8.8 (SNAT .11), DMZ ↛ ADMIN (FW-DROP), ADMIN → DMZ ping, SSH ключ/пароль/root.
   Осталось: lynis после + rkhunter/chkrootkit (запущены в фоне → /root/*.txt), перезагрузка HQ-FW (правила/wg живут),
   write memory + export_config, бэкап конфигов HQ-FW в `configs/`, `download_lab` → `stand/`.
7. [x] Отчёт по структуре методички (кроме скриншота топологии).

## Заметки

- **Команда (2026-10-23):** BKS2 открывали и micha (pod 6), и micha_pc (pod 10) — пустые сессии, их не трогать.
  Вечером micha_pc присоединён к рабочей сессии №4 (`pnet-helper.py join`); его пустая сессия №6 (pod 10) осталась —
  закрыть может пользователь (`close-session 6`). Шпаргалка к защите — `HUMAN.md`, сценарий проверок — `demo-checks.md`.
- **2026-10-23 ~20:50 (сессия №4): все линки qemu ↔ IOL мёртвые.** HQ-FW ens3/ens4 RX 0 пакетов (uptime 1:04 — перезапущена
  при публикации), HQ-EDGE не пингует 203.0.113.10, ISP — Kali 203.0.113.18; ARP-записи на IOL возрастом ~85 мин = момент
  перезапуска qemu-узлов. IOL ↔ IOL и облако (ens5) работают. **Подтверждено:** после перезапуска qemu-узлов при живых IOL
  линки не восстанавливаются; перезапуск ISP, HQ-EDGE, HQ-DMZ (stop+start, конфиги из startup-config) всё вернул, VPCS
  трогать не пришлось. Затем регресс по `demo-checks.md` п. 1–7 — всё ✅ (`outputs/regress-20261023.txt`); п. 8 (ребут HQ-FW) не повторял.
- **2026-10-24:** после перезагрузки хоста все узлы сессии №4 были выключены, диски целы; `start_all` → всё поднялось само
  (линки qemu ↔ IOL живы, т. к. стартовали вместе; VPCS взял адрес из startup.vpc; wg handshake с Kali; правила 37/8 строк).
- Проверки с Kali удобнее скриптом: `pnet-helper.py push` на HQ-FW (telnet, md5) → на Kali `scp fwadmin@192.168.15.134:/tmp/c.sh .`
  (короткая строка через `type`) → `sh c.sh` → вывод в файл. RDP без GUI — `xfreerdp ... /auth-only` (rc=0 — NLA прошла).
  Из Git Bash вызывать хелпер с `MSYS_NO_PATHCONV=1` (иначе `/root/...` → `C:/Program Files/Git/root/...`).
- VNC-консоли через MCP `read_console` теряют Shift (`|`, `$`, `-W`); `pnet-helper.py type` на Kali обрезает длинные строки
  (~50 симв.) — давать короткие строки. Хелпер исправлен: открытие лабы не уводит аккаунт из присоединённой сессии.
- **Опубликовано 2026-10-23:** узлы 5/6/8 → `linux-bks2-hq-fw-v1` (3,2 ГБ), `winserver-bks2-win-srv-v1` (12 ГБ), `linux-bks2-ext-client-v1`
  (13 ГБ); проверено на клоне `BKS2-verify` (HQ-FW правила/wg, Kali туннель сам, RDP NLA, DNAT 8080, DELUDE open).
  Оверлеи на хосте: `/opt/unetlab/tmp/<id сессии лабы>/<session узла>/virtioa.qcow2`.
- **MAC/IP в облаке управления одинаковы во всех pod** (firstmac в .unl): HQ-FW ens5 .134, Kali eth1 .133 — два pod BKS2 с запущенными
  HQ-FW/Kali одновременно конфликтуют в сети управления (WAN/DMZ изолированы, им не мешает).

- **DELUDE (2026-10-23):** xtables-addons 3.19 на ядре 5.15 шлёт SYN/ACK с TTL=0 (WARNING dst.h:160 в delude_tg) — HQ-EDGE
  его отбрасывал, nmap видел 12345 filtered. Исправлено правилом
  `-t mangle -A POSTROUTING -o ens3 -m ttl --ttl-eq 0 -j TTL --ttl-set 64` (в `HQ-FW-iptables.sh` и rules.v4) — теперь 12345 open.
  TARPIT этим не страдает.

- Консоли Ubuntu/Windows в PNET — VNC (как pfSense: возможны потери Shift/лишние Enter) или telnet для serial-консоли Ubuntu.
  Сеть облака с Mac недоступна — выводы со скриншотов (telnet HQ-FW читается хорошо).
- xtables-addons собирается DKMS под текущее ядро — нужны `linux-headers-$(uname -r)` и интернет через MGMT.
- **2026-10-23 вечер:** состав авторов на титуле (4 человека, как в ЛР1) подтверждён пользователем; скриншот топологии
  `img/topology.png` вставлен в отчёт (рис. 1). Отчёт собирается (28 стр.), регресс п. 1–7 пройден — ЛР2 готова к сдаче.
