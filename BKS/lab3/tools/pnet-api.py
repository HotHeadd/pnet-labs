#!/usr/bin/env python3
"""Запуск операций штатного клиента через репозиторный helper (сохранение Join)."""
import asyncio
import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("pnet_helper", ROOT / "tools/pnet-helper.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
LAB = "/BKS labs/BKS3.unl"

async def main():
    async with h.client() as c:
        action = sys.argv[1]
        if action == "inventory":
            print(json.dumps(await c.list_labs(), ensure_ascii=False))
            print(json.dumps(await c.get_template("linux"), ensure_ascii=False))
        elif action == "create":
            print(await c.create_lab("BKS3", "/BKS labs", description="Linux GRE/IPsec/OSPF and Xray cascade; BKS variant 6", author="Dotsenko, Dzyuba, Martyushev, Goryachev"))
        elif action == "topology":
            t=await c._topology(LAB)
            print(json.dumps({k:t.get(k) for k in ["nodes","networks","labinfo"]}, ensure_ascii=False))
        elif action == "layout":
            await c._ensure_lab(LAB)
            for ident,left,top in [(1,470,40),(2,470,290),(3,150,290),(4,820,490)]:
                await c._api_post("/api/labs/session/networks/edit",{"id":ident,"left":left,"top":top})
            print("Network positions updated")
        elif action == "start":
            print(await c.start_all_nodes(LAB))
        elif action == "download":
            name, data = await c.download_lab(LAB)
            dest = ROOT / "BKS/lab3/stand" / pathlib.Path(name).name
            dest.write_bytes(data)
            print(dest)
        elif action == "build":
            await c._ensure_lab(LAB)
            if await c.list_nodes(LAB):
                raise RuntimeError("Lab already contains nodes; refusing to duplicate them")
            template = await c.get_template("linux")
            specs = [("HQ-GW",3,1024,470,180),("BR-GW",3,1024,150,180),
                     ("HQ-SRV",2,768,470,390),("BR-CLIENT",2,768,150,390),
                     ("XRAY-RELAY",2,768,790,180)]
            for name, eth, ram, left, top in specs:
                body = {k:v for k,v in template.items() if v is not None}
                body.update(type="qemu",template="linux",image="linux-bks3-"+name.lower(),name=name,
                            ethernet=eth,ram=ram,cpu=1,console="telnet",left=str(left),top=str(top),count=1,postfix=0,
                            qemu_options="-machine type=pc,accel=kvm -vga std -usbdevice tablet -boot c -cpu host")
                await c._api_post("/api/labs/session/nodes/add",body)
            nodes=await c.list_nodes(LAB)
            print("Created", len(nodes), "nodes")
            ids={n['name']:int(n['id']) for n in nodes.values()}
            for name in ["WAN", "HQ-LAN", "BR-LAN", "NetManagement"]:
                await c._api_post("/api/labs/session/networks/add",dict(name=name,type="pnet0" if name=="NetManagement" else "bridge",left=450,top=60,visibility=1,postfix=0))
            nets=await c.list_networks(LAB)
            ni={n['name']:int(n['id']) for n in nets.values()}
            links={"HQ-GW":["WAN","HQ-LAN","NetManagement"],"BR-GW":["WAN","BR-LAN","NetManagement"],
                   "HQ-SRV":["HQ-LAN","NetManagement"],"BR-CLIENT":["BR-LAN","NetManagement"],"XRAY-RELAY":["WAN","NetManagement"]}
            for name, ns in links.items():
                await c._api_post("/api/labs/session/interfaces/edit",{"node_id":ids[name],"data":{str(i):ni[n] for i,n in enumerate(ns)}})
            print("Topology connected")

asyncio.run(main())
