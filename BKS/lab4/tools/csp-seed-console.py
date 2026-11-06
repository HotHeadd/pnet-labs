#!/usr/bin/env python3
"""Operate the observed CSP entropy target in the isolated training VM.
Uses OS randomness for pointer jitter/timing; this is lab automation, not a
claim of certified collection of entropy from a physical human operator.
"""
import asyncio,importlib.util,pathlib,sys,secrets
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[3]
sp=importlib.util.spec_from_file_location('h',root/'tools/pnet-helper.py');h=importlib.util.module_from_spec(sp);sp.loader.exec_module(h)
async def main():
 rng=secrets.SystemRandom();screen=h.GuacScreen(1024,768)
 async with h.client() as c:
  await c._ensure_lab('/BKS labs/BKS4.unl');ws=await c._open_console_ws(7)
  async def pump():
   left=''
   async for msg in ws:
    ins,left=h.parse_instructions(left+(msg if isinstance(msg,str) else msg.decode()))
    for v in ins:
     if v and v[0]=='sync':await ws.send(h._guac_instr(*v))
     screen.handle(v)
  reader=asyncio.create_task(pump())
  try:
   await asyncio.sleep(3)
   misses=0
   for step in range(int(sys.argv[1]) if len(sys.argv)>1 else 10):
    pathlib.Path('/tmp/bks4-csp-frame.png').write_bytes(screen.png())
    im=Image.open('/tmp/bks4-csp-frame.png').convert('RGB');pixels=im.load();points=set()
    for y in range(im.height):
     for x in range(im.width):
      r,g,b=pixels[x,y]
      if b-r>65 and g-r>25 and g>90:points.add((x,y))
    candidates=[]
    while points:
     p=points.pop();component=[p];queue=[p]
     while queue:
      x,y=queue.pop()
      for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
       if n in points:points.remove(n);queue.append(n);component.append(n)
     if len(component)>1200:
      xs=[p[0] for p in component];ys=[p[1] for p in component]
      w=max(xs)-min(xs);height=max(ys)-min(ys)
      if 60<w<110 and 60<height<110 and abs(w-height)<8:candidates.append(component)
    if len(candidates)!=1:
     misses+=1
     if misses>=10:
      print('Stopped: target not confidently visible',len(candidates));break
     await asyncio.sleep(.3)
     continue
    misses=0
    component=candidates[0]
    x=round(sum(p[0] for p in component)/len(component))+rng.randint(-8,8)
    y=round(sum(p[1] for p in component)/len(component))+rng.randint(-8,8)
    print('Target click',step+1,x,y,'pixels',len(component),flush=True)
    await ws.send(h._guac_instr('mouse',x,y,0));await asyncio.sleep(rng.uniform(.08,.2))
    await ws.send(h._guac_instr('mouse',x,y,1));await asyncio.sleep(rng.uniform(.08,.2))
    await ws.send(h._guac_instr('mouse',x,y,0));await asyncio.sleep(rng.uniform(.15,.45))
   await asyncio.sleep(1)

  finally:reader.cancel();await ws.close()
asyncio.run(main())
