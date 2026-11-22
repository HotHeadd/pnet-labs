#!/usr/bin/env bash
set -euo pipefail

# Start from the configuration installed by setup-suricata.sh.
feed=${1:?Usage: update-ids-rules.sh et-open-icmp.rules}
threshold=${2:-}
yaml=/etc/suricata/bks5.yaml
target=/etc/suricata/bks5-et-icmp.rules
threshold_target=/etc/suricata/bks5-threshold.config
candidate=$(mktemp /etc/suricata/.bks5-yaml.XXXXXX)
fallback=$(mktemp -d /etc/suricata/.bks5-rules.XXXXXX)
dropin=/etc/systemd/system/bks5-suricata.service.d/10-rules.conf
keep=0
cleanup() {
  if [[ $keep == 0 ]]; then
    cp -p "$fallback/yaml" "$yaml"
    if [[ -e $fallback/feed ]]; then cp -p "$fallback/feed" "$target"; else rm -f -- "$target"; fi
    if [[ -e $fallback/threshold ]]; then cp -p "$fallback/threshold" "$threshold_target"; else rm -f -- "$threshold_target"; fi
    if [[ -e $fallback/dropin ]]; then cp -p "$fallback/dropin" "$dropin"; else rm -f -- "$dropin"; fi
    systemctl daemon-reload
    systemctl restart bks5-suricata.service
  fi
  rm -f -- "$candidate" "$fallback/yaml" "$fallback/feed" "$fallback/threshold" "$fallback/dropin"
  rmdir "$fallback"
}

cp -p "$yaml" "$fallback/yaml"
if [[ -e $target ]]; then cp -p "$target" "$fallback/feed"; fi
if [[ -e $threshold_target ]]; then cp -p "$threshold_target" "$fallback/threshold"; fi
if [[ -e $dropin ]]; then cp -p "$dropin" "$fallback/dropin"; fi
trap cleanup EXIT
install -m 0644 "$feed" "$target"
if [[ -n $threshold ]]; then install -m 0644 "$threshold" "$threshold_target"; fi

python3 - "$yaml" "$candidate" "$threshold" <<'PY'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
replacement = 'rule-files:\n  - /etc/suricata/bks5.rules\n  - /etc/suricata/bks5-et-icmp.rules\n'
yaml, count = re.subn(r'(?m)^rule-files:[^\n]*\n(?:[ \t]+[^\n]*\n|\n)*', replacement + '\n', source)
if count != 1:
    raise SystemExit('Cannot locate a unique rule-files list')
if sys.argv[3]:
    yaml = re.sub(r'(?m)^threshold-file:[^\n]*\n', '', yaml)
    yaml += '\nthreshold-file: /etc/suricata/bks5-threshold.config\n'
Path(sys.argv[2]).write_text(yaml)
PY

suricata -T -c "$candidate" -l /var/log/bks5-suricata
install -m 0644 "$candidate" "$yaml"
install -d "$(dirname "$dropin")"
cat > "$dropin" <<'UNIT'
[Service]
ExecStart=
ExecStart=/usr/bin/suricata --af-packet=ens3 -k none -c /etc/suricata/bks5.yaml -l /var/log/bks5-suricata
UNIT
systemctl daemon-reload
systemctl restart bks5-suricata.service
sleep 3
systemctl is-active bks5-suricata.service
keep=1
