#!/usr/bin/env python3
"""Создать узлы и сети только в пустой SA7."""
import asyncio
import importlib.util
from pathlib import Path
from types import SimpleNamespace

REPO=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('helper',REPO/'tools/pnet-helper.py')
helper=importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
LAB='/SA labs/SA7.unl'

async def main():
    c=helper.client()
    try:
        await c.login()
        data=await c._topology(LAB)
        if data.get('nodes') or data.get('networks'):
            raise SystemExit('SA7 не пустая, создание отменено')
        for name,ram,cpu,eth,left,top in [('gw',2048,2,3,350,150),
                ('im',6144,4,2,700,150),('rtc',4096,4,2,350,440),
                ('workstation',3072,2,1,50,150)]:
            await helper.add_qemu(c,SimpleNamespace(lab=LAB,template='linux',
                image='linux-sa7-'+name,name=name.upper(),eth=eth,ram=ram,cpu=cpu,
                console='vnc',left=left,top=top))
        for name,kind,left,top in [('EXTERNAL 192.168.15.0/24','pnet0',50,340),
                ('DMZ 10.70.10.0/24','bridge',350,320),
                ('INTERNAL 10.70.20.0/24','bridge',700,320)]:
            await helper.add_cloud(c,SimpleNamespace(lab=LAB,name=name,type=kind,left=left,top=top))
        data=await c._topology(LAB)
        networks={n['name'].split()[0]:int(n['id']) for n in data['networks'].values()}
        mapping={'GW':['DMZ','INTERNAL','EXTERNAL'],'IM':['INTERNAL','EXTERNAL'],
                 'RTC':['DMZ','EXTERNAL'],'WORKSTATION':['EXTERNAL']}
        for node in data['nodes'].values():
            for index,network in enumerate(mapping[node['name']]):
                await helper.connect(c,SimpleNamespace(lab=LAB,node=int(node['id']),iface=index,network=networks[network]))
    finally:
        await c.close()

if __name__=='__main__':
    asyncio.run(main())
