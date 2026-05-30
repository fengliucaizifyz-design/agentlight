#!/bin/sh
set -eu

STATE="${1:-working}"

case "$STATE" in
  idle|working|confirm|error|offline) ;;
  *) STATE="error" ;;
esac

/usr/bin/curl -sS --max-time 1 \
  -X POST "http://localhost:9527/state" \
  -H "Content-Type: application/json" \
  -d "{\"state\":\"$STATE\",\"source\":\"codex\"}" \
  >/dev/null 2>&1 || true

exit 0
