#!/usr/bin/env python3
"""Запуск MCP pnetlab под аккаунтом из .pnet-account (креды — tools/pnet_creds.py).

В .mcp.json: "command": "sh", "args": ["tools/pnet-mcp.sh"].
Сменить аккаунт: tools/pnet-helper.py use <аккаунт>, затем в Claude Code /mcp → pnetlab → Reconnect.

Правка поведения MCP (без изменений в самом сервере): открытие лабы (open_lab и повторный вход после выбивания сессии)
не создаёт новую сессию через factory/create, если аккаунт уже привязан к сессии этой лабы — своей или присоединённой
через Join (pnet-helper.py join). Иначе MCP уводил бы присоединённый аккаунт в отдельный пустой pod.
"""
import logging
import os
import runpy
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pnet_creds  # noqa: E402

env = pnet_creds.env()
if env is None:
    sys.exit(f"pnet-mcp: нет пароля выбранного аккаунта в {pnet_creds.CREDS} (скопировать mcp-creds.example.json и заполнить) "
             "или не выбран аккаунт (pnet-helper.py use <аккаунт>)")
os.environ.update(env)
sys.path.insert(0, os.path.expanduser(os.environ.get("PNETLAB_MCP_SRC", "~/mcp/pnetlab-mcp-server/src")))

from pnetlab_mcp_server import client as _cl  # noqa: E402

log = logging.getLogger("pnet-mcp")
_create = _cl.PNetLabClient.open_lab


async def _bound_session(self, path: str):
    """id сессии этой лабы, к которой уже привязан аккаунт (/api/auth → lab), или None."""
    sid = (await self._api_get("/api/auth") or {}).get("lab")
    if not sid:
        return None
    for r in await self.list_running_labs():
        if str(r.get("session_id")) == str(sid) and r.get("lab_path") == path:
            return sid
    return None


async def open_lab(self, lab_path: str):
    path = self._normalize_lab_path(lab_path)
    sid = await _bound_session(self, path)
    if sid:
        self._current_lab = path
        log.info("Lab %s: reuse bound session %s", path, sid)
        return {"session": sid, "reused": True}
    return await _create(self, lab_path)


async def _request(self, method: str, path: str, *, retry: bool = True, **kw):
    await self._ensure_auth()
    resp = await self._client.request(method, path, **kw)
    try:
        return self._parse(resp)
    except _cl.PNetLabClientError as exc:
        expired = exc.code in (401, 412) or "90001" in f"{exc.message}{exc.detail}"
        if not (expired and retry):
            raise
        self._authenticated = False
        await self.login()
        if self._current_lab:
            lab, self._current_lab = self._current_lab, None
            await open_lab(self, lab)  # вместо безусловного factory/create
        return self._parse(await self._client.request(method, path, **kw))


_cl.PNetLabClient.open_lab = open_lab
_cl.PNetLabClient._request = _request
runpy.run_module("pnetlab_mcp_server", run_name="__main__")
