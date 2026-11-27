#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cat > /etc/apt/apt.conf.d/99-sa7 <<'EOF'
Acquire::ForceIPv4 "true";
Acquire::Languages "none";
Acquire::Retries "3";
EOF
sed -i 's@http://@https://@g' /etc/apt/sources.list.d/ubuntu.sources
apt-get update
apt-get install -y --no-install-recommends xorg xfce4 lightdm dbus-x11 xterm xfce4-terminal xdotool x11-utils x11-xserver-utils openjdk-17-jre gajim libnss3-tools libnss3 libgbm1 libasound2t64 libatk-bridge2.0-0 libgtk-3-0t64 curl jq openssl ca-certificates python3-venv python3-yaml nmap tcpdump tshark chrony
