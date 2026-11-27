#!/usr/bin/env python3
"""pnet-helper.py с таймаутами для нестабильного канала SA6.

Аргументы те же, что у tools/pnet-helper.py. Настройки применяются только
к этому процессу; общий MCP-клиент не меняется.
"""
import functools
import importlib.util
from pathlib import Path
import httpx
import websockets

websockets.connect = functools.partial(websockets.connect,
    open_timeout=45, ping_interval=None, close_timeout=5)
source = Path(__file__).resolve().parents[3] / 'tools/pnet-helper.py'
spec = importlib.util.spec_from_file_location('helper', source)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
original = helper.client


def client():
    result = original()
    result._client.timeout = httpx.Timeout(45)
    return result


helper.client = client
helper.main()
