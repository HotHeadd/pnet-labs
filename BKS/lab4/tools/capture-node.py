#!/usr/bin/env python3
"""Capture QEMU's framebuffer when Guacamole does not replay the entire screen."""
import subprocess,sys,shlex,uuid
from pathlib import Path
session=int(sys.argv[1]);node_session=int(sys.argv[2]);out=Path(sys.argv[3]).resolve()
remote='/opt/unetlab/bks4-preparation/frame-%d-%s.ppm'%(node_session,uuid.uuid4().hex[:8])
code='''import socket,time,os
s=socket.socket(socket.AF_UNIX);s.connect(%r);s.settimeout(0.3)
try:
 while True:s.recv(8192)
except socket.timeout:pass
s.sendall(%r)
end=time.monotonic()+8
while time.monotonic()<end:
 try:s.recv(8192)
 except socket.timeout:pass
 if os.path.exists(%r) and os.path.getsize(%r)>100:break
else:raise RuntimeError("Screenshot not created")
'''%('/opt/unetlab/tmp/%d/%d/monitor.sock'%(session,node_session),('screendump '+remote+'\n').encode(),remote,remote)
subprocess.run(['ssh','-o','BatchMode=yes','root@100.100.57.19','python3 -c '+shlex.quote(code)],check=True)
ppm=out.with_suffix('.ppm');subprocess.run(['scp','root@100.100.57.19:'+remote,str(ppm)],check=True)
subprocess.run(['sips','-s','format','png',str(ppm),'--out',str(out)],check=True,stdout=subprocess.DEVNULL)
print(out)
