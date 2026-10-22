#!/usr/bin/env python3
"""Что MCP pnetlab не умеет: qemu-узлы с опциями шаблона, облака (pnet0), набор в VNC-консоли с Shift.

Запускать python'ом из venv MCP-сервера (там httpx/websockets и сам клиент):
  ~/mcp/pnetlab-mcp-server/.venv/bin/python tools/pnet-helper.py <команда> ...
Логин берётся из конфига Claude Desktop (mcpServers.pnetlab.env) — не копировать.
Скрипт логинится тем же аккаунтом, что и MCP, и выбивает его сессию; MCP перелогинится сам.

  add-qemu LAB TEMPLATE IMAGE NAME [--eth N] [--ram MB] [--cpu N] [--console telnet|vnc] [--left X --top Y]
  add-cloud LAB NAME [--type pnet0] [--left X --top Y]
  connect LAB NODE_ID IF_INDEX NETWORK_ID
  edit LAB NODE_ID key=value...  частичная правка узла (nodes/edit; узел остановлен), напр. console=vnc config=1
  type LAB NODE_ID FILE        строки файла набираются в консоли (Enter после каждой), Shift для заглавных и символов
  keys LAB NODE_ID KEY...      отдельные клавиши: Enter, Tab, Esc, Up, Down, Left, Right, Del, BackSpace, F1..F12,
                               ctrl-alt-del, ctrl-<c>, win-<c>, alt-<c>|alt-<Key>
  shot LAB NODE_ID OUT.png     скриншот консоли (без ввода)
"""
import argparse
import asyncio
import json
import os
import sys

CFG = os.path.expanduser("~/Library/Application Support/Claude/claude_desktop_config.json")
sys.path.insert(0, os.path.expanduser("~/mcp/pnetlab-mcp-server/src"))

from pnetlab_mcp_server.client import PNetLabClient, _guac_instr  # noqa: E402
from pnetlab_mcp_server.guac_screen import GuacScreen, parse_instructions  # noqa: E402

SHIFTED = set('~!@#$%^&*()_+{}|:"<>?') | set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
SHIFT_L = 0xFFE1
CTRL_L = 0xFFE3
ALT_L = 0xFFE9
SUPER_L = 0xFFEB
KEYS = {
    "Enter": 0xFF0D, "Tab": 0xFF09, "Esc": 0xFF1B, "BackSpace": 0xFF08, "Del": 0xFFFF,
    "Super": 0xFFEB, "Up": 0xFF52, "Down": 0xFF54, "Left": 0xFF51, "Right": 0xFF53, "Home": 0xFF50, "End": 0xFF57,
    **{f"F{i}": 0xFFBE + i - 1 for i in range(1, 13)},
}


def client() -> PNetLabClient:
    env = json.load(open(CFG))["mcpServers"]["pnetlab"]["env"]
    return PNetLabClient(
        base_url=env["PNETLAB_HOST"],
        username=env["PNETLAB_USERNAME"],
        password=env["PNETLAB_PASSWORD"],
        html_console=int(env.get("PNETLAB_HTML_CONSOLE", "1")),
        verify_ssl=env.get("PNETLAB_VERIFY_SSL", "true").lower() == "true",
    )


async def add_qemu(c: PNetLabClient, a) -> None:
    await c._ensure_lab(a.lab)
    body = {k: v for k, v in (await c.get_template(a.template)).items() if v is not None}
    body.update(
        type="qemu", template=a.template, image=a.image, name=a.name, ethernet=a.eth, ram=a.ram,
        cpu=a.cpu, console=a.console, left=str(a.left), top=str(a.top), count=1, postfix=0,
    )
    res = await c._api_post("/api/labs/session/nodes/add", body)
    nodes = res.get("nodes", {}) if isinstance(res, dict) else {}
    new = max(nodes.values(), key=lambda n: int(n["id"])) if nodes else res
    print(json.dumps({k: new.get(k) for k in ("id", "name", "image", "ram", "console", "qemu_options")}
                     if isinstance(new, dict) else new, ensure_ascii=False))


async def add_cloud(c: PNetLabClient, a) -> None:
    await c._ensure_lab(a.lab)
    res = await c._api_post("/api/labs/session/networks/add", {
        "name": a.name, "type": a.type, "left": a.left, "top": a.top, "visibility": 1, "postfix": 0})
    nets = res.get("networks", {}) if isinstance(res, dict) else {}
    print(json.dumps(max(nets.values(), key=lambda n: int(n["id"])) if nets else res, ensure_ascii=False))


async def connect(c: PNetLabClient, a) -> None:
    await c._ensure_lab(a.lab)
    await c._api_post("/api/labs/session/interfaces/edit",
                      {"node_id": a.node, "data": {str(a.iface): a.network}})
    eth = (await c.get_node(a.lab, a.node)).get("ethernets", {}).get(str(a.iface), {})
    print(json.dumps({"node": a.node, "if": a.iface, "network_id": eth.get("network_id")}))


