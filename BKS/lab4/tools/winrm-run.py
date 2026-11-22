#!/usr/bin/env python3
"""Run a PowerShell file through the host-only SSH tunnel (NTLM message encryption)."""
import os,sys
from pathlib import Path
import winrm
password=Path(os.environ.get('WINRM_PASSWORD_FILE','/tmp/bks4-windows-password')).read_text().strip()
s=winrm.Session(os.environ.get('WINRM_URL','http://127.0.0.1:15985/wsman'),auth=('Administrator',password),transport='ntlm')
ps="$ProgressPreference='SilentlyContinue';$OutputEncoding=[Console]::OutputEncoding=[Text.UTF8Encoding]::new();\n"+Path(sys.argv[1]).read_text()
r=s.run_ps(ps);out=r.std_out.decode('utf-8',errors='replace');err=r.std_err.decode('utf-8',errors='replace')
if len(sys.argv)>2:Path(sys.argv[2]).write_text(out)
print(out,end='')
if err and r.status_code:print(err,file=sys.stderr)
raise SystemExit(r.status_code)
