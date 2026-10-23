#!/usr/bin/env python3
"""Запуск MCP pnetlab под аккаунтом из .pnet-account (креды — tools/pnet_creds.py).

В .mcp.json: "command": "<venv MCP>/bin/python", "args": ["<репо>/tools/pnet-mcp.py"], без env.
Сменить аккаунт: tools/pnet-helper.py use <аккаунт>, затем в Claude Code /mcp → pnetlab → Reconnect.
"""
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
runpy.run_module("pnetlab_mcp_server", run_name="__main__")
