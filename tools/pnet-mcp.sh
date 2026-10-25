#!/bin/sh
# MCP pnetlab для этого репо (.mcp.json): python из venv MCP-сервера + tools/pnet-mcp.py (аккаунт из .pnet-account).
# venv: $PNETLAB_MCP_PY или ~/mcp/pnetlab-mcp-server/.venv (см. TEAM.md).
PY=${PNETLAB_MCP_PY:-$HOME/mcp/pnetlab-mcp-server/.venv/bin/python}
[ -x "$PY" ] || { echo "pnet-mcp: нет $PY — установить MCP-сервер (TEAM.md) или задать PNETLAB_MCP_PY" >&2; exit 1; }
exec "$PY" "$(dirname "$0")/pnet-mcp.py"
