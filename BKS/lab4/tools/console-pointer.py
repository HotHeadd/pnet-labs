#!/usr/bin/env python3
"""Click an observed location in a PNETLab VNC console through Guacamole."""
import asyncio,importlib.util,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3]
s=importlib.util.spec_from_file_location('h',root/'tools/pnet-helper.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
async def main():
 node,x,y=map(int,sys.argv[1:4])
 async with h.client() as c:
  await c._ensure_lab('/BKS labs/BKS4.unl');ws=await c._open_console_ws(node)
  async def pump():
   left=''
   async for msg in ws:
    instructions,left=h.parse_instructions(left+(msg if isinstance(msg,str) else msg.decode()))
    for ins in instructions:
     if ins and ins[0]=='sync':await ws.send(h._guac_instr(*ins))
  reader=asyncio.create_task(pump())
  try:
   await asyncio.sleep(2.5)
   for mask in [0,1,0]:
    await ws.send(h._guac_instr('mouse',x,y,mask));await asyncio.sleep(.15)
   await asyncio.sleep(1)
  finally:reader.cancel();await ws.close()
asyncio.run(main())
