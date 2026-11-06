from pathlib import Path
import subprocess,secrets,string
h=Path.home();p=h/'.bks4-snmp-community'
if not p.exists():p.write_text(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(24)));p.chmod(0o600)
community=p.read_text().strip()
subprocess.run(['sudo','apt-get','install','-y','-qq','snmp'],check=True,stdout=subprocess.DEVNULL)
conf='authCommunity log '+community+' 10.1.99.1\n'
subprocess.run(['sudo','tee','/etc/snmp/snmptrapd.conf'],input=conf,text=True,stdout=subprocess.DEVNULL,check=True)
subprocess.run(['sudo','chmod','600','/etc/snmp/snmptrapd.conf'],check=True)
s=(h/'.snmp');s.mkdir(exist_ok=True,mode=0o700);f=s/'snmp.conf';f.write_text('defCommunity '+community+'\n');f.chmod(0o600)
unit='''[Unit]
Description=BKS4 native NGFW trap receiver
After=network-online.target
[Service]
ExecStart=/usr/sbin/snmptrapd -f -Lo udp:10.1.99.10:162
StandardOutput=append:/var/log/bks4/snmp-traps.log
StandardError=append:/var/log/bks4/snmp-traps.log
Restart=on-failure
[Install]
WantedBy=multi-user.target
'''
subprocess.run(['sudo','systemctl','disable','--now','snmptrapd.service','snmptrapd.socket'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
subprocess.run(['sudo','tee','/etc/systemd/system/bks4-snmptrap.service'],input=unit,text=True,stdout=subprocess.DEVNULL,check=True)
subprocess.run(['sudo','systemctl','daemon-reload'],check=True);subprocess.run(['sudo','systemctl','enable','--now','bks4-snmptrap.service'],check=True)
subprocess.run(['sudo','systemctl','is-active','bks4-snmptrap.service'],check=True)
