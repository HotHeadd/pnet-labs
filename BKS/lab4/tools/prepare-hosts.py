#!/usr/bin/env python3
"""Run on PNETLab host: create independent cloud-init images for BKS4."""
from pathlib import Path
import json,subprocess
base=Path('/opt/unetlab/addons/qemu/linux-ubuntu-server-22.04/virtioa.qcow2')
key=Path('/root/.ssh/id_rsa_dy.pub').read_text().strip()
for name,ip,gw,oob in [('lan-client','10.1.10.42/24','10.1.10.1',221),('dmz-web','10.1.50.10/26','10.1.50.1',222),('wan-test','192.168.100.1/24','192.168.100.2',223),('admin-linux','10.1.99.10/24','10.1.99.1',224)]:
 image=base.parent.parent/('linux-bks4-'+name)
 if image.exists(): raise RuntimeError('Refusing to overwrite '+str(image))
 image.mkdir(); seed=Path('/opt/unetlab/bks4-seeds')/name;seed.mkdir(parents=True,exist_ok=True)
 data={'version':2,'ethernets':{'ens3':{'addresses':[ip],'routes':[{'to':'default','via':gw,'table':100},{'to':ip.rsplit('.',1)[0]+'.0/'+ip.split('/')[1],'scope':'link','table':100}],'routing-policy':[{'from':ip.split('/')[0]+'/32','table':100,'priority':100}]},'ens4':{'addresses':['192.168.15.%d/24'%oob],'routes':[{'to':'default','via':'192.168.15.2'}],'nameservers':{'addresses':['1.1.1.1','8.8.8.8']}}}}
 if name=='wan-test': data['ethernets']['ens3']['routes'] += [{'to':'10.1.0.0/16','via':gw}]
 user={'hostname':name,'manage_etc_hosts':True,'users':[{'name':'labadmin','groups':['sudo'],'shell':'/bin/bash','sudo':'ALL=(ALL) NOPASSWD:ALL','ssh_authorized_keys':[key],'lock_passwd':True}],'ssh_pwauth':False,'write_files':[{'path':'/etc/ssh/sshd_config.d/bks4.conf','content':'PasswordAuthentication no\nPermitRootLogin no\n'}]}
 (seed/'user-data').write_text('#cloud-config\n'+json.dumps(user))
 (seed/'meta-data').write_text(json.dumps({'instance-id':'bks4-'+name,'local-hostname':name}))
 (seed/'network-config').write_text(json.dumps(data))
 subprocess.run(['qemu-img','create','-f','qcow2','-F','qcow2','-b',str(base),str(image/'virtioa.qcow2')],check=True)
 subprocess.run(['genisoimage','-quiet','-output',str(image/'cdrom.iso'),'-volid','cidata','-joliet','-rock','user-data','meta-data','network-config'],cwd=seed,check=True)
 print(name,ip,oob)
