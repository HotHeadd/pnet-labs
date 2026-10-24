"""Креды MCP-аккаунтов команды для MCP pnetlab и tools/pnet-helper.py.

Файл — $PNETLAB_CREDS, по умолчанию mcp-creds.json в корне репо (в .gitignore; репо публичный — не коммитить):
скопировать mcp-creds.example.json и вписать пароли:  {"host": "http://…", "accounts": {"vlad_pc": "<пароль>", …}}.
Выбранный аккаунт — первая строка .pnet-account в корне репо (pnet-helper.py use <аккаунт>).
Root SSH к хосту — только по ключу (ssh-copy-id), паролей здесь нет.
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREDS = os.environ.get("PNETLAB_CREDS", os.path.join(REPO, "mcp-creds.json"))
ACCOUNT = os.path.join(REPO, ".pnet-account")
_data = json.load(open(CREDS, encoding="utf-8")) if os.path.exists(CREDS) else {}
HOST = os.environ.get("PNETLAB_HOST", _data.get("host", "http://100.100.57.19"))


def accounts() -> dict:
    """{аккаунт: пароль} — только заполненные."""
    return {k: v for k, v in (_data.get("accounts") or {}).items() if v}


def selected() -> str | None:
    if os.path.exists(ACCOUNT):
        return (open(ACCOUNT).read().split() or [None])[0]
    return None


def env() -> dict | None:
    """Переменные окружения MCP для выбранного аккаунта или None."""
    acc = accounts()
    name = selected()
    if not name or name not in acc:
        return None
    return {"PNETLAB_HOST": HOST, "PNETLAB_USERNAME": name, "PNETLAB_PASSWORD": acc[name],
            "PNETLAB_VERIFY_SSL": "false", "PNETLAB_HTML_CONSOLE": "1"}
