#!/usr/bin/env python3
"""На WORKSTATION: первая регистрация Bob через SSO в отдельном браузере."""
import json
import os
from pathlib import Path
import sys
import time

os.environ['SA6_BROWSER_PORT'] = '4445'
sys.path.insert(0, '/opt/sa6-tools')
import browser as b

directory = json.loads(Path('/root/sa6-private/directory-credentials.json').read_text())
secrets = json.loads(Path('/root/sa6-private/browser-credentials.json').read_text())


def wait_text(fragment):
    for attempt in range(60):
        if fragment in b.text():
            return
        time.sleep(0.5)
    raise RuntimeError('Browser did not reach: ' + fragment)


def wait_selector(selector):
    for attempt in range(12):
        try:
            return b.element(selector)
        except RuntimeError:
            time.sleep(0.5)
    raise RuntimeError('Browser element did not appear: ' + selector)


def click_text(label):
    element = b.call('POST', '/element', {
        'using': 'xpath', 'value': "//button[normalize-space(.)=" + json.dumps(label) + "]"})[b.ELEMENT]
    b.call('POST', '/element/' + element + '/click', {})


wait_text('Email address')
b.fill('input[type=email]:not(#email)', 'bob@sa6.test')
click_text('Use single sign-on')
wait_selector('#username')
b.fill('#username', 'bob')
b.fill('#password', directory['bob'])
b.click('#kc-login')
wait_selector('#input-password-form_new-password')
print('Bob: LDAP/OIDC authentication succeeded', flush=True)
b.fill('#input-password-form_new-password', secrets['vault_master_bob'])
b.fill('#input-password-form_new-password-confirm', secrets['vault_master_bob'])
if b.script("return document.getElementById('input-password-form_check-for-breaches').checked"):
    b.click('#input-password-form_check-for-breaches')
click_text('Create account')
wait_text('Add it later')
click_text('Add it later')
wait_text('Skip to web app')
b.click("a[href='#/vault']")
wait_text('All vaults')
if 'Start tour' in b.text():
    click_text('Skip')
print('Bob: encrypted vault initialized', flush=True)
