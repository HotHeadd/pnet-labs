#!/bin/bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import base64,zipfile
# Standard harmless antivirus test file (EICAR), not malware.
p=Path('/var/www/html')
b=base64.b64decode('WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=')
assert len(b)==68
(p/'eicar.com').write_bytes(b)
with zipfile.ZipFile(p/'eicar.zip','w',zipfile.ZIP_DEFLATED) as z:z.writestr('eicar.com',b)
(p/'allowed.txt').write_text('BKS4 harmless control download\n')
PY
install -d -m 700 /etc/nginx/bks4-tls
openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/nginx/bks4-tls/server.key -out /etc/nginx/bks4-tls/server.crt -days 30 -subj '/CN=bks4-test.local' -addext 'subjectAltName=DNS:bks4-test.local,IP:10.1.50.10,IP:192.168.100.1'
cat > /etc/nginx/sites-available/bks4-tls <<'EOF'
server {
 listen 443 ssl;
 ssl_certificate /etc/nginx/bks4-tls/server.crt;
 ssl_certificate_key /etc/nginx/bks4-tls/server.key;
 root /var/www/html;
 location / { try_files $uri $uri/ =404; }
}
EOF
ln -sf /etc/nginx/sites-available/bks4-tls /etc/nginx/sites-enabled/bks4-tls
nginx -t
systemctl reload nginx
curl -fsS http://127.0.0.1/allowed.txt
