# БКС4, вариант 6 — проверки и готовность

## Текущее состояние 13.11.2026

Работают KERIO, Linux3–6 и ADMIN-WIN7; CONTINENT выключен. Сессия9/pod7. Континент повторно проверен по сохранённой политике21FW/4NAT: AV, DPI гостя/администратора, IPS, GeoIP и доставка событий подтверждены outputs/continent-demo-* и img/continent-*-current.png. Даты полного прогона ниже сохранены явно.

Kerio активирован: licenseSet=true/rsTrialRegistered/LoginRegular. Итог22FW/defaultDrop, без TemporarySSH. Группы Guests/Administrators и nativeAppID: гость блокируется на6667/16667/6881/16881, администратор проходит IRC/PONG и получает16384байт BitTorrent. GeoIP: off RU/US200, on RU200/US000, nativeклассификацияUS. NativeIPS: log-only Alert, High/Medium DropAndLog блокирует SQL/path traversal WAN; Lowсканирование толькоAlert. Исключение SID1:2000345 глобально, не по IP. NativeSyslog/внешниеIPSSNMP/статистика/нативныйrestoreсемиразделов проверены. Артефакты outputs/kerio-*, configs/kerio-*.

Не закрыто: первоначальная базаAV (EICAR/ZIP200), свежие обновленияIPS, подавление сканирования именноIPS и веб-детекты прямогоLAN→DMZ. См. manual-actions.md. Не заявлять полную готовность этих пунктов и не повторять регистрацию/CAPTCHA.

Для Kerio проверки выполняются из ~/bks4-checks/ на соответствующей LinuxВМ: check-kerio.sh lan/wan/dmz/admin, check-app-protocols.py с10.1.10.42 или10.1.99.10. Полные ответы API — kerio-status.py на ADMIN; пароли берутся из приватных файлов. Проверка доставки IPS: check-alert-delivery.py --component IPS --origin kerio --since <UTC> --output <файл>. Пользовательские группы привязаны к рабочим IP автоматически; это не парольный портал.

Состояние на 2026-11-07 после итогового прогона (установка `76d7bac5`, `outputs/continent-final-*`). Все пункты ниже подтверждены **одним** прогоном 10:37–10:44 UTC с событиями журнала (`continent-final-events.txt`).

## Что готово и что осталось

| Пункт | Подтверждение | Текущий статус |
|---|---|---|
| LAN → WAN, NAT | `outputs/continent-final-base-lan.txt` | Готово |
| Публикация DMZ 8080/8443 | `outputs/continent-final-base-wan.txt` | Готово |
| Изоляция DMZ → LAN | `outputs/continent-final-base-dmz.txt`, событие в `continent-final-events.txt` | Готово; LAN → DMZ кроме 80/443 — `BKS4-Deny-LAN-to-DMZ-Other` |
| Антивирус plain/ZIP/HTTPS | `outputs/continent-final-av-{guest,admin}.txt` | Готово для гостя LAN и администратора (DMZ и WAN) |
| Категории URL и типы файлов | Условие варианта 6 | Отдельные ограничения URL/типов файлов вариантом не заданы; не подменять их тестом DPI |
| Исключение администратора | `outputs/continent-final-apps-admin.txt` + события | Готово |
| Гостевой DPI на двух портах | `outputs/continent-final-apps-guest.txt` + события | Готово: IRC, Jabber, BitTorrent + категории Chat/FileSharing, любой получатель; HTTP гостя при этом работает (веб-правила выше DPI) |
| IDS/IPS, сканирование | `outputs/continent-final-ids-wan.txt`, `-ids-lan-443.txt`, `configs/continent-ips-user-signatures.txt` | Готово: пользовательские сигнатуры 3900001/3900002 blocked (nmap --version-all и hping SYN); XMAS режет МЭ |
| IDS/IPS, веб-сигнатуры | `outputs/continent-final-ids-wan.txt`, события | Готово |
| Управление только из Management | `outputs/continent-final-management.txt` | Готово |
| GeoIP выключен/включён | `outputs/continent-geoip-{disabled,enabled}.txt` | Готово, с событием `src_country=US` blocked |
| Три статистических представления | `outputs/continent-final-security-statistics.json` | Готово |
| SNMP-оповещения AV | `outputs/continent-final-av-alerts.txt` | Готово: 8 уведомлений итогового прогона |
| SNMP-оповещения IPS | `outputs/continent-final-ips-alerts.txt` | Готово: 5 уведомлений |
| Ложное срабатывание IPS | `outputs/continent-docs-exception*.txt` | Выполнено: Admin200 после исключения, WAN всё ещё блокируется SID4149401 |
| Резервное копирование | `outputs/continent-native-backup.txt` | Свежая зашифрованная копия, штатное восстановление CDC done100; описание и контрольные хеши проверены |
| Kerio | `outputs/kerio-final-*.txt`, `configs/kerio-*.json` | Текущее состояние и ограничения приведены в начале; строка не относится к старому прогону Континента |

