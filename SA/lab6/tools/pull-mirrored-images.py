#!/usr/bin/env python3
"""На WEB или PNET-хосте: загрузить OCI-образы по официальным digest.

Глобальная конфигурация Docker не меняется. После загрузки config ID
сравнивается с официальной amd64-копией, проверенной на Mac.
"""
import json
from pathlib import Path
import subprocess

records = json.loads(Path('/tmp/sa6-web-image-digests.json').read_text())
for record in records:
    image = record['image']
    repository = image.rsplit(':', 1)[0]
    if repository == 'docker.gitea.com/gitea':
        # DockerHub и официальный registry имеют одинаковый manifest digest.
        repository = 'docker.io/gitea/gitea'
    elif '/' not in repository:
        repository = 'docker.io/library/' + repository
    elif '.' not in repository.split('/')[0]:
        repository = 'docker.io/' + repository
    mirror = 'm.daocloud.io/' + repository + '@' + record['digest']
    subprocess.run(['docker', 'pull', mirror], check=True)
    actual = subprocess.check_output(['docker', 'image', 'inspect', mirror,
        '--format', '{{.Id}}']).decode().strip()
    if actual != record['id']:
        raise SystemExit('Не совпал config ID: ' + image)
    subprocess.run(['docker', 'tag', mirror, image], check=True)
    print('official config ID OK: ' + image, flush=True)
subprocess.run(['docker', 'save', '-o', '/tmp/sa6-native-web-images.tar',
    *[r['image'] for r in records]], check=True)
