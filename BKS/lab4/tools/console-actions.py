#!/usr/bin/env python3
"""Run explicit observed GUI actions through one PNETLab console connection."""
import asyncio,importlib.util,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3]
s=importlib.util.spec_from_file_location('h',root/'tools/pnet-helper.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
async def main():
 node=int(sys.argv[1]);actions=json.loads(pathlib.Path(sys.argv[2]).read_text())
 async with h.client() as c:
  await c._ensure_lab('/BKS labs/BKS4.unl');ws=await c._open_console_ws(node)
  async def pump():
   left=''
   async for msg in ws:
    ins,left=h.parse_instructions(left+(msg if isinstance(msg,str) else msg.decode()))
    for v in ins:
     if v and v[0]=='sync':await ws.send(h._guac_instr(*v))
  reader=asyncio.create_task(pump())
  async def key(k,down):await ws.send(h._guac_instr('key',k,int(down)));await asyncio.sleep(.04)
  try:
   await asyncio.sleep(2)
   for a in actions:
    if a[0]=='click':
     for mask in [0,1,0]:await ws.send(h._guac_instr('mouse',a[1],a[2],mask));await asyncio.sleep(.1)
    elif a[0]=='rightclick':
     for mask in [0,4,0]:await ws.send(h._guac_instr('mouse',a[1],a[2],mask));await asyncio.sleep(.1)
    elif a[0]=='key':
     mods=[{'ctrl':h.CTRL_L,'alt':h.ALT_L,'shift':h.SHIFT_L}[m] for m in a[2:]]
     for m in mods:await key(m,True)
     k={**h.KEYS,'PageDown':0xFF56,'PageUp':0xFF55,'Shift':h.SHIFT_L}.get(a[1],ord(a[1]) if len(a[1])==1 else 0)
     if not k:raise ValueError('Unknown key')
     await key(k,True);await key(k,False)
     for m in reversed(mods):await key(m,False)
    elif a[0] in ('text','textfile'):
     value=a[1] if a[0]=='text' else pathlib.Path(a[1]).read_text().strip()
     for ch in value:
      shift=ch in h.SHIFTED
      if shift:await key(h.SHIFT_L,True)
      k=ord(ch) if ord(ch)<256 else 0x01000000+ord(ch)
      await key(k,True);await key(k,False)
      if shift:await key(h.SHIFT_L,False)
    elif a[0]=='wait':await asyncio.sleep(float(a[1]))
    else:raise ValueError('Unsupported action')
   await asyncio.sleep(3)
  finally:reader.cancel();await ws.close()
asyncio.run(main())
