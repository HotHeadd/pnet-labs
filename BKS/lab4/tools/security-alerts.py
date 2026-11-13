#!/usr/bin/env python3
"""External BKS4 syslog/ICAP monitor; notifications originate on ADMIN-LINUX.

Local experimental OIDs below 1.3.6.1.3.9999.4 are lab-only, not vendor MIBs.
SNMP credentials are loaded by Net-SNMP from a protected configuration file.
"""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

FILES = [Path('/var/log/bks4/10.1.99.1/events.log'), Path('/var/log/c-icap/server.log')]
STATE = Path('/var/lib/bks4-security-alerts/offsets.json')
OUT = Path('/var/log/bks4/security-alerts.jsonl')
OID = '.1.3.6.1.3.9999.4'


def parse(line, kind):
    if kind == 'ngfw' and ' kerio-security ' in line:
        match = re.search(
            r'IPS: (.*?), severity: (\w+), Rule ID: (\d+:\d+) (.*?), '
            r'proto:(\w+), ip/port:([\d.]+):(\d+).*?-> ([\d.]+):(\d+)', line)
        if not match:
            return None
        mode, severity, sid, signature, proto, src, sport, dst, dport = match.groups()
        return {'origin': 'Kerio native syslog', 'component': 'IPS',
                'syslog_app': 'kerio-security', 'signature_id': sid,
                'signature': signature, 'severity': severity, 'proto': proto,
                'src_ip': src, 'src_port': sport, 'dest_ip': dst, 'dest_port': dport,
                'action': 'blocked' if mode == 'Packet drop' else 'allowed'}
    if kind == 'ngfw':
        header = line.split(' ', 6)
        if len(header) < 7 or header[3] != 'suricata':
            return None
        d = dict(re.findall(r'(\w+)="((?:[^"\\]|\\.)*)"', line))
        if (not d.get('signature_id', '').isdigit() or int(d['signature_id']) == 0
                or d.get('action') not in {'allowed', 'blocked'}):
            return None
        return dict(origin='NGFW syslog', component='IPS', syslog_app='suricata', **{
            k: d.get(k) for k in ['timestamp_str', 'src_ip', 'dest_ip',
                                 'signature_id', 'signature', 'action']})
    if 'VIRUS DETECTED:' in line:
        return {'origin': 'ICAP engine log', 'component': 'AV',
                'detail': line.strip()[:500]}
    return None


def notify(event):
    event['monitor_utc'] = datetime.now(timezone.utc).isoformat()
    event['sender'] = 'BKS4-MONITOR (10.1.99.10)'
    text = json.dumps(event, ensure_ascii=True)
    subprocess.run([
        '/usr/bin/snmptrap', '-v', '2c', '-m', '', '-t', '2', '-r', '0',
        'udp:10.1.99.10:162', '', OID + '.0.1',
        OID + '.1.0', 's', text,
    ], env=dict(os.environ, SNMPCONFPATH='/etc/bks4-alert-client'),
        check=True, capture_output=True, timeout=10)
    with OUT.open('a') as f:
        f.write(text + '\n')
    print(text, flush=True)


def main():
    STATE.parent.mkdir(parents=True, exist_ok=True)
    offsets = json.loads(STATE.read_text()) if STATE.exists() else {}
    seen = set()
    while True:
        for path in FILES:
            if not path.exists():
                continue
            stat = path.stat()
            key = str(path)
            old = offsets.get(key)
            # New deployments start at EOF, never replay old tests as fresh alerts.
            start = stat.st_size if old is None else old['position']
            if old and (old['inode'] != stat.st_ino or start > stat.st_size):
                start = 0
            with path.open('rb') as stream:
                stream.seek(start)
                while True:
                    position = stream.tell()
                    line = stream.readline()
                    if not line:
                        break
                    if not line.endswith(b'\n'):
                        stream.seek(position)
                        break
                    event = parse(line.decode('utf-8', 'replace'), 'ngfw' if path == FILES[0] else 'icap')
                    digest = hashlib.sha256(line).hexdigest()
                    if event and digest not in seen:
                        notify(event)
                        seen.add(digest)
                        if len(seen) > 4096:
                            seen = {digest}
                offsets[key] = {'inode': stat.st_ino, 'position': stream.tell()}
        temp = STATE.with_suffix('.tmp')
        temp.write_text(json.dumps(offsets))
        temp.replace(STATE)
        time.sleep(1)


if __name__ == '__main__':
    main()
