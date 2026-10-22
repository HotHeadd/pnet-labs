# ЛР2 БКС — интеграция межсетевого экрана в КВС головного офиса (вариант 6)

Условие — `preamble/Лабораторная работа №2 (БКС).pdf` (42 стр.; теория iptables/xtables-addons/knockd/RDP/PKI/VPN,
задание — стр. 39–42). Для справки там же ЛР3 (site-to-site GRE+IPsec+OSPF на Linux, Xray-каскад) — вероятно, продолжит этот стенд.
Источник условий — Dropbox `/obsvault/mephi/s7/basynya/bks/` (см. корневой `CLAUDE.md`). Преподаватель — Басыня Е. А.
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
В `../lab1/CLAUDE.md` (конец журнала) уже был согласован «План на ЛР с МЭ»: DMZ — маршрутизируемый интерфейс МЭ, правила DMZ на МЭ
вместо ACL DMZ-IN, маршруты в DMZ на HQ-EDGE через МЭ, e0/3 HQ-EDGE убрать.

**Решения пользователя (2026-10-22):**
- Стенд **с нуля**, отдельная лаба **`/BKS labs/BKS2-FW.unl`** (создана через MCP под `vlad_pc`). Чужие лабы/сессии не трогать:
  `/BKS labs/BKS2.unl` (author 6, один узел HQ-FW, 2 открытые сессии pod 6/10) — не наш, не открывать и не менять.
  BKS1 не копируем — на стенде фрагмент ГО из ЛР1 (те же адреса: HQ-EDGE 203.0.113.2, ADMIN 10.1.10.0/27, DMZ 10.1.100.0/28),
  в отчёте — как МЭ встраивается в полную схему ЛР1 (pfSense-заглушки → Ubuntu-МЭ на DMZ).
- **HQ-FW (Ubuntu) на DMZ:** HQ-EDGE → публичный транзит → HQ-FW → HQ-DMZ (WIN-SRV).
- **Внешний клиент EXT-CLIENT в «интернете» стенда** за ISP (wg-quick, xfreerdp, nmap) — Kali (всё уже есть) или Ubuntu.

## Окружение (2026-10-22)

MCP `pnetlab` на Mac подключён (аккаунт `vlad_pc`, local scope, см. корневой `CLAUDE.md`).
На Mac не установлен шаблон typst (`./new-lab.sh` упал на `@local/mephi-lab`) — собирать с `--package-path`
(копия `mephi-labs/` в `<dir>/local/mephi-lab/0.1.0/`). Папка лабы создана копированием `mephi-labs/template/`.

## PNETLab (проверено 2026-10-22 из Mac, `vlad_pc`)

- Шаблоны qemu: `linux` (по умолчанию `linux-ubuntu-srv-16.04.4-webmin`, есть `linux-ubuntu-server-22.04`), `winserver`
  (`winserver-S2019-VL-x64`, 8 ГБ RAM по умолчанию, nic e1000, консоль VNC), `kali` (`kali-2020-epiol`, 4 ГБ, VNC), `win`, `docker`.
- `list_labs` по подпапкам (`/BKS labs`, `/SA labs`) отдаёт ошибку 60038.
- MCP `add_node` не передаёт qemu-опции шаблона (см. корневой CLAUDE.md, проверено в `~/mcp/pnetlab-mcp-server/src/.../client.py`) →
  qemu-узлы и облако добавляет пользователь в веб-морде.

## ТОЧКА ОСТАНОВКИ (2026-10-22 ~23:00, кончились лимиты)

