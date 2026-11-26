#!/usr/bin/env python3
"""Создать узлы и сети в предварительно созданной пустой лабе SA6."""
import asyncio
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('helper', REPO / 'tools/pnet-helper.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
LAB = '/SA labs/SA6.unl'


async def main():
    c = helper.client()
    try:
        await c.login()
        lab = await c._topology(LAB)
        if lab.get('nodes') or lab.get('networks'):
            raise SystemExit('Лаба не пустая: автоматическое создание отменено')
        for name, ram, cpu, left, top in [
            ('directory', 1024, 1, 150, 100),
            ('apps', 2560, 2, 450, 100),
            ('web', 4096, 2, 750, 100),
            ('workstation', 2048, 2, 450, 450)]:
            await helper.add_qemu(c, SimpleNamespace(
                lab=LAB, template='linux', image='linux-sa6-' + name,
                name=name.upper(), eth=2, ram=ram, cpu=cpu,
                console='vnc', left=left, top=top))
        for name, kind, left, top in [
            ('SA6-LAN 10.60.0.0/24', 'bridge', 450, 280),
            ('MGMT pnet0', 'pnet0', 850, 450)]:
            await helper.add_cloud(c, SimpleNamespace(
                lab=LAB, name=name, type=kind, left=left, top=top))
        lab = await c._topology(LAB)
        networks = list(lab['networks'].values()) if isinstance(lab['networks'], dict) else lab['networks']
        lan = next(int(n['id']) for n in networks if n['type'] == 'bridge')
        mgmt = next(int(n['id']) for n in networks if n['type'] == 'pnet0')
        nodes = list(lab['nodes'].values()) if isinstance(lab['nodes'], dict) else lab['nodes']
        for node in nodes:
            await helper.connect(c, SimpleNamespace(lab=LAB, node=int(node['id']), iface=0, network=lan))
            await helper.connect(c, SimpleNamespace(lab=LAB, node=int(node['id']), iface=1, network=mgmt))
    finally:
        await c.close()


if __name__ == '__main__':
    asyncio.run(main())
