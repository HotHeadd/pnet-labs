# БКС4 — проверки прямыми командами

Гайд по устройству стенда — [HUMAN.md](HUMAN.md). Ниже команды для ввода в консолях; каждый опыт показывается вместе с результатом и соответствующим событием NGFW.

## Подготовка

Присоединиться через Join к `/BKS labs/BKS4.unl`, session 9/pod 7. Проверить, какой NGFW включён: Kerio и Континент имеют одинаковые адреса, работают поочерёдно. Для переключения сначала штатно выключить текущую ОС и проверить status 0. Не применять Stop Lab, Destroy или Wipe.

Проверять рабочие источники: Guest — LAN-CLIENT 10.1.10.42, Admin — ADMIN-LINUX 10.1.99.10; OOB используется только для обслуживания. После переключения проверить Management и привязки TAP. В Континенте заново войти гостем и администратором через портал auth.bks4.test. В Kerio роли определяются автоматически по IP.

## Разрешённый HTTP и запрещённые направления

На LAN-CLIENT:

```sh
ip route get 10.1.50.10
curl --noproxy '*' --interface 10.1.10.42 -sS -m 5 http://10.1.50.10/allowed.txt
curl --noproxy '*' --interface 10.1.10.42 -sS -m 5 http://192.168.100.1/allowed.txt
timeout 5 nc -s 10.1.10.42 -vz 10.1.50.10 22
echo $?
```

Оба HTTP-запроса возвращают текст контрольного файла. SSH ограничен таймаутом; 124 означает истечение времени ожидания. На DMZ-WEB проверить другое запрещённое направление:

```sh
timeout 5 nc -s 10.1.50.10 -vz 10.1.10.42 22
echo $?
```

На ADMIN-LINUX проверить, что сам SSH-сервис доступен администратору:

```sh
nc -s 10.1.99.10 -vz -w 3 10.1.50.10 22
```

## Публикация и управление

На WAN-TEST:

```sh
curl --noproxy '*' --interface 192.168.100.1 -sS -m 5 http://192.168.100.2:8080/allowed.txt
curl --noproxy '*' --interface 192.168.100.1 -ksS -m 5 https://192.168.100.2:8443/allowed.txt
```

Для Kerio сравнить WebAdmin 4081 из WAN и Management:

```sh
# WAN-TEST: таймаут
curl --noproxy '*' --interface 192.168.100.1 -ksS -m 5 -o /dev/null -w 'HTTP=%{http_code}\n' https://192.168.100.2:4081/admin/
# ADMIN-LINUX: ответ WebAdmin
curl --noproxy '*' --interface 10.1.99.10 -ksS -m 5 -o /dev/null -w 'HTTP=%{http_code}\n' https://10.1.99.1:4081/admin/
```

У Континента проверить TCP444 из Management, LAN и WAN командой nc с соответствующим `-s`. Открытый порт ещё не доказывает успешную аутентификацию. На ADMIN-LINUX можно прочитать API через curl с ГОСТ-движком из установленной официальной c4_lib:

```sh
umask 077
export OPENSSL_ENGINE_PATH="$HOME/bks4-c4/c4_lib"
export OPENSSL_CONF="$OPENSSL_ENGINE_PATH/openssl.cnf"
curl --noproxy '*' --interface 10.1.99.10 --user admin -ksS -m 10 -o /tmp/bks4-api.private.json -w 'HTTP=%{http_code}\n' https://10.1.99.1:444/api-v1-objects/config
jq -M '{configurations:(.data|length)}' /tmp/bks4-api.private.json
rm /tmp/bks4-api.private.json
```

Пароль curl запросит отдельно без отображения. Перед записью ответа выполнить `umask 077`, сам ответ целиком в отчёт не печатать: конфигурация может содержать закрытые данные.

## Антивирус

На LAN-CLIENT поочерёдно выполнить curl с теми же параметрами для allowed.txt, eicar.com и eicar.zip:

```sh
curl --noproxy '*' --interface 10.1.10.42 -sS -m 5 -o /dev/null -w 'HTTP=%{http_code} bytes=%{size_download}\n' http://10.1.50.10/eicar.com
curl --noproxy '*' --interface 10.1.10.42 -sS -m 5 -o /dev/null -w 'HTTP=%{http_code} bytes=%{size_download}\n' http://10.1.50.10/eicar.zip
curl --noproxy '*' --interface 10.1.10.42 -ksS -m 5 -o /tmp/eicar-https -w 'HTTPS=%{http_code} bytes=%{size_download}\n' https://10.1.50.10/eicar.com
sha256sum /tmp/eicar-https
```

