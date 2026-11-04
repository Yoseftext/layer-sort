#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --help|-h) exec python3 "$ROOT/tools/qa/qa.py" provenance --help ;;
  --dry-run) echo 'Would inspect APK manifest/cert/hash, optionally compare downloaded CI artifact and installed APK under the device lock.'; exit 0 ;;
esac
exec python3 "$ROOT/tools/qa/qa.py" provenance "$@"
