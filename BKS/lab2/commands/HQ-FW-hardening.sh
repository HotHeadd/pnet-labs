#!/bin/sh
# HQ-FW: remote access, backups, updates, extra protection (lab 2, aspects 1, 2, 4, 5)

# --- SSH: key-only for fwadmin, no root, strong algorithms ---
# admin public key (generated on the admin workstation, fetched over MGMT to /root/admin.pub)
install -d -m 700 -o fwadmin -g fwadmin /home/fwadmin/.ssh
cp /root/admin.pub /home/fwadmin/.ssh/authorized_keys
chown fwadmin:fwadmin /home/fwadmin/.ssh/authorized_keys; chmod 600 /home/fwadmin/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/90-hq-fw.conf <<'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers fwadmin
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
Banner /etc/issue.net
EOF
echo 'Authorized access only. All activity is logged.' > /etc/issue.net
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
# rkhunter reads only the main sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sshd -t && systemctl restart ssh

# --- fail2ban: SSH brute force -> ban 1 h ---
cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 3
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban; systemctl restart fail2ban

# --- auditd: watch firewall/VPN/SSH configs ---
cat > /etc/audit/rules.d/hq-fw.rules <<'EOF'
-w /etc/iptables/ -p wa -k fw-rules
-w /etc/wireguard/ -p wa -k vpn-config
-w /etc/ssh/sshd_config.d/ -p wa -k ssh-config
-w /etc/netplan/ -p wa -k net-config
-w /usr/sbin/iptables -p x -k fw-exec
EOF
augenrules --load; systemctl enable --now auditd

# --- automatic security updates ---
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# --- unused services off ---
systemctl disable --now snapd.service snapd.socket multipathd.service ModemManager.service 2>/dev/null
systemctl mask snapd.service snapd.socket 2>/dev/null

# --- backups: etckeeper (git /etc) + daily config archive, 14 copies ---
etckeeper init 2>/dev/null; etckeeper commit 'HQ-FW lab2 baseline' 2>/dev/null
cat > /usr/local/sbin/hq-fw-backup <<'EOF'
#!/bin/sh
D=/var/backups/hq-fw; mkdir -p $D; chmod 700 $D
iptables-save > /etc/iptables/rules.v4.live
tar czf $D/hq-fw-$(date +%F-%H%M).tgz /etc/iptables /etc/wireguard /etc/ssh/sshd_config.d \
  /etc/netplan /etc/sysctl.d/90-hq-fw.conf /etc/fail2ban/jail.d /etc/audit/rules.d 2>/dev/null
ls -1t $D/*.tgz | tail -n +15 | xargs -r rm -f
EOF
chmod 700 /usr/local/sbin/hq-fw-backup
echo '30 2 * * * root /usr/local/sbin/hq-fw-backup' > /etc/cron.d/hq-fw-backup
/usr/local/sbin/hq-fw-backup
# --- rkhunter: known false positives (sshd drop-in, etckeeper files) ---
cat >> /etc/rkhunter.conf.local <<'EOF2'
ALLOW_SSH_ROOT_USER=no
ALLOWHIDDENDIR=/etc/.git
ALLOWHIDDENFILE=/etc/.etckeeper
ALLOWHIDDENFILE=/etc/.gitignore
EOF2
echo HARDENING-DONE
