#!/usr/bin/env python3
"""На хосте PNETLab: отдельные загрузочные диски и cloud-init для SA6.

Общий образ Ubuntu не изменяется. Повторный запуск отказывается
перезаписывать уже созданные диски.
"""
import json
from pathlib import Path
import subprocess

BASE = Path('/opt/unetlab/addons/qemu/linux-ubuntu-server-22.04/virtioa.qcow2')
NODES = [('directory', 10, 231, '12G'), ('apps', 20, 232, '16G'),
         ('web', 30, 233, '24G'), ('workstation', 100, 234, '16G')]


def main():
    key = Path('/root/.ssh/id_rsa_dy.pub').read_text().strip()
    images = BASE.parent.parent
    for name, _, _, _ in NODES:
        if (images / ('linux-sa6-' + name)).exists():
            raise SystemExit('Уже существует образ linux-sa6-' + name)
    hosts = '127.0.0.1 localhost\n' + ''.join(
        f'10.60.0.{ip} {name}.sa6.test {name}\n' for name, ip, _, _ in NODES)
    for name, ip, management, size in NODES:
        image = images / ('linux-sa6-' + name)
        image.mkdir()
        seed = Path('/opt/unetlab/sa6-seeds') / name
        seed.mkdir(parents=True, exist_ok=True)
        network = {'version': 2, 'ethernets': {
            'ens3': {'dhcp4': False, 'addresses': [f'10.60.0.{ip}/24']},
            'ens4': {'dhcp4': False, 'addresses': [f'192.168.15.{management}/24'],
                     'routes': [{'to': 'default', 'via': '192.168.15.2'}],
                     'nameservers': {'addresses': ['1.1.1.1', '8.8.8.8']}}}}
        user = {'hostname': name, 'fqdn': name + '.sa6.test',
                'manage_etc_hosts': False, 'timezone': 'Europe/Moscow',
                'users': [{'name': 'labadmin', 'groups': ['sudo'],
                           'shell': '/bin/bash', 'sudo': 'ALL=(ALL) NOPASSWD:ALL',
                           'ssh_authorized_keys': [key], 'lock_passwd': True}],
                'disable_root': True, 'ssh_pwauth': False,
                'write_files': [
                    {'path': '/etc/hosts', 'content': hosts},
                    {'path': '/etc/ssh/sshd_config.d/sa6.conf',
                     'content': 'PasswordAuthentication no\nPermitRootLogin no\n'}],
                'runcmd': [['systemctl', 'enable', '--now', 'serial-getty@ttyS0.service']]}
        (seed / 'user-data').write_text('#cloud-config\n' + json.dumps(user))
        (seed / 'meta-data').write_text(json.dumps({
            'instance-id': 'sa6-' + name, 'local-hostname': name}))
        (seed / 'network-config').write_text(json.dumps(network))
        subprocess.run(['qemu-img', 'create', '-f', 'qcow2', '-F', 'qcow2',
                        '-b', str(BASE), str(image / 'virtioa.qcow2')], check=True)
        subprocess.run(['qemu-img', 'resize', str(image / 'virtioa.qcow2'), size], check=True)
        subprocess.run(['genisoimage', '-quiet', '-output', str(image / 'cdrom.iso'),
                        '-volid', 'cidata', '-joliet', '-rock',
                        'user-data', 'meta-data', 'network-config'], cwd=seed, check=True)
        print(f'{name}: 10.60.0.{ip}/24; management 192.168.15.{management}/24', flush=True)


if __name__ == '__main__':
    main()
