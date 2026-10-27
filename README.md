# Отчёты по лабам в PNETLab (typst)

```
mephi-labs/   — шаблон @local/mephi-lab:0.1.0 (титульник лабы + оформление НИР, ГОСТ 7.32)
new-lab.sh    — создать папку новой лабы из заготовки
Makefile      — собрать все отчёты / один / watch
lab1/ ...     — отчёты: main.typ, img/, configs/, outputs/
```

## Установка на Mac (один раз)

```sh
brew install typst
cd ~/projects/pnet-labs
./mephi-labs/install.sh
```

Шрифт Times New Roman на macOS уже есть, `fonts/` нужна только на Linux.
Пакет `modern-g7-32` typst скачает сам при первой сборке.

## Работа

```sh
./new-lab.sh lab1          # или bks/lab1, sa/lab2 — подпапки по предметам тоже работают
make watch-lab1            # пересборка при сохранении (или превью в Tinymist)
make                       # собрать все отчёты
```

В лабе:

| Папка      | Что класть                                  | Как вставлять |
|------------|---------------------------------------------|---------------|
| `img/`     | скриншоты, схема топологии                  | `#figure(image("img/x.png"), caption: [...]) <fig-x>` |
| `configs/` | `show running-config` устройств (`R1.txt`)  | `#device-config("R1", read("configs/R1.txt")) <lst-r1>` |
| `outputs/` | вывод show/ping/traceroute                  | `#cli-output("R1", "show ip route", read("outputs/R1-route.txt"))` |

`cli-output` печатает шрифтом 9pt, чтобы широкие таблицы `show` не переносились
(`size: 8pt` — ещё мельче).

## Шаблон

Правки в `mephi-labs/lib/` сразу действуют на все отчёты (пакет поставлен симлинком).
`mephi-labs/template/` копируется только при создании новой лабы.

## Инструкции для ИИ-ассистентов

Единый источник правил для любой модели — [AGENTS.md](AGENTS.md).
Перед работой с лабой читать также её `AGENTS.md`: там состояние стенда, решения и журнал.
`CLAUDE.md` служит только указателем для совместимости и не содержит отдельных правил.
Подключение клиентов к общему MCP описано в [TEAM.md](TEAM.md).
