"""Выгрузка/загрузка config.xml pfSense через веб-интерфейс (Diagnostics > Backup & Restore).

python pfsense-gui.py backup  <адрес> <файл>   — сохранить текущий config.xml
python pfsense-gui.py restore <адрес> <файл>   — загрузить config.xml (pfSense перезагрузится)
Логин admin / pfsense. Прокси окружения игнорируется.
"""
import http.cookiejar
import re
import ssl
import sys
import urllib.parse
import urllib.request
import uuid

USER, PASSWORD = "admin", "pfsense"


def opener():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ctx),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))


def csrf(html):
    m = re.search(r'name=[\'"]__csrf_magic[\'"] value="([^"]+)"', html)
    return m.group(1) if m else ""


def login(op, base):
    page = op.open(base + "/").read().decode()
    data = urllib.parse.urlencode({"__csrf_magic": csrf(page), "usernamefld": USER,
                                   "passwordfld": PASSWORD, "login": "Sign In"}).encode()
    page = op.open(base + "/", data).read().decode()
    if "usernamefld" in page:
        sys.exit("login failed")


def backup(op, base, path):
    page = op.open(base + "/diag_backup.php").read().decode()
    data = urllib.parse.urlencode({"__csrf_magic": csrf(page), "backuparea": "",
                                   "donotbackuprrd": "yes", "encrypt_password": "",
                                   "download": "Download configuration as XML"}).encode()
    body = op.open(base + "/diag_backup.php", data).read()
    if not body.lstrip().startswith(b"<?xml"):
        sys.exit("backup failed: " + body[:200].decode(errors="replace"))
    open(path, "wb").write(body)


def restore(op, base, path):
    page = op.open(base + "/diag_backup.php").read().decode()
    boundary = uuid.uuid4().hex
    fields = {"__csrf_magic": csrf(page), "restorearea": "", "decrypt_password": "",
              "restore": "Restore Configuration"}
    parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
             for k, v in fields.items()]
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="conffile"; '
                 f'filename="config.xml"\r\nContent-Type: text/xml\r\n\r\n'.encode()
                 + open(path, "rb").read() + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    req = urllib.request.Request(base + "/diag_backup.php", b"".join(parts),
                                 {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    page = op.open(req).read().decode(errors="replace")
    msg = re.findall(r'class="alert[^"]*"[^>]*>(.*?)</div>', page, re.S)
    print(re.sub(r"<[^>]+>|\s+", " ", " | ".join(msg)).strip() or "no message")


def main():
    action, host, path = sys.argv[1:4]
    base = f"https://{host}"
    op = opener()
    login(op, base)
    {"backup": backup, "restore": restore}[action](op, base, path)


if __name__ == "__main__":
    main()
