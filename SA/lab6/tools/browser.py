#!/usr/bin/env python3
"""W3C WebDriver для браузерных проверок внутри WORKSTATION.

Сеанс и учётные данные остаются на ВМ; пароли не выводятся.
"""
import base64
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request

PORT = int(os.environ.get('SA6_BROWSER_PORT', '4444'))
STATE = Path('/root/sa6-private/browser-session' + ('' if PORT == 4444 else '-' + str(PORT)) + '.json')
ELEMENT = 'element-6066-11e4-a52e-4f735466cecf'


def request(method, path, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request('http://127.0.0.1:' + str(PORT) + path, data=body,
        method=method, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            value = json.load(response)['value']
    except urllib.error.HTTPError as exc:
        # Не выводить исходный запрос: в нём может находиться пароль формы.
        error = json.load(exc).get('value', {}).get('error', 'unknown error')
        raise RuntimeError('WebDriver: ' + error) from None
    if isinstance(value, dict) and value.get('error'):
        raise RuntimeError('WebDriver: ' + value['error'])
    return value


def start():
    capabilities = {'browserName': 'MiniBrowser', 'acceptInsecureCerts': False}
    if PORT != 4444:
        capabilities['webkitgtk:browserOptions'] = {'args': ['--automation', '--private']}
    value = request('POST', '/session', {'capabilities': {'alwaysMatch': capabilities}})
    STATE.write_text(json.dumps({'id': value['sessionId']}))
    STATE.chmod(0o600)
    call('POST', '/timeouts', {'implicit': 5000, 'pageLoad': 60000, 'script': 30000})
    call('POST', '/window/rect', {'width': 1024, 'height': 730, 'x': 0, 'y': 27})


def call(method, path, data=None):
    session = json.loads(STATE.read_text())['id']
    return request(method, '/session/' + session + path, data)


def navigate(url):
    call('POST', '/url', {'url': url})


def script(source, *arguments):
    return call('POST', '/execute/sync', {'script': source, 'args': list(arguments)})


def text():
    return script('return document.body.innerText')


def element(selector, using='css selector'):
    return call('POST', '/element', {'using': using, 'value': selector})[ELEMENT]


def click(selector, using='css selector'):
    for attempt in range(20):
        try:
            return call('POST', '/element/' + element(selector, using) + '/click', {})
        except RuntimeError as exc:
            if attempt == 19 or str(exc) not in ['WebDriver: element click intercepted', 'WebDriver: stale element reference']:
                raise
            time.sleep(0.2)


def fill(selector, value):
    target = element(selector)
    call('POST', '/element/' + target + '/clear', {})
    call('POST', '/element/' + target + '/value', {'text': value})


def screenshot(path):
    Path(path).write_bytes(base64.b64decode(call('GET', '/screenshot')))


if __name__ == '__main__':
    import sys
    if sys.argv[1] == 'start':
        start()
        print('Browser test session started; certificate validation enabled')
    elif sys.argv[1] == 'url':
        navigate(sys.argv[2])
        print(text())
    elif sys.argv[1] == 'text':
        print(text())
    elif sys.argv[1] == 'screenshot':
        screenshot(sys.argv[2])
        print('Screenshot saved on WORKSTATION')
