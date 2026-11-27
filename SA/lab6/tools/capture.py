#!/usr/bin/env python3
"""Снимок framebuffer SA6 через монитор QEMU, без ввода в консоль."""
import argparse
import gzip
import io
from pathlib import Path
import shlex
import subprocess
from PIL import Image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('node', choices=['directory', 'apps', 'web', 'workstation'])
p.add_argument('output', type=Path)
p.add_argument('--ssh-socket', help='локальный сокет уже открытого SSH-соединения')
a = p.parse_args()
node_session = {'directory': 26, 'apps': 27, 'web': 28, 'workstation': 29}[a.node]
code = '''import gzip,os,socket,sys,tempfile,time
fd,path=tempfile.mkstemp(prefix='sa6-frame-',suffix='.ppm');os.close(fd);os.unlink(path)
s=socket.socket(socket.AF_UNIX);s.settimeout(0.5)
try:
 s.connect(%r)
 try:s.recv(8192)
 except socket.timeout:pass
 s.sendall(('screendump '+path+'\\n').encode())
 reply=b'';end=time.monotonic()+8
 while time.monotonic()<end:
  try:reply+=s.recv(8192)
  except socket.timeout:continue
  if b'(qemu)' in reply and os.path.exists(path):break
 else:raise RuntimeError('Framebuffer was not captured')
 with open(path,'rb') as f:data=f.read()
 sys.stdout.buffer.write(gzip.compress(data,3))
finally:
 s.close()
 if os.path.exists(path):os.unlink(path)
''' % ('/opt/unetlab/tmp/15/' + str(node_session) + '/monitor.sock')
ssh = ['ssh']
if a.ssh_socket:
    ssh += ['-S', a.ssh_socket]
result = subprocess.run(ssh + ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
    '-o', 'ProxyCommand=tailscale nc %h %p', '-o', 'ServerAliveInterval=5',
    '-o', 'ServerAliveCountMax=3', 'root@100.100.57.19',
    'python3 -c ' + shlex.quote(code)], stdout=subprocess.PIPE,
    stderr=subprocess.PIPE, timeout=45)
if result.returncode:
    raise SystemExit(result.stderr.decode(errors='replace'))
with Image.open(io.BytesIO(gzip.decompress(result.stdout))) as screenshot:
    a.output.parent.mkdir(parents=True, exist_ok=True)
    screenshot.save(a.output)
print(a.output)
