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

После старта: VPCS PC-HQ-ADMIN `ip 10.1.10.10/27 10.1.10.1`; на EXT-CLIENT туннель wg0 поднимается сам (`wg0.service`),
RDP: `xfreerdp /v:10.1.100.12 /u:rdpuser /p:'Lab2-Vpn-Win#7' /cert-ignore /sec:nla`.