## Перед демонстрацией

1. Сейчас включён KERIO, CONTINENT штатно выключен. Для демонстрации Континента сначала штатно выключить Kerio и убедиться в status0, затем запустить Континент. Для возврата — обратный порядок; оба одновременно не запускать.
2. Проверить сессии PNETLab и присоединиться к `/BKS labs/BKS4.unl` под своим `*_pc`. Не создавать второй pod с теми же MAC/IP.
3. Проверить, что работает только одна из платформ Kerio/Континент. Не применять Stop/Destroy Lab или Wipe.
4. На ADMIN-LINUX проверить `ip route get 10.1.99.1` и доступность Management. Недоступность адреса самого шлюза не считается успешным тестом ограничения управления. После остановки/смены NGFW проверить, что TAP тестовых машин остались присоединены к своим мостам: при их пересоздании встречалась потеря привязки. Для текущего pod есть защищённый проверками `tools/repair-bks4-links.py`; сначала сверить node session через API и выполнить его без `--apply`.
5. Проверять трафик с рабочих адресов, а не через служебный OOB. OOB используется для администрирования и сбора файлов.
6. Использовать отдельные адреса для ролей: Guest — `10.1.10.42`, Admin — `10.1.99.10`. Не менять роли подряд на одном IP без штатного logout.
## Независимые проверки мониторинга на ADMIN-LINUX

```bash
bash ~/check-alert-services.sh
sudo python3 ~/summarize-security-log.py --output /home/labadmin/bks4-security-statistics.json
```

Прямой `check-icap.sh` проверяет backend ICAP: контрольный файл — 204, EICAR и ZIP — вложенный HTTP 403. Это **не** гостевой HTTP через NGFW. Проверку доставки запускают с UTC-меткой до начала нового теста:

```bash
sudo python3 ~/check-alert-delivery.py --component AV --since '<UTC-время начала теста>' --output /home/labadmin/av-alert-delivery.txt
```

Для IPS используется `--component IPS` после реального события на шлюзе. Проверочный скрипт не генерирует детекты и не выдаёт старые записи за свежие. Уведомление отправляет внешний монитор `10.1.99.10`; native LinkUp от `10.1.99.1` не подтверждает IPS/AV.

## После восстановления Management

- Повторить базовые проверки `commands/check-base-policy.sh` на LAN/WAN/Admin/DMZ с рабочим источником.
- Для IPS сначала разрешённый HTTP к собственному опубликованному DMZ, затем ограниченный тест из `commands/check-ids-web.sh wan`. Сопоставить время, SID, адреса и action в syslog; отдельно проверить полученный SNMP payload.
- GeoIP проверять только к своему `192.168.100.2:8080/8443` с привязкой эмулированного RU/US источника. Публичные адреса здесь — источники, а не внешние цели сканирования.
- Ложное срабатывание `/docs?topic=/etc/passwd` разобрано: правило `BKS4-Admin-Docs-IPS-Exception` обходит IPS только для `10.1.99.10 → 192.168.100.2:8080`. После Admin200, WANtimeout+SID4149401blocked. Исключение охватывает весь этот HTTP-сервис доверенного АРМ; сигнатура глобально не отключена.
- Испытание восстановления выполнено со свежей копией после интеграции: изменено только описание BKS4_WAN_TEST, восстановлен CDC, задача done100[], описание вернулось, хеши20FW/4NAT/10сетевых объектов/75сервисов совпали. После восстановленной политики выполнены сетевые и AV-проверки. Старый диск/копию до командной работы не восстанавливать.

## Разбор подтверждённого IPS-события

В `outputs/continent-ips-events.txt` событие `2026-11-06 17:43:01` (UTC) относится к источнику `192.168.100.1:60596`, цели `10.1.50.10:80`, SID `4109359`, сигнатуре Nmap HTTP User-Agent и действию `blocked`. Входящий опубликованный порт — `192.168.100.2:8080`, внутренний адрес виден после DNAT. Это лабораторный тест строки User-Agent, а не доказательство блокировки произвольного портового сканирования.

Критерий готовности к защите: единый актуальный прогон применимых тестов, клиентский результат и соответствующее нативное событие с совпадающими временем/источником. Незавершённые и отложенные этапы должны остаться явно отмеченными.
