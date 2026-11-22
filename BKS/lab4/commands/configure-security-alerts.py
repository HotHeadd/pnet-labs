#!/usr/bin/env python3
"""Run as root on ADMIN-LINUX with the path to security-alerts.py as argument."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys

assert os.geteuid() == 0
os.umask(0o077)
source = Path(sys.argv[1]).resolve()
assert source.is_file()
secret = Path('/root/.bks4-monitor-snmp-community')
if not secret.exists():
    secret.write_text(secrets.token_hex(24))
secret.chmod(0o600)
community = secret.read_text().strip()
client = Path('/etc/bks4-alert-client')
client.mkdir(mode=0o700, exist_ok=True)
(client / 'snmp.conf').write_text('defVersion 2c\ndefCommunity ' + community + '\n')
(client / 'snmp.conf').chmod(0o600)
receiver = Path('/etc/snmp/snmptrapd.conf')
conf = receiver.read_text()
marker = '# BKS4 external security monitor\n'
if marker not in conf:
    conf += '\n' + marker + 'authCommunity log ' + community + ' 10.1.99.10\n'
    receiver.write_text(conf)
    receiver.chmod(0o600)
    subprocess.run(['systemctl', 'restart', 'bks4-snmptrap.service'], check=True)
target = Path('/usr/local/sbin/bks4-security-alerts.py')
shutil.copyfile(source, target)
target.chmod(0o755)
Path('/etc/systemd/system/bks4-security-alerts.service').write_text('''[Unit]
Description=BKS4 external IPS and ICAP SNMP alert monitor
After=network-online.target rsyslog.service bks4-snmptrap.service
Wants=network-online.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/sbin/bks4-security-alerts.py
Restart=on-failure
RestartSec=3
UMask=0077
[Install]
WantedBy=multi-user.target
''')
subprocess.run(['systemctl', 'daemon-reload'], check=True)
subprocess.run(['systemctl', 'enable', '--now', 'bks4-security-alerts.service'], check=True)
subprocess.run(['systemctl', 'is-active', 'bks4-security-alerts.service'], check=True)
print('External monitor installed; native NGFW sender and its community unchanged.')
