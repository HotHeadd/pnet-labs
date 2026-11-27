#!/usr/bin/env python3
"""На Mac: сформировать проверенные манифесты и сценарии для трёх узлов."""
import base64
import gzip
import hashlib
import json
from pathlib import Path
import shlex
import urllib.parse

lab = Path(__file__).resolve().parents[1]
cache = Path('/tmp/sa6-apt-cache')
destination = lab / 'tools/apt'
destination.mkdir(exist_ok=True)
worker = (lab / 'tools/guest-apt-range.py').read_bytes()
for node in ['apps', 'web', 'workstation']:
    source = Path('/tmp/sa6-' + node + ('-remaining-plan.txt' if node == 'apps' else '-package-plan.txt'))
    rows = [shlex.split(x) for x in source.read_text().splitlines() if x.startswith("'https://")]
    if not rows:
        raise SystemExit('Нет проверенного списка пакетов: ' + node)
    packages = []
    for url, name, size, digest in rows:
        path = cache / name
        data = path.read_bytes()
        algorithm, expected = digest.split(':', 1)
        if len(data) != int(size) or hashlib.new(algorithm.lower().removesuffix('sum'), data).hexdigest() != expected:
            raise SystemExit('Локальный пакет не прошёл проверку: ' + name)
        packages.append({'name': name, 'size': int(size), 'sha256': hashlib.sha256(data).hexdigest(),
            'source': url, 'mirror': 'https://mirror.yandex.ru' + urllib.parse.urlsplit(url).path})
    install = shlex.split(next(x for x in (lab / ('commands/install-' + node + '.sh')).read_text().splitlines()
        if x.startswith('apt-get install')))[1:]
    plan = json.dumps({'packages': packages, 'install': install}, indent=2).encode()
    (destination / (node + '.json')).write_bytes(plan)
    script = '#!/bin/bash\nset -euo pipefail\ninstall -d -m 700 /root/sa6-private\n'
    for name, data in [('/tmp/sa6-apt-range.py', worker), ('/root/sa6-private/apt-plan.json', plan)]:
        encoded = base64.b64encode(gzip.compress(data, mtime=0)).decode()
        script += "base64 -d <<'SA6DATA' | gzip -d > " + name + '\n'
        script += '\n'.join(encoded[i:i+76] for i in range(0, len(encoded), 76)) + '\nSA6DATA\n'
    script += 'python3 /tmp/sa6-apt-range.py /root/sa6-private/apt-plan.json\n'
    target = Path('/tmp/sa6-range-install-' + node + '.sh')
    target.write_text(script)
    print(node, len(packages), sum(p['size'] for p in packages), target, flush=True)
