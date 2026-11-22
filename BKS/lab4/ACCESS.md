# Ключ лицензии и креды БКС4

Ключ Kerio: `20339-ZRB21-ZLCF8`.

Подписанный файл лицензии: [access/kerio-license.key](access/kerio-license.key). Linux Trial, 25 пользователей, до 06.12.2026. Для восстановления импортировать этот файл в мастер Kerio через **Register offline by license file**. Повторно получать файл на сайте не требуется.

| Сервис | Логин | Пароль |
|---|---|---|
| Kerio: https://10.1.99.1:4081/admin/ | `Admin` | `Lab12345` |
| Континент: ЦУС/локальная консоль | `admin` | `Bks4!bf8089a8a861c1caff75` |
| ADMIN-WIN | `Administrator` | `Test123` |
| Портал Guest | `labguest` | `Aa7!ofV6YvBSFEhyOO2tQpfB` |
| Портал Admin | `lab-admin` | `Aa7!0EDxrGB7Fkal5kjqrGEq` |
| LAN-CLIENT, консоль | `labadmin` | `Aa7!cATysQUt6EDhd44zR9jZ` |
| ADMIN-LINUX, консоль | `labadmin` | `Aa7!qQLQtaxRShrdMyMCtDPl` |
| PNETLab MCP: http://100.100.57.19 | `vlad_pc` | `mcfaclaudeot` |

SNMP community: `XeWGhsgw5hGjZk98XTu63pjo`.

SSH к PNETLab: `root@100.100.57.19`, отдельный ключ `access/pnetlab_ed25519` (уже проверен при подготовке передачи).

```bash
chmod 600 BKS/lab4/access/pnetlab_ed25519
ssh -i BKS/lab4/access/pnetlab_ed25519 -o IdentitiesOnly=yes root@100.100.57.19
```

Linux-VM доступны через PNETLab-хост по ключу `/root/.ssh/id_rsa_dy`, пользователь `labadmin`: LAN `.221`, DMZ `.222`, WAN `.223`, ADMIN-LINUX `.224` в подсети `192.168.15.0/24`. Windows OOB: `192.168.15.135`.

Kerio и Континент имеют одинаковые рабочие IP: запускать поочерёдно. MCP и браузер под одним аккаунтом выбивают сессию друг друга.

Креды сохранены открыто по прямому указанию пользователя. Новые учебные пароли БКС — `Lab12345`; текущие пароли выше не менялись.
