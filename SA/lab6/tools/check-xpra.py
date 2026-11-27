#!/usr/bin/env python3
"""Проверить отключение/подключение Xpra, сохранив UUID и процесс Tryton."""
from pathlib import Path
import shlex
import subprocess

code = r'''
from pathlib import Path
import subprocess,time
ssh=['ssh','-i','/root/.ssh/id_rsa_dy','-o','BatchMode=yes','-o','ConnectTimeout=5']
def guest(octet,command):
 return subprocess.check_output(ssh+['labadmin@192.168.15.'+str(octet),command],universal_newlines=True)
def state():
 data=guest(232,'sudo -u alice env HOME=/home/alice xpra info :100 --socket-dir=/home/alice/.xpra')
 values=dict(line.split('=',1) for line in data.splitlines() if '=' in line)
 window=next(key.rsplit('.',1)[0] for key,value in values.items() if key.endswith('.title') and value=='Alice SA6 - Tryton')
 return {'clients':int(values['clients']),'server':values['server.pid'],
  'uuid':values['server.uuid'],'tryton':values[window+'.pid'],'title':values[window+'.title']}
before=state()
assert before['clients']==1,before
records=[('before',before)]
try:
 guest(234,'sudo systemctl stop sa6-xpra-client')
 for attempt in range(20):
  disconnected=state()
  if disconnected['clients']==0:break
  time.sleep(0.5)
 else:raise RuntimeError('Xpra connection did not close after client stop')
 records.append(('disconnected',disconnected))
finally:
 guest(234,'sudo systemctl start sa6-xpra-client')
for attempt in range(20):
 after=state()
 if after['clients']==1:break
 time.sleep(0.5)
else:raise RuntimeError('Xpra client did not reconnect')
records.append(('reconnected',after))
for label,item in records:
 for key in ['server','uuid','tryton','title']:assert item[key]==before[key],(label,key)
lines=['Xpra display :100; SSH from WORKSTATION to APPS','stage          clients server_pid tryton_pid']
for label,item in records:lines.append('%-14s %-7s %-10s %s'%(label,item['clients'],item['server'],item['tryton']))
lines.extend(['session_uuid='+before['uuid'],'window_title='+before['title'],'same_session_and_application=true'])
output='\n'.join(lines)+'\n'
Path('/tmp/sa6-xpra-proof.txt').write_text(output)
print(output,end='')
'''
result = subprocess.run(['ssh', '-n', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
    'root@100.100.57.19', 'python3 -c ' + shlex.quote(code)], stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT, timeout=90)
print(result.stdout.decode(errors='replace'), end='')
if result.returncode == 0:
    (Path(__file__).resolve().parents[1] / 'outputs/xpra-reconnect.txt').write_bytes(result.stdout)
raise SystemExit(result.returncode)
