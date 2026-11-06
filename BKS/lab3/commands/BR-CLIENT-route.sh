#!/bin/bash
set -euo pipefail
# The Xray first hop must also use the simulated WAN, not management.
python3 - <<'PY'
import yaml
p='/etc/netplan/50-cloud-init.yaml'
with open(p) as f:
    d=yaml.safe_load(f)
r=d['network']['ethernets']['ens3'].setdefault('routes',[])
entry={'to':'203.0.113.0/24','via':'10.2.20.1'}
if entry not in r:
    r.append(entry)
with open(p,'w') as f:
    yaml.safe_dump(d,f)
PY
chmod 600 /etc/netplan/50-cloud-init.yaml
ip route replace 203.0.113.0/24 via 10.2.20.1 dev ens3
