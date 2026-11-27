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
apt-get install -y --no-install-recommends curl jq openssl ca-certificates python3-venv python3-yaml nodejs npm build-essential git nftables tcpdump tshark chrony
