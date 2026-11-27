#!/usr/bin/env python3
"""На госте: загрузить недостающие .deb частями, проверить SHA256, заполнить кэш."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.request

plan = json.loads(Path(sys.argv[1]).read_text())
cache = Path('/var/cache/apt/archives')
parts = cache / 'partial/sa6-ranges'
parts.mkdir(parents=True, exist_ok=True)
chunk_size = 256 * 1024
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda: f.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()


for record in plan['packages']:
    name, size, expected, url = (record[k] for k in ['name', 'size', 'sha256', 'mirror'])
    if Path(name).name != name:
        raise SystemExit('Недопустимое имя пакета')
    destination = cache / name
    if destination.exists() and destination.stat().st_size == size and sha(destination) == expected:
        print('cached ' + name, flush=True)
        continue
    print('download ' + name + ' ' + str(size), flush=True)

    def download(start):
        end = min(start + chunk_size, size) - 1
        target = parts / (expected + '-' + str(start))
        length = end - start + 1
        if target.exists() and target.stat().st_size == length:
            return target
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, headers={
                    'Range': 'bytes=' + str(start) + '-' + str(end),
                    'Accept-Encoding': 'identity'})
                with opener.open(req, timeout=25) as response:
                    if response.status == 206:
                        wanted = 'bytes ' + str(start) + '-' + str(end) + '/' + str(size)
                        if response.headers.get('Content-Range') != wanted:
                            raise ValueError('Неверный Content-Range')
                    elif not (response.status == 200 and start == 0 and end == size - 1):
                        raise ValueError('Сервер не подтвердил диапазон')
                    data = response.read(length + 1)
                if len(data) != length:
                    raise ValueError('Неполный диапазон')
                temp = target.with_suffix('.part')
                temp.write_bytes(data)
                temp.replace(target)
                return target
            except Exception as exc:
                if attempt == 3:
                    raise RuntimeError(name + ' offset=' + str(start) + ': ' + str(exc))
                time.sleep(attempt + 1)

    with ThreadPoolExecutor(max_workers=4) as pool:
        downloaded = list(pool.map(download, range(0, size, chunk_size)))
    assembled = parts / (expected + '.deb')
    with assembled.open('wb') as out:
        for part in downloaded:
            out.write(part.read_bytes())
    if assembled.stat().st_size != size or sha(assembled) != expected:
        raise SystemExit('SHA256 пакета не совпал: ' + name)
    assembled.replace(destination)
    print('SHA256 OK ' + name, flush=True)

subprocess.run(['env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get', '--no-download',
    '-o', 'DPkg::Lock::Timeout=60', *plan['install']], check=True)
