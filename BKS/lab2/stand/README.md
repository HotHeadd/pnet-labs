# Стенд BKS2 — ЛР2 БКС (МЭ Ubuntu на DMZ ГО)

Файл: `pnetlab_export-20261023-184936.zip` (лаба `/BKS labs/BKS2.unl`, состояние на 23.10.2026).
В выгрузке только топология и startup-config IOL. **Диски qemu-узлов (HQ-FW, WIN-SRV, EXT-CLIENT) в неё не входят** —
они опубликованы образами на сервере PNETLab (`linux-bks2-hq-fw-v1`, `winserver-bks2-win-srv-v1`, `linux-bks2-ext-client-v1`,
23.10.2026, проверено на клоне лабы): любой аккаунт, открывший лабу, получает узлы настроенными. Импорт выгрузки на другой сервер
без этих образов не заработает — тогда настройка с нуля по скриптам `../commands/`.

| Узел | Образ | Логин |
|---|---|---|
| HQ-FW (5) | linux-bks2-hq-fw-v1 (база linux-ubuntu-server-22.04), консоль telnet | root / Lab2-Fw-2026; fwadmin (SSH только по ключу) |
| WIN-SRV (6) | winserver-bks2-win-srv-v1 (база winserver-S2019-VL-x64), VNC | Administrator / Test123; rdpuser / Lab2-Vpn-Win#7 |
| EXT-CLIENT (8) | linux-bks2-ext-client-v1 (база linux-kali-large-2019.3), VNC | root / toor |
| ISP, HQ-EDGE, HQ-DMZ | IOL | без пароля |

### Учётные данные — подробно

Пароли учебные, действуют только внутри стенда (узлы недоступны снаружи PNETLab).

| Узел | Учётка | Пароль / ключ | Где действует |
|---|---|---|---|
| HQ-FW | `root` | `Lab2-Fw-2026` | только консоль PNETLab (telnet `100.100.57.19:30008`); по SSH запрещён |
| HQ-FW | `fwadmin` | ключ Ed25519 с Kali (`/root/.ssh/id_ed25519`); пароль `Lab2-Fw-2026` — только для `sudo` | SSH с Kali: `ssh fwadmin@192.168.15.134`; пароль по SSH не принимается |
| WIN-SRV | `Administrator` | `Test123` (из образа PNETLab) | консоль PNETLab (VNC `100.100.57.19:30009`) |
| WIN-SRV | `rdpuser` | `Lab2-Vpn-Win#7` | RDP с NLA через WireGuard (группа Remote Desktop Users, без прав администратора) |
| EXT-CLIENT | `root` | `toor` (стандарт Kali) | консоль PNETLab (VNC `100.100.57.19:30011`) |
| EXT-CLIENT ↔ HQ-FW | WireGuard | ключи в `/etc/wireguard/wg0.conf` на обоих узлах | туннель 10.1.200.8 ↔ 10.1.200.1, udp/51820 на 203.0.113.10 |
| ISP, HQ-EDGE, HQ-DMZ | — | без пароля (консоль сразу в `>`, `enable` без пароля; telnet на vty закрыт — `login` без пароля) | консоль PNETLab |
| PC-HQ-ADMIN | — | — | консоль PNETLab |

fail2ban на HQ-FW: 3 ошибки SSH за 10 мин → бан адреса на 1 ч (`fail2ban-client set sshd unbanip <ip>`).
VNC-консоли без пароля: «Общий экран» macOS их не открывает — HTML5-консоль PNETLab или RealVNC/TigerVNC.
Аккаунты PNETLab (`*_pc` и веб) — не здесь: `mcp-creds.json` в корне репо (не в git).

После старта: VPCS PC-HQ-ADMIN `ip 10.1.10.10/27 10.1.10.1`; на EXT-CLIENT туннель wg0 поднимается сам (`wg0.service`),
RDP: `xfreerdp /v:10.1.100.12 /u:rdpuser /p:'Lab2-Vpn-Win#7' /cert-ignore /sec:nla`.
