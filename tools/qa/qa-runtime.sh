#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  --help|-h) echo 'Usage: qa-runtime.sh [--dry-run] SECONDS (5..120)'; exit 0 ;;
  --dry-run) echo 'Would run existing locked agentctl runtime with bounded duration.'; exit 0 ;;
esac
DURATION="${1:-30}"
[[ "$DURATION" =~ ^[0-9]+$ ]] && (( DURATION >= 5 && DURATION <= 120 )) || { echo 'FAIL: duration must be 5..120 seconds' >&2; exit 2; }
exec agentctl runtime "$DURATION"
