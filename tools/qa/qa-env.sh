#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --help|-h) echo 'Usage: qa-env.sh [--out DIR] [--dry-run] (read-only inventory)'; exit 0 ;;
  --dry-run) echo 'Would collect read-only tool, ref, disk and ADB metadata under the shared device lock.'; exit 0 ;;
esac
exec python3 "$ROOT/tools/qa/qa.py" env "$@"
