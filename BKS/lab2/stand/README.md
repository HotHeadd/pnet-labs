# Стенд BKS2 — ЛР2 БКС (МЭ Ubuntu на DMZ ГО)

Файл: `pnetlab_export-20261022-233939.zip` (лаба `/BKS labs/BKS2.unl`, состояние на 22.10.2026).
В выгрузке только топология и startup-config IOL. **Диски qemu-узлов (HQ-FW, WIN-SRV, EXT-CLIENT) в неё не входят** —
их настройка живёт на сервере PNETLab в дисках узлов; не делать wipe узлов 5, 6, 8. Повторить настройку с нуля — скрипты в `../commands/`.

| Узел | Образ | Логин |
|---|---|---|
| HQ-FW (5) | linux-ubuntu-server-22.04, консоль telnet | root / Lab2-Fw-2026; fwadmin (SSH только по ключу) |
| WIN-SRV (6) | winserver-S2019-VL-x64, VNC | Administrator / Test123; rdpuser / Lab2-Vpn-Win#7 |
| EXT-CLIENT (8) | linux-kali-large-2019.3, VNC | root / toor |
| ISP, HQ-EDGE, HQ-DMZ | IOL | без пароля |

После старта: VPCS PC-HQ-ADMIN `ip 10.1.10.10/27 10.1.10.1`; на EXT-CLIENT `wg-quick up wg0` (wireguard-go),
RDP: `xfreerdp /v:10.1.100.12 /u:rdpuser /p:'Lab2-Vpn-Win#7' /cert-ignore /sec:nla`.
