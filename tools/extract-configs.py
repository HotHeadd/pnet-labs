"""Достаёт startup-config IOL-нод из .unl (из zip-выгрузки PNETLab) и чистит их для отчёта.

Использование: python tools/extract-configs.py <лаба.unl> <папка-лабы>/configs
(.unl — распаковать из stand/pnetlab_export-*.zip во временную папку)
"""
import base64
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

unl, out = Path(sys.argv[1]), Path(sys.argv[2])
root = ET.parse(unl).getroot()
names = {n.get("id"): (n.get("name"), n.get("type")) for n in root.iter("node")}
out.mkdir(parents=True, exist_ok=True)

SKIP = re.compile(r"^(!\s*|! Last configuration change.*|boot-start-marker|boot-end-marker|"
                  r"version 15\.\d|mmi .*|no mmi .*|redundancy|multilink bundle-name authenticated|"
                  r"no cdp log mismatch duplex|service timestamps .*|no service password-encryption|"
                  r"service compress-config|ip tcp synwait-time 5|no ip icmp rate-limit unreachable|"
                  r"vlan internal allocation policy ascending|control-plane|"
                  r"ip forward-protocol nd|no ip http server|no ip http secure-server|no aaa new-model|"
                  r"no ipv6 cef|line aux 0|end)$")


def clean(text: str) -> str:
    blocks, cur = [], []
    for line in text.replace("\r", "").split("\n"):
        if line and not line.startswith(" "):
            if cur:
                blocks.append(cur)
            cur = [line]
        elif line.strip():
            cur.append(line)
    if cur:
        blocks.append(cur)
    res = []
    for b in blocks:
        head, body = b[0], b[1:]
        if SKIP.match(head) and not body:
            continue
        if head.startswith("interface "):
            body = [l for l in body if l != " no shutdown"]
            # неиспользуемый порт без настроек (служебный no shutdown PNET) — выкинуть
            if not body or set(body) <= {" no ip address", " shutdown"}:
                continue
        if head.startswith("line aux"):
            continue
        res.append("\n".join([head] + body))
    return "\n".join(res) + "\n"


for n in root.iter("node"):
    name, data = n.get("name"), n.get("config_data")
    if n.get("type") != "iol" or not data:
        continue
    raw = base64.b64decode(data).decode("utf-8", "replace")
    (out / f"{name}.txt").write_text(clean(raw), encoding="utf-8", newline="\n")
    print(name)