Континент возвращает 403 для HTTP EICAR/ZIP. Kerio сбрасывает соединение с 0 байт тела; один HTTP200 не означает передачу файла. HTTPS без TLS-инспекции передаёт 68 байт. Сопоставить с нативным AV-событием.

## IRC и BitTorrent

С ADMIN-LINUX и LAN-CLIENT отправить IRC-регистрацию на 6667 и 16667 с рабочим источником. Имя nick должно быть уникальным и коротким:

```sh
printf 'NICK a6667\r\nUSER bks4 0 * :lab\r\nPING :bks4\r\n' | timeout 8 nc -s 10.1.99.10 192.168.100.1 6667 | sed -n '/ 001 /p;/PONG/p'
```

Ответ 001 подтверждает регистрацию. Для гостя заменить источник на 10.1.10.42 и nick; повторить на 16667. Отсутствие ответа сопоставить с пользовательским запретом в журнале.

BitTorrent проверять программой transmission-cli с private-торрентом собственного WAN-TEST, отдельно для 6881 и 16881. В отдельном каталоге настроек задать bind-address-ipv4 рабочего источника, выключить DHT/PEX/LPD/uTP и port forwarding. Получить harmless-<порт>.torrent через curl, запустить клиент с `-g <каталог настроек> -w <каталог загрузки> -M -et <торрент>` под timeout. У администратора появляется harmless.txt (3407872 байта), у гостя каталог пуст. Точные команды каждого опыта сохранены в `commands/direct-*-bt-*.txt`; это текст команд, не исполняемый сценарий.

## IDS/IPS

На WAN-TEST выполнить ограниченное сканирование только собственного NGFW:

```sh
sudo nmap -Pn -n -sS -sV --max-retries 1 --host-timeout 25s -p 22,443,8080,8443 192.168.100.2
```

Сначала проверить allowed.txt, затем отправить SQL-признак:

```sh
curl --noproxy '*' --interface 192.168.100.1 -sS -m 5 'http://192.168.100.2:8080/weblinks-categories?id=1%20union%20select%20password'
```

На Kerio дождаться штатного IPS Startup, последнего среди событий движка не менее 8 секунд. `enabled` или UpdateOk не заменяют готовность движка. На прямом LAN→DMZ Kerio возвращает 404 без IPS-детекта; этот путь не объявлять защищённым IPS.

На Континенте дополнительно:

```sh
sudo hping3 -q -I ens3 -a 192.168.100.1 -F -P -U -p 8080 -c 12 -i u50000 192.168.100.2
sudo hping3 -q -I ens3 -a 192.168.100.1 -S -p 8080 -c 120 -i u10000 192.168.100.2
```

XMAS может отсечь обычный МЭ раньше СОВ. Для утверждения IPS-блокировки показать SID, действие и время соответствующего события.

## Журналы и доставка уведомлений

На ADMIN-LINUX читать настоящий журнал, а не печатать сохранённую сводку. Например, для событий Kerio за 19.11.2026:

```sh
sudo grep -a '2026-11-19.*IPS: Packet drop' /var/log/bks4/10.1.99.1/events.log | tail -n 1 | fold -s -w 65
sudo grep '2018289' /var/log/bks4/snmp-traps.log | grep '2026-11-19' | tail -n 1 | fold -s -w 95
```

Для нового опыта заменить дату и SID на фактические. У Континента искать APP-NAME suricata и нужный signature_id. AV Континента сопоставлять также с журналом c-icap. Отправитель AV/IPS-уведомлений — внешний монитор 10.1.99.10; LinkUp не заменяет сообщение об атаке.

## GeoIP

Только на изолированном WAN-TEST:

```sh
sudo ip addr replace 5.255.255.5/32 dev lo
sudo ip addr replace 8.8.8.8/32 dev lo
curl --noproxy '*' --interface 5.255.255.5 -sS -m 5 http://192.168.100.2:8080/allowed.txt
curl --noproxy '*' --interface 8.8.8.8 -sS -m 5 http://192.168.100.2:8080/allowed.txt
```

При включённом запрете US источник RU проходит, US получает таймаут. Для сравнения off/on изменять правило штатно и затем возвращать исходное включённое состояние. Сохранённые результаты прежних дат не выдавать за новый прогон.
