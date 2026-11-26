#!/usr/bin/env bash
set -euo pipefail
# The FTP password is supplied via standard input.
IFS= read -r ftp_password
id bksftp >/dev/null 2>&1 || useradd --create-home --shell /bin/bash bksftp
printf 'bksftp:%s\n' "$ftp_password" | chpasswd
install -d -o ubuntu -g ubuntu -m 0755 /home/ubuntu/bks6/incoming
printf 'BKS6: FTP and SFTP transfer the same control file.\n' > /home/ubuntu/bks6/control.txt
install -m 0644 /home/ubuntu/bks6/control.txt /home/bksftp/control.txt
cat > /etc/vsftpd.conf <<'CONF'
listen=YES
listen_ipv6=NO
listen_address=192.168.106.20
anonymous_enable=NO
local_enable=YES
write_enable=NO
download_enable=YES
local_root=/home/bksftp
userlist_enable=YES
userlist_deny=NO
userlist_file=/etc/vsftpd.bks6-users
pasv_enable=YES
pasv_min_port=41000
pasv_max_port=41010
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
CONF
printf 'bksftp\n' > /etc/vsftpd.bks6-users
systemctl enable --now vsftpd
systemctl restart vsftpd
sha256sum /home/ubuntu/bks6/control.txt /home/bksftp/control.txt
ss -lnt | awk 'NR == 1 || $4 ~ /:(21|22)$/'
