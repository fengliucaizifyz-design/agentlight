#!/bin/sh
set -eu

STATE="${1:-working}"
LOG="${CODEX_HOME:-$HOME/.codex}/hooks/agentlight.log"

case "$STATE" in
  idle|working|confirm|error|offline) ;;
  *) STATE="error" ;;
esac

mkdir -p "$(dirname "$LOG")"
printf '%s state=%s source=codex\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STATE" >>"$LOG" 2>/dev/null || true

/usr/bin/curl -sS --max-time 1 \
  -X POST "http://localhost:9527/state" \
  -H "Content-Type: application/json" \
  -d "{\"state\":\"$STATE\",\"source\":\"codex\"}" \
  >/dev/null 2>&1 || true

exit 0