async def edit(c: PNetLabClient, a) -> None:
    await c._ensure_lab(a.lab)
    body = {"id": a.node, **dict(kv.split("=", 1) for kv in a.fields)}
    await c._api_post("/api/labs/session/nodes/edit", body)
    node = await c.get_node(a.lab, a.node)
    links = {e["name"]: e.get("network_id") for e in node.get("ethernets", {}).values()}
    print(json.dumps({**{k: node.get(k) for k in body}, "links": links}, ensure_ascii=False))


async def _session(c: PNetLabClient, lab: str, node: int, actions, shot: str | None = None) -> None:
    await c._ensure_lab(lab)
    ws = await c._open_console_ws(node)
    screen = GuacScreen(1024, 768)
    left = ""

    async def pump() -> None:
        nonlocal left
        try:
            async for msg in ws:
                m = msg if isinstance(msg, str) else msg.decode("utf-8", "replace")
                instrs, left = parse_instructions(left + m)
                for ins in instrs:
                    if ins and ins[0] == "sync":
                        await ws.send(_guac_instr(*ins))
                    screen.handle(ins)
        except Exception:
            pass

    async def press(sym: int, mods=()) -> None:
        for m in mods:
            await ws.send(_guac_instr("key", m, 1))
        await ws.send(_guac_instr("key", sym, 1))
        await ws.send(_guac_instr("key", sym, 0))
        for m in reversed(mods):
            await ws.send(_guac_instr("key", m, 0))
        await asyncio.sleep(0.03)

    reader = asyncio.create_task(pump())
    try:
        await asyncio.sleep(2.5)
        await actions(press)
        await asyncio.sleep(3.0)
    finally:
        reader.cancel()
        await ws.close()
    if shot:
        open(shot, "wb").write(screen.png())
        print(shot)


async def type_file(c: PNetLabClient, a) -> None:
    lines = open(a.file, encoding="utf-8").read().splitlines()

    async def act(press) -> None:
        for line in lines:
            for ch in line:
                sym = ord(ch) if ord(ch) < 0x100 else 0x01000000 + ord(ch)  # X11: Unicode keysym
                await press(sym, (SHIFT_L,) if ch in SHIFTED else ())
            await press(KEYS["Enter"])
            await asyncio.sleep(a.per_line)

    await _session(c, a.lab, a.node, act, a.shot)


async def keys(c: PNetLabClient, a) -> None:
    async def act(press) -> None:
        for k in a.keys:
            if k == "ctrl-alt-del":
                await press(KEYS["Del"], (CTRL_L, ALT_L))
            elif k.startswith("ctrl-shift-"):
                await press(ord(k[11:]), (CTRL_L, SHIFT_L))
            elif k.startswith("ctrl-"):
                await press(ord(k[5:]), (CTRL_L,))
            elif k.startswith("win-"):
                await press(ord(k[4:]), (SUPER_L,))
            elif k.startswith("alt-"):
                await press(ord(k[4:]) if len(k) == 5 else KEYS[k[4:]], (ALT_L,))
            else:
                await press(KEYS[k])
            await asyncio.sleep(0.5)

    await _session(c, a.lab, a.node, act, a.shot)


async def shot(c: PNetLabClient, a) -> None:
    async def act(press) -> None:
        pass

    await _session(c, a.lab, a.node, act, a.out)


def main() -> None:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    q = sub.add_parser("add-qemu")
    for n in ("lab", "template", "image", "name"):
        q.add_argument(n)
    q.add_argument("--eth", type=int, default=1)
    q.add_argument("--ram", type=int, default=2048)
    q.add_argument("--cpu", type=int, default=1)
    q.add_argument("--console", default="vnc")
    q.add_argument("--left", type=int, default=100)
    q.add_argument("--top", type=int, default=100)
    n = sub.add_parser("add-cloud")
    n.add_argument("lab")
    n.add_argument("name")
    n.add_argument("--type", default="pnet0")
    n.add_argument("--left", type=int, default=100)
    n.add_argument("--top", type=int, default=100)
    k = sub.add_parser("connect")
    k.add_argument("lab")
    k.add_argument("node", type=int)
    k.add_argument("iface", type=int)
    k.add_argument("network", type=int)
    t = sub.add_parser("type")
    t.add_argument("lab")
    t.add_argument("node", type=int)
    t.add_argument("file")
    t.add_argument("--per-line", type=float, default=0.7)
    t.add_argument("--shot")
    y = sub.add_parser("keys")
    y.add_argument("lab")
    y.add_argument("node", type=int)
    y.add_argument("keys", nargs="+")
    y.add_argument("--shot")
    e = sub.add_parser("edit")
    e.add_argument("lab")
    e.add_argument("node", type=int)
    e.add_argument("fields", nargs="+", help="key=value, напр. console=vnc config=1")
    s = sub.add_parser("shot")
    s.add_argument("lab")
    s.add_argument("node", type=int)
    s.add_argument("out")
    a = p.parse_args()

    async def run() -> None:
        c = client()
        try:
            await c.login()
            await {"add-qemu": add_qemu, "add-cloud": add_cloud, "connect": connect, "edit": edit,
                   "type": type_file, "keys": keys, "shot": shot}[a.cmd](c, a)
        finally:
            await c.close()

    asyncio.run(run())


if __name__ == "__main__":
    main()
