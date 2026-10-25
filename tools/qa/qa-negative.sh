#!/usr/bin/env bash
# Local, read-only controlled failures. A case that returns 0 is a test failure.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --help|-h) echo 'Usage: qa-negative.sh --apk VERIFIED_APK [--out DIR] [--dry-run]'; exit 0 ;;
  --dry-run) echo 'Would run three read-only negative APK oracle fixtures; no device access.'; exit 0 ;;
esac
[[ "${1:-}" == '--apk' && $# -ge 2 ]] || { echo 'Usage: qa-negative.sh --apk VERIFIED_APK [--out DIR]' >&2; exit 2; }
APK="$2"; shift 2
OUT="/tmp/opencode/qa-negative-$(date +%Y%m%d-%H%M%S)"
if [[ "${1:-}" == --out && $# -ge 2 ]]; then OUT="$2"; shift 2; fi
(( $# == 0 )) || exit 2
mkdir -p "$OUT"
pass=0
for id in NEG-01 NEG-02 NEG-03; do
  case "$id" in
    NEG-01) opt=(--package com.yoseftext.wrong.dev) ;;
    NEG-02) opt=(--orientation LANDSCAPE) ;;
    NEG-03) opt=(--sha256 "$(printf '%064d' 0)") ;;
  esac
  if python3 "$ROOT/tools/qa/qa.py" provenance --apk "$APK" "${opt[@]}" --out "$OUT/$id" > "$OUT/$id-console.json"; then
    echo "$id FALSE_PASS"; exit 1
  fi
  jq -e --arg id "$id" '.status == "FAIL" and any(.checks[]; .id == $id and .status == "FAIL")' "$OUT/$id/report.json" >/dev/null || {
    echo "$id FAILURE_NOT_DETECTED"; exit 1;
  }
  echo "$id EXPECTED_FAIL"; ((pass+=1))
done
echo "NEGATIVE_SUITE_PASS: $pass/3 expected FAIL verdicts; $OUT"
