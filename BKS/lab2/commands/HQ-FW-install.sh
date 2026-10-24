#!/bin/sh
# Установка пакетов на HQ-FW (Ubuntu 22.04). Интернет на время установки — через облако (ens5).
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get update
apt-get -y full-upgrade
apt-get -y install --no-install-recommends \
  iptables-persistent conntrack wireguard wireguard-tools \
  xtables-addons-dkms xtables-addons-common dkms build-essential \
  linux-headers-generic "linux-headers-$(uname -r)" \
  fail2ban unattended-upgrades lynis rkhunter chkrootkit auditd etckeeper git tcpdump
echo INSTALL-DONE
