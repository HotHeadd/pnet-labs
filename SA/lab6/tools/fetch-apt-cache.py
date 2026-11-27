#!/usr/bin/env python3
"""Загрузить недостающие .deb из вывода apt-get --print-uris в локальный кэш.

Список пакетов и контрольные суммы берутся с целевой Ubuntu, не вычисляются
по имени пакета. Полученный tar можно перенести в её APT-кэш.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
from pathlib import Path
import shlex
import subprocess
import tarfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('node', choices=['apps', 'web', 'workstation'])
a = p.parse_args()
cache = Path('/tmp/sa6-apt-cache')
cache.mkdir(exist_ok=True)
rows = [shlex.split(line) for line in Path(f'/tmp/sa6-{a.node}-package-plan.txt').read_text().splitlines()
        if line.startswith("'https://") or line.startswith("'http://")]


def fetch(row):
    url, name, size, digest = row
    if Path(name).name != name:
        raise ValueError('Недопустимое имя файла')
    algorithm, expected = digest.split(':', 1)
    algorithm = algorithm.lower().removesuffix('sum')
    path = cache / name
    def valid(candidate):
        return candidate.exists() and candidate.stat().st_size == int(size) and hashlib.new(algorithm, candidate.read_bytes()).hexdigest() == expected
    if not valid(path):
        temp = path.with_name(path.name + '.part')
        r = subprocess.run(['curl', '--noproxy', '*', '-fL', '--retry', '2',
            '--connect-timeout', '10', '--max-time', '180', '-sS', '-o', str(temp), url],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if r.returncode:
            raise RuntimeError(name + ': ' + r.stderr.strip())
        if not valid(temp):
            raise RuntimeError(name + ': размер или контрольная сумма не совпали')
        temp.replace(path)
    return path


print(f'{a.node}: {len(rows)} файлов, {sum(int(r[2]) for r in rows)/1024/1024:.1f} МиБ', flush=True)
paths = []
with ThreadPoolExecutor(max_workers=4) as pool:
    futures = [pool.submit(fetch, row) for row in rows]
    for i, f in enumerate(as_completed(futures), 1):
        paths.append(f.result())
        if i % 25 == 0 or i == len(rows):
            print(f'Проверено {i}/{len(rows)}', flush=True)
bundle = Path(f'/tmp/sa6-{a.node}-packages.tar')
with tarfile.open(bundle, 'w') as archive:
    for path in sorted(paths):
        info = archive.gettarinfo(str(path), arcname=path.name)
        info.uid = info.gid = 0
        info.uname = info.gname = 'root'
        with path.open('rb') as f:
            archive.addfile(info, f)
print(bundle, hashlib.sha256(bundle.read_bytes()).hexdigest(), flush=True)
