#!/usr/bin/env python3
"""Что MCP pnetlab не умеет: qemu-узлы с опциями шаблона, облака (pnet0), набор в VNC-консоли с Shift.

Запускать python'ом из venv MCP-сервера (там httpx/websockets и сам клиент):
  ~/mcp/pnetlab-mcp-server/.venv/bin/python tools/pnet-helper.py <команда> ...
Каталог src MCP-сервера — $PNETLAB_MCP_SRC (по умолчанию ~/mcp/pnetlab-mcp-server/src).
Логин — тот же, что у MCP: переменные PNETLAB_HOST/USERNAME/PASSWORD, иначе аккаунт из .pnet-account с паролем
из файла кредов (tools/pnet_creds.py), иначе mcpServers.pnetlab.env из .mcp.json в корне репо, иначе конфиг Claude Desktop.
Скрипт логинится тем же аккаунтом, что и MCP, и выбивает его сессию; MCP перелогинится сам.

  add-qemu LAB TEMPLATE IMAGE NAME [--eth N] [--ram MB] [--cpu N] [--console telnet|vnc] [--left X --top Y]
  add-cloud LAB NAME [--type pnet0] [--left X --top Y]
  connect LAB NODE_ID IF_INDEX NETWORK_ID
  edit LAB NODE_ID key=value...  частичная правка узла (nodes/edit; узел остановлен), напр. console=vnc config=1
  type LAB NODE_ID FILE        строки файла набираются в консоли (Enter после каждой), Shift для заглавных и символов
  keys LAB NODE_ID KEY...      отдельные клавиши: Enter, Tab, Esc, Up, Down, Left, Right, Del, BackSpace, F1..F12,
                               ctrl-alt-del, ctrl-<c>, win-<c>, alt-<c>|alt-<Key>
  shot LAB NODE_ID OUT.png     скриншот консоли (без ввода)
  push LAB NODE_ID FILE REMOTE  передать файл на Linux-узел через консоль (base64 в heredoc) и проверить md5sum -c
                               (на экране должно быть «REMOTE: OK»; --shot сохраняет скриншот;
                               для VNC-консолей --key-delay 0.05, иначе теряется Shift)

Командная работа (см. TEAM.md): у каждого свой аккаунт, к открытой сессии лабы присоединяются (Join).
  join LAB [--session ID]      присоединить текущий аккаунт к живой сессии лабы (factory/join, как Join в веб-интерфейсе)
  use АККАУНТ                  выбрать аккаунт для MCP (tools/pnet-mcp.py) и хелпера; потом /mcp → Reconnect
  sessions                     открытые сессии сервера: id, лаба, pod, аккаунт, запущено узлов
  close-session ID [--force]   закрыть сессию (pod уничтожается); без --force — только свою и без запущенных узлов
  status LAB                   сессии лабы, образы qemu-узлов (лаба не открывается)
  snapshot LAB NODE_ID [--name БАЗА]  свернуть диск узла своего pod в новый образ БАЗА-vN на хосте (root SSH по ключу,
                               $PNETLAB_SSH или root@<хост>; tools/pnet-host/pnet-snapshot.sh) и перевести узел .unl на него; узел должен быть остановлен
"""
import argparse
import asyncio
import base64
import gzip
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFGS = (os.path.join(REPO, ".mcp.json"),
        os.path.expanduser("~/Library/Application Support/Claude/claude_desktop_config.json"))
