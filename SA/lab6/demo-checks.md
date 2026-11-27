# СА №6, вариант 6 — демонстрация

В PNETLab открыть Running Labs → SA6 → Join сессии15 (`vlad_pc`).
Открыть VNC WORKSTATION. Это отдельная рабочая станция; окно Tryton
выполняется на APPS. Не создавать второй pod этой лабы с pnet0.

## Xpra и Tryton

Открыт Tryton от Alice, справочник Party → Parties, запись SA6 Project.
Если окна нет, в терминале WORKSTATION:

```sh
sudo systemctl start sa6-xpra-client
```

Для отключения и возврата выполнить по одной команде:

```sh
sudo systemctl stop sa6-xpra-client
sudo systemctl start sa6-xpra-client
```

Сервер `sa6-xpra` не останавливать: сохраняемый сеанс находится на APPS.
Проверка сохранения UUID и PID уже записана в `outputs/xpra-reconnect.txt`.

Парольный SSH: `ssh alice@apps.sa6.test` разрешён, `ssh bob@apps.sa6.test`
отклоняется AllowGroups. Прикладной вход Tryton проверяется отдельно:
Alice разрешена, Bob с правильным LDAP-паролем получает HTTP401.

## NFS

В терминале WORKSTATION:

```sh
sudo -u alice cat /mnt/team/sa6-report.txt
sudo -u bob cat /mnt/team/sa6-report.txt
echo $?
sudo cat /mnt/team/sa6-report.txt
echo $?
```

Ожидаются содержимое общего файла у Alice и Permission denied у Bob
и root клиента; оба отказа возвращают код1.

## SSO

В браузере WORKSTATION открыть `https://git.sa6.test/`, выбрать Sign in with
Keycloak и войти как alice. Затем в том же профиле браузера открыть
`https://vault.sa6.test/`, указать `alice@sa6.test` и выбрать Use single sign-on.
При живом сеансе Keycloak повторный LDAP-пароль не требуется. Vaultwarden
отдельно запрашивает мастер-пароль для расшифровки хранилища.

Если Gitea или Vaultwarden уже авторизованы, выйти только из приложений.
Не удалять cookies Keycloak. Истёкший сеанс сначала восстановить входом
в Gitea, затем повторить второе приложение.

В Alice видны Shared и Private. Во втором приватном браузере Bob
(`bob@sa6.test`) видна только Shared. На сервере проверены запрет чтения
Private и запрет изменения Shared: `outputs/vaultwarden-rights.txt`.
Роли участников показаны в Admin Console → SA6 Team → Members.

Keycloak: `https://auth.sa6.test/admin/master/console/`, realm sa6,
User federation → sa6-ldap и Clients → gitea/vaultwarden.

## Учётные данные и службы

LDAP-пароли находятся только на ВМ в root-файле
`/root/sa6-private/directory-credentials.json`. На WORKSTATION мастер-пароли
Vaultwarden и пароль администратора Keycloak находятся в
`/root/sa6-private/browser-credentials.json`. Открывать локально через
`sudo less`, не выводить в снимках для отчёта и не переносить в репозиторий.
Администратор Keycloak: `labadmin`.

Основные службы: DIRECTORY — slapd/nfs-server; APPS — sssd/tryton-server/
sa6-xpra/postgresql; WEB — nginx и контейнеры sa6-keycloak/sa6-vaultwarden/
sa6-gitea/sa6-db; WORKSTATION — sssd/lightdm/sa6-xpra-client.

Топология сохранена в `stand/`; гостевые диски находятся в рабочей сессии.
Настроенные образы QEMU не публиковались.
