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
LAB = "/BKS labs/BKS4.unl"

async def main():
    async with h.client() as c:
        action = sys.argv[1]
        if action == "inventory":
            print(json.dumps(await c.list_labs(), ensure_ascii=False))
            print(json.dumps(await c.get_template("linux"), ensure_ascii=False))
        elif action == "create":
            print(await c.create_lab("BKS4", "/BKS labs", description="Kerio Control and Continent 4.2.1; UTM/NGFW; BKS variant 6", author="Dotsenko, Dzyuba, Martyushev, Goryachev"))
        elif action == "topology":
            t=await c._topology(LAB)
            print(json.dumps({k:t.get(k) for k in ["nodes","networks","labinfo"]}, ensure_ascii=False))
        elif action == "hosts":
            await c._ensure_lab(LAB)
            nodes=await c.list_nodes(LAB); names={n['name'] for n in nodes.values()}
            tpl=await c.get_template("linux")
            for j,(name,net) in enumerate([("LAN-CLIENT","LAN"),("DMZ-WEB","DMZ"),("WAN-TEST","WAN"),("ADMIN-LINUX","Management")]):
                if name in names:continue
                b={k:v for k,v in tpl.items() if v is not None}
                b.update(type="qemu",template="linux",image="linux-bks4-"+name.lower(),name=name,ethernet=2,ram=3072 if name=="ADMIN-LINUX" else 1024,cpu=1,console="telnet",left=str(150+j*240),top="570",count=1,postfix=0,qemu_options="-machine type=pc,accel=kvm -vga std -usbdevice tablet -boot c -cpu host")
                await c._api_post("/api/labs/session/nodes/add",b)
            nodes=await c.list_nodes(LAB); ids={n['name']:int(n['id']) for n in nodes.values()}
            nets=await c.list_networks(LAB);ni={n['name']:int(n['id']) for n in nets.values()}
            for name,net in [("LAN-CLIENT","LAN"),("DMZ-WEB","DMZ"),("WAN-TEST","WAN"),("ADMIN-LINUX","Management")]:
                await c._api_post("/api/labs/session/interfaces/edit",{"node_id":ids[name],"data":{"0":ni[net],"1":ni["OOB"]}})
                print(name,ids[name])
        elif action == "layout":
            await c._ensure_lab(LAB)
            for ident,left,top in [(1,470,40),(2,470,290),(3,150,290),(4,820,490)]:
                await c._api_post("/api/labs/session/networks/edit",{"id":ident,"left":left,"top":top})
            print("Network positions updated")
        elif action in ["start", "stop"]:
            node=int(sys.argv[2])
            print(await (c.start_node(LAB,node) if action=="start" else c.stop_node(LAB,node)))
        elif action == "download":
            name, data = await c.download_lab(LAB)
            dest = ROOT / "BKS/lab4/stand" / pathlib.Path(name).name
            dest.write_bytes(data)
            print(dest)
        elif action == "build":
            await c._ensure_lab(LAB)
            if await c.list_nodes(LAB):
                raise RuntimeError("Lab already contains nodes; refusing to duplicate them")
            template = await c.get_template("linux")
            specs = [("KERIO", "kerio", "kerio-bks4-10.0.1",4,4096,2,"virtio-net-pci",450,160),
                     ("CONTINENT", "linux", "linux-bks4-continent-ncc",4,8192,2,"vmxnet3",700,160)]
            for name, tpl, image, eth, ram, cpu, nic, left, top in specs:
                template=await c.get_template(tpl)
                body={k:v for k,v in template.items() if v is not None}
                body.update(type="qemu",template=tpl,image=image,name=name,ethernet=eth,ram=ram,cpu=cpu,
                            console="vnc",left=str(left),top=str(top),count=1,postfix=0,qemu_nic=nic,
                            qemu_version="4.1.0",qemu_arch="x86_64",
                            qemu_options="-machine type=pc,accel=kvm -vga std -usbdevice tablet -boot c -cpu host")
                await c._api_post("/api/labs/session/nodes/add",body)
            nodes=await c.list_nodes(LAB); ids={n['name']:int(n['id']) for n in nodes.values()}
            for j,name in enumerate(["WAN","LAN","DMZ","Management","OOB"]):
                await c._api_post("/api/labs/session/networks/add",dict(name=name,type="pnet0" if name=="OOB" else "bridge",left=180+j*180,top=380,visibility=1,postfix=0))
            nets=await c.list_networks(LAB); ni={n['name']:int(n['id']) for n in nets.values()}
            for name in ids:
                await c._api_post("/api/labs/session/interfaces/edit",{"node_id":ids[name],"data":{str(i):ni[n] for i,n in enumerate(["WAN","LAN","DMZ","Management"])}})
            print("Topology connected")

asyncio.run(main())