sys.path.insert(0, os.path.expanduser(os.environ.get("PNETLAB_MCP_SRC", "~/mcp/pnetlab-mcp-server/src")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pnet_creds  # noqa: E402

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


def _env() -> dict:
    if os.environ.get("PNETLAB_USERNAME"):
        return os.environ
    if env := pnet_creds.env():
        return env
    for cfg in CFGS:
        if os.path.exists(cfg):
            return json.load(open(cfg))["mcpServers"]["pnetlab"]["env"]
    sys.exit("нет логина PNETLab: задать PNETLAB_HOST/USERNAME/PASSWORD или .mcp.json в корне репозитория")


_create = PNetLabClient.open_lab


async def _open_lab(self, lab_path: str):
    """Как в pnet-mcp.py: не уводить аккаунт из присоединённой сессии лабы в свой pod (factory/create)."""
    path = self._normalize_lab_path(lab_path)
    sid = (await self._api_get("/api/auth") or {}).get("lab")
    if sid:
        for r in await self.list_running_labs():
            if str(r.get("session_id")) == str(sid) and r.get("lab_path") == path:
                self._current_lab = path
                return {"session": sid, "reused": True}
    return await _create(self, lab_path)


PNetLabClient.open_lab = _open_lab


def client() -> PNetLabClient:
    env = _env()
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


async def _session(c: PNetLabClient, lab: str, node: int, actions, shot: str | None = None,
                   key_delay: float = 0.03) -> None:
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
        await asyncio.sleep(key_delay)

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


async def _type_lines(c: PNetLabClient, lab: str, node: int, lines, per_line: float, shot: str | None,
                      key_delay: float = 0.03) -> None:
    async def act(press) -> None:
        for line in lines:
            for ch in line:
                sym = ord(ch) if ord(ch) < 0x100 else 0x01000000 + ord(ch)  # X11: Unicode keysym
                await press(sym, (SHIFT_L,) if ch in SHIFTED else ())
            await press(KEYS["Enter"])
            await asyncio.sleep(per_line)

    await _session(c, lab, node, act, shot, key_delay)


async def type_file(c: PNetLabClient, a) -> None:
    lines = open(a.file, encoding="utf-8").read().splitlines()
    await _type_lines(c, a.lab, a.node, lines, a.per_line, a.shot)


async def push(c: PNetLabClient, a) -> None:
    data = open(a.file, "rb").read()
    b64 = base64.b64encode(gzip.compress(data, 9, mtime=0)).decode()
    lines = [f"base64 -d <<'B64' | gunzip > {a.remote}", *(b64[i:i + 76] for i in range(0, len(b64), 76)), "B64",
             f"clear; echo '{hashlib.md5(data).hexdigest()}  {a.remote}' | md5sum -c"]
    await _type_lines(c, a.lab, a.node, lines, a.per_line, a.shot, a.key_delay)
    print(f"{a.remote}: {len(data)} байт, md5 {hashlib.md5(data).hexdigest()}")


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


async def _rows(c: PNetLabClient, what: str) -> list:
    d = await c._api_post(f"/store/public/admin/{what}/filter",
                          {"data": {"page_number": 1, "page_quantity": 500, "page_total": 0, "flag_filter_change": 1}})
    return (d or {}).get("data_table", []) if isinstance(d, dict) else []


async def _sessions(c: PNetLabClient) -> list:
    users = {u.get("pod"): u.get("username") for u in await _rows(c, "users")}
    return [{"id": r["lab_session_id"], "lab": r["lab_session_path"], "pod": r["lab_session_pod"],
             "user": users.get(r["lab_session_pod"]), "running": r["lab_session_running"]}
            for r in await _rows(c, "lab_sessions")]


async def _unl(c: PNetLabClient, lab: str) -> ET.Element:
    # читаем .unl через экспорт: get_lab открыл бы лабу и создал этому аккаунту pod
    for attempt in range(4):
        try:
            _, data = await c.download_lab(lab)
            break
        except Exception:  # «Cannot remove UUID from exported labs (15)» — экспорты чаще раза в секунду
            if attempt == 3:
                raise
            await asyncio.sleep(2)
    zf = zipfile.ZipFile(io.BytesIO(data))
    return ET.fromstring(zf.read(next(n for n in zf.namelist() if n.endswith(".unl"))))


async def sessions(c: PNetLabClient, a) -> None:
    for s in await _sessions(c):
        print(f"{s['id']:>4}  pod {s['pod']:>3}  {s['user'] or '?':<16} узлов {s['running']:>2}  {s['lab']}")


async def close_session(c: PNetLabClient, a) -> None:
    s = next((s for s in await _sessions(c) if s["id"] == a.id), None)
    if not s:
        sys.exit(f"нет сессии {a.id}")
    if not a.force and (s["user"] != c.username or s["running"]):
        sys.exit(f"сессия {a.id}: {s['user']}, узлов {s['running']} — закрывать можно только свою пустую (или --force)")
    print(await c._api_post("/api/labs/session/factory/destroy", {"lab_session": a.id}))


async def status(c: PNetLabClient, a) -> None:
    unl = await _unl(c, a.lab)
    path = c._normalize_lab_path(a.lab)
    for s in await _sessions(c):
        if s["lab"] == path:
            print(f"сессия {s['id']}: pod {s['pod']} {s['user']}, узлов {s['running']}")
    for n in unl.iter("node"):
        if n.get("type") == "qemu":
            print(f"узел {n.get('id')} {n.get('name')}: {n.get('image')}")


def use_account(name: str) -> None:
    accounts = pnet_creds.accounts()
    if name not in accounts:
        sys.exit(f"нет аккаунта {name} в {pnet_creds.CREDS}")
    with open(pnet_creds.ACCOUNT, "w") as f:
        f.write(name + "\n")
    print(f"аккаунт: {name}. В Claude Code: /mcp → pnetlab → Reconnect (MCP через tools/pnet-mcp.py)")


async def join(c: PNetLabClient, a) -> None:
    path = c._normalize_lab_path(a.lab)
    live = [s for s in await _sessions(c) if s["lab"] == path and (s["id"] == a.session if a.session else s["running"])]
    if len(live) != 1:
        sys.exit(f"нужна ровно одна сессия {path}{' с id ' + str(a.session) if a.session else ' с запущенными узлами'}: {live}")
    s = live[0]
    await c._api_post("/api/labs/session/factory/join", {"lab_session": s["id"]})
    me = await c.get_session_info()
    print(f"{c.username}: сессия {me.get('lab')} (автор {s['user']}, pod {s['pod']}, узлов {s['running']})")


async def use(c: PNetLabClient, a) -> None:
    use_account(a.account)


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


async def snapshot(c: PNetLabClient, a) -> None:
    ssh = os.environ.get("PNETLAB_SSH", "root@" + pnet_creds.HOST.split("//")[-1].split(":")[0])  # root SSH по ключу
    lab = c._normalize_lab_path(a.lab)
    node = await c.get_node(lab, a.node)  # открывает лабу: работаем в своём pod
    if int(node.get("status", 0)) != 0:
        sys.exit(f"узел {a.node} запущен — сначала выключить ОС и stop_node")
    session = (await c.get_session_info()).get("lab")
    tmpl = node["template"]
    base = a.name or f"{tmpl}-{_slug(os.path.basename(lab)[:-4])}-{_slug(node['name'])}"
    if not base.startswith(tmpl + "-"):
        sys.exit(f"имя образа должно начинаться с «{tmpl}-»")
    tpl = await c._api_get(f"/api/list/templates/{tmpl}")
    names = list((tpl.get("options", {}).get("image", {}).get("options") or {}))
    ver = max([int(m.group(1)) for i in names if (m := re.fullmatch(re.escape(base) + r"-v(\d+)", str(i)))] or [0]) + 1
    image = f"{base}-v{ver}"
    script = os.path.join(REPO, "tools", "pnet-host", "pnet-snapshot.sh")
    with open(script, "rb") as f:
        r = subprocess.run(["ssh", "-o", "BatchMode=yes", ssh, "sh", "-s", "--", str(session), str(node["session"]),
                            image, base, str(a.keep)], stdin=f)
    if r.returncode:
        sys.exit(f"снимок не сделан (код {r.returncode})")
    await c._api_post("/api/labs/session/nodes/edit", {"id": a.node, "image": image})
    print(json.dumps({"node": a.node, "image": (await c.get_node(lab, a.node)).get("image")}, ensure_ascii=False))


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
    u = sub.add_parser("push")
    u.add_argument("lab")
    u.add_argument("node", type=int)
    u.add_argument("file")
    u.add_argument("remote")
    u.add_argument("--per-line", type=float, default=0.1)
    u.add_argument("--key-delay", type=float, default=0.01)
    u.add_argument("--shot")
    s = sub.add_parser("shot")
    s.add_argument("lab")
    s.add_argument("node", type=int)
    s.add_argument("out")
    sub.add_parser("sessions")
    jn = sub.add_parser("join")
    jn.add_argument("lab")
    jn.add_argument("--session", type=int)
    us = sub.add_parser("use")
    us.add_argument("account")
    x = sub.add_parser("close-session")
    x.add_argument("id", type=int)
    x.add_argument("--force", action="store_true")
    st = sub.add_parser("status")
    st.add_argument("lab")
    sn = sub.add_parser("snapshot")
    sn.add_argument("lab")
    sn.add_argument("node", type=int)
    sn.add_argument("--name")
    sn.add_argument("--keep", type=int, default=2)
    a = p.parse_args()

    async def run() -> None:
        c = client()
        try:
            await c.login()
            await {"add-qemu": add_qemu, "add-cloud": add_cloud, "connect": connect, "edit": edit,
                   "type": type_file, "keys": keys, "shot": shot, "push": push,
                   "sessions": sessions, "close-session": close_session,
                   "status": status, "snapshot": snapshot,
                   "use": use, "join": join}[a.cmd](c, a)
        finally:
            await c.close()

    asyncio.run(run())


if __name__ == "__main__":
    main()