Стенд запущен и работает, всё ключевое проверено (см. план п. 6). Сохранено: write memory IOL + export_config,
`stand/pnetlab_export-20261022-215442.zip`; HQ-FW — rules.v4 (netfilter-persistent), wg-quick@wg0 enabled, бэкап /var/backups/hq-fw.
Продолжить: (1) на HQ-FW `grep 'Hardening index' /root/lynis-after.txt`, `/root/rkhunter.txt`, `/root/chkrootkit.txt` → `outputs/`;
(2) перезагрузить HQ-FW и проверить, что правила/wg/маршруты поднялись; (3) конфиги HQ-FW (`iptables-save`, wg0.conf без ключа,
netplan, sshd 90-hq-fw.conf) переписать в `configs/HQ-FW/`; (4) отчёт `main.typ` (листинги из `commands/`, `outputs/`, скриншоты `img/`);
(5) спросить пользователя про удаление ноды 7 (EXT-CLIENT-old). Kali после ребута: `wg-quick up wg0` вручную.

## Стенд BKS2-FW

| id | Узел | Образ | Порты |
|---|---|---|---|
| 1 | ISP | IOL L3 15.4 | e0/0 → HQ-EDGE e0/0; e0/1 → EXT-CLIENT; lo0 8.8.8.8 |
| 2 | HQ-EDGE | IOL L3 15.4 | e0/0 → ISP; e0/1 → HQ-FW e0 (WAN); e0/2 → PC-HQ-ADMIN |
| 3 | HQ-DMZ | IOL L2 15.2 | e0/0 → HQ-FW e1; e0/1 → WIN-SRV; VLAN 100 на всех портах |
| 4 | PC-HQ-ADMIN | VPCS | → HQ-EDGE e0/2 |
| 5 | HQ-FW | linux-ubuntu-server-22.04, 3 NIC, 2 ГБ, 2 CPU, telnet | e0 → HQ-EDGE e0/1; e1 → HQ-DMZ e0/0; e2 → облако NetManagement (net 3) |
| 6 | WIN-SRV | winserver-S2019-VL-x64, 4 ГБ, 2 CPU, vnc | e0 → HQ-DMZ e0/1 |
| 7 | EXT-CLIENT-old | kali-2020-epiol → не грузится («No bootable device»); остановлен, e1 ещё в облаке (отвязать API не дал) — **удалить, когда пользователь разрешит** | — |
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
2. [x] Стенд BKS2-FW собран (2026-10-22): IOL/VPCS — MCP, qemu + облако — `tools/pnet-helper.py`; `start_all`.
3. [x] Адресация/маршрутизация (IOL консолью, HQ-FW netplan `commands/HQ-FW-netplan.yaml`, Kali nmcli `commands/EXT-CLIENT-setup.sh`).
4. [x] HQ-FW базово: `commands/HQ-FW-{install,base,iptables,hardening}.sh`; Lynis до — 65.
5. [x] Вариант 6: WireGuard (`HQ-FW-wireguard.sh`), psd/recent → TARPIT, DELUDE 12345, WIN-SRV NLA (`WIN-SRV-base.ps1`).
6. [~] Проверки сделаны (`outputs/`, скриншоты `img/`): nmap до/после/DELUDE, WG, RDP NLA ок / без NLA отказ / без туннеля нет,
   DNAT 8080, WIN-SRV → 8.8.8.8 (SNAT .11), DMZ ↛ ADMIN (FW-DROP), ADMIN → DMZ ping, SSH ключ/пароль/root.
   Осталось: lynis после + rkhunter/chkrootkit (запущены в фоне → /root/*.txt), перезагрузка HQ-FW (правила/wg живут),
   write memory + export_config, бэкап конфигов HQ-FW в `configs/`, `download_lab` → `stand/`.
7. [ ] Отчёт по структуре методички; листинги сырыми по ходу, формализация в конце.

## Заметки

- Консоли Ubuntu/Windows в PNET — VNC (как pfSense: возможны потери Shift/лишние Enter) или telnet для serial-консоли Ubuntu.
  Сеть облака с Mac недоступна — выводы со скриншотов (telnet HQ-FW читается хорошо).
- xtables-addons собирается DKMS под текущее ядро — нужны `linux-headers-$(uname -r)` и интернет через MGMT.
