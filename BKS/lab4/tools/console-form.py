#!/usr/bin/env python3
"""Fill an observed remote console form; values may come from a private file."""
import asyncio,importlib.util,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[3]
s=importlib.util.spec_from_file_location('h',root/'tools/pnet-helper.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
async def main():
 node=int(sys.argv[1]);values=json.loads(pathlib.Path(sys.argv[2]).read_text())
 async with h.client() as c:
  async def act(press):
   for i,text in enumerate(values):
    for char in text:
     sym=ord(char) if ord(char)<256 else 0x01000000+ord(char)
     await press(sym,(h.SHIFT_L,) if char in h.SHIFTED else ())
    if i<len(values)-1:await press(h.KEYS['Tab'])
   await press(h.KEYS['Enter'])
  await h._session(c,'/BKS labs/BKS4.unl',node,act,None,0.05)
asyncio.run(main())
