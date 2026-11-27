#!/bin/bash
# На WEB от root. Конфиги заранее переданы в /tmp/sa6-web-configs.
set -euo pipefail
umask 077
install -d -m 700 /root/sa6-private
install -d -m 755 /opt/sa6 /opt/sa6/tls
install -m 644 /root/sa6-private/ca.crt /opt/sa6/tls/ca.crt
install -m 644 /root/sa6-private/web.crt /opt/sa6/tls/web.crt
install -m 600 /root/sa6-private/web.key /opt/sa6/tls/web.key
install -m 644 /root/sa6-private/ca.crt /usr/local/share/ca-certificates/sa6-ca.crt
update-ca-certificates
cat /etc/ssl/certs/ca-certificates.crt > /opt/sa6/tls/ca-bundle.crt
chmod 644 /opt/sa6/tls/ca-bundle.crt
if ! grep -q 'auth.sa6.test' /etc/hosts; then
    printf '10.60.0.30 auth.sa6.test git.sa6.test vault.sa6.test\n' >> /etc/hosts
fi
install -m 644 /tmp/sa6-web-configs/docker-compose.yaml /opt/sa6/docker-compose.yaml
install -m 644 /tmp/sa6-web-configs/nginx-sa6.conf /etc/nginx/sites-available/sa6
install -m 644 /tmp/sa6-web-configs/web-image-digests.json /opt/sa6/image-digests.json
python3 - <<'PY'
import json, secrets, subprocess
from pathlib import Path
p = Path('/root/sa6-private/web-credentials.json')
values = json.loads(p.read_text()) if p.exists() else {}
for name in ['kc_db', 'kc_admin', 'vault_oidc', 'gitea_oidc', 'gitea_admin',
             'vault_master_alice', 'vault_master_bob']:
    values.setdefault(name, secrets.token_urlsafe(24))
p.write_text(json.dumps(values, indent=2))
p.chmod(0o600)
Path('/opt/sa6/.env').write_text(''.join(key + '=' + values[name] + '\n' for key, name in [
    ('KC_DB_PASSWORD', 'kc_db'), ('KC_ADMIN_PASSWORD', 'kc_admin'),
    ('VAULT_OIDC_SECRET', 'vault_oidc')]))
Path('/opt/sa6/.env').chmod(0o600)
for record in json.loads(Path('/opt/sa6/image-digests.json').read_text()):
    actual = subprocess.check_output(['docker', 'image', 'inspect', record['image'],
        '--format', '{{.Id}}']).decode().strip()
    if actual != record['id']:
        raise SystemExit('Image ID mismatch: ' + record['image'])
print('All four official image config IDs verified')
PY
ln -sfn /etc/nginx/sites-available/sa6 /etc/nginx/sites-enabled/sa6
nginx -t
systemctl enable --now nginx docker
systemctl reload nginx
cd /opt/sa6
export COMPOSE_API_VERSION=1.44
docker-compose config --quiet
docker-compose up -d
for attempt in $(seq 1 150); do
    if curl --silent --fail https://auth.sa6.test/realms/master >/dev/null; then
        printf 'Keycloak HTTPS realm endpoint ready\n'
        exit 0
    fi
    sleep 2
done
printf 'Keycloak readiness timeout\n' >&2
exit 1
