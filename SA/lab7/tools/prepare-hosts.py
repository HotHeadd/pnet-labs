#!/usr/bin/env python3
"""На PNET-хосте: отдельные диски SA7 и cloud-init, без изменения общих образов."""
import json
from pathlib import Path
import subprocess

BASE=Path('/opt/unetlab/addons/qemu/linux-ubuntu-server-24.04/virtioa.qcow2')
NODES=[('gw',241,'20G',3),('im',242,'40G',2),
       ('rtc',243,'40G',2),('workstation',244,'24G',1)]

def main():
    if not BASE.is_file():
        raise SystemExit('Нет проверенного базового Ubuntu 24.04')
    images=BASE.parent.parent
    for name,_,_,_ in NODES:
        if (images/('linux-sa7-'+name)).exists():
            raise SystemExit('Уже существует linux-sa7-'+name)
    key=Path('/root/.ssh/id_rsa_dy.pub').read_text().strip()
    public=['xmpp.lab.local','xmpp-tcp.lab.local','matrix.lab.local',
            'rtc.lab.local','sso.lab.local']
    for name,management,size,nics in NODES:
        image=images/('linux-sa7-'+name)
        image.mkdir()
        seed=Path('/opt/unetlab/sa7-seeds')/name
        seed.mkdir(parents=True,exist_ok=True)
        public_gw={'gw':'127.0.0.1','im':'10.70.20.10',
                   'rtc':'10.70.10.10','workstation':'192.168.15.241'}[name]
        hosts='127.0.0.1 localhost\n'+public_gw+' '+' '.join(public)+'\n'
        hosts+='10.70.20.20 im.sa7.test directory.sa7.test\n10.70.10.30 rtc.sa7.test\n'
        if name=='gw':
            networks=[('ens3','10.70.10.10/24'),('ens4','10.70.20.10/24'),('ens5','192.168.15.241/24')]
        elif name=='im':
            networks=[('ens3','10.70.20.20/24'),('ens4','192.168.15.242/24')]
        elif name=='rtc':
            networks=[('ens3','10.70.10.30/24'),('ens4','192.168.15.243/24')]
        else:
            networks=[('ens3','192.168.15.244/24')]
        ethernets={iface:{'dhcp4':False,'addresses':[ip]} for iface,ip in networks}
        ethernets[networks[-1][0]].update(routes=[{'to':'default','via':'192.168.15.2'}],
            nameservers={'addresses':['1.1.1.1','8.8.8.8']})
        config={'hostname':'sa7-'+name,'fqdn':name+'.sa7.test','manage_etc_hosts':False,
            'timezone':'Europe/Moscow','users':[{'name':'labadmin','groups':['sudo'],
                'shell':'/bin/bash','sudo':'ALL=(ALL) NOPASSWD:ALL',
                'ssh_authorized_keys':[key],'lock_passwd':True}],
            'disable_root':True,'ssh_pwauth':False,
            'write_files':[{'path':'/etc/hosts','content':hosts},
                {'path':'/etc/ssh/sshd_config.d/sa7.conf','content':'PasswordAuthentication no\nPermitRootLogin no\n'}],
            'runcmd':[['systemctl','enable','--now','serial-getty@ttyS0.service']]}
        (seed/'user-data').write_text('#cloud-config\n'+json.dumps(config))
        (seed/'meta-data').write_text(json.dumps({'instance-id':'sa7-'+name,'local-hostname':'sa7-'+name}))
        (seed/'network-config').write_text(json.dumps({'version':2,'ethernets':ethernets}))
        subprocess.run(['/opt/qemu/bin/qemu-img','create','-f','qcow2','-F','qcow2','-b',str(BASE),str(image/'virtioa.qcow2')],check=True)
        subprocess.run(['/opt/qemu/bin/qemu-img','resize',str(image/'virtioa.qcow2'),size],check=True)
        subprocess.run(['genisoimage','-quiet','-output',str(image/'cdrom.iso'),'-volid','cidata','-joliet','-rock','user-data','meta-data','network-config'],cwd=str(seed),check=True)
        print(name,'management 192.168.15.'+str(management),flush=True)

if __name__=='__main__':
    main()
