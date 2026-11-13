#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
exec /usr/bin/python3 "$ROOT/tools/agents/task_ledger.py" "$@"
