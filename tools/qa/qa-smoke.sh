#!/usr/bin/env bash
# Bounds device test via existing agentctl. No raw ADB action or service edits.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
usage() { echo 'Usage: qa-smoke.sh --apk FILE --run-id CI_ID [--sha256 HASH] [--out DIR] [--dry-run]'; }
APK='' SHA='' RUN='' OUT='' DRY=0
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY=1; shift ;;
    --apk|--sha256|--run-id|--out)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      case "$1" in
        --apk) APK="$2" ;;
        --sha256) SHA="$2" ;;
        --run-id) RUN="$2" ;;
        --out) OUT="$2" ;;
      esac
      shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$APK" && -n "$RUN" ]] || { echo 'FAIL: --apk and --run-id required to prove CI artifact provenance' >&2; usage >&2; exit 2; }
if (( DRY )); then
  echo "Would verify APK provenance, install the project app via agentctl, then run locked smoke and touch checks."
  exit 0
fi
[[ -n "$OUT" ]] || OUT="/tmp/opencode/qa-smoke-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
finish() {
  local rc="$1"
  trap - EXIT
  python3 "$ROOT/tools/qa/qa-device-report.py" --out "$OUT" --exit "$rc" || true
}
trap 'finish "$?"' EXIT
args=(--apk "$APK" --installed --out "$OUT/provenance")
[[ -z "$SHA" ]] || args+=(--sha256 "$SHA")
[[ -z "$RUN" ]] || args+=(--run-id "$RUN")
# Install only the verified project APK. Check offline identity before altering
# phone state. Never install an unverified input; agentctl owns the lock.
pre=(--apk "$APK" --out "$OUT/preflight")
[[ -z "$SHA" ]] || pre+=(--sha256 "$SHA")
[[ -z "$RUN" ]] || pre+=(--run-id "$RUN")
python3 "$ROOT/tools/qa/qa.py" provenance "${pre[@]}" > "$OUT/preflight.json" || exit 1
agentctl install "$APK" > "$OUT/install.log" 2>&1 || { echo 'FAIL: install (see install.log)' >&2; exit 1; }
python3 "$ROOT/tools/qa/qa.py" provenance "${args[@]}" > "$OUT/provenance.json" || exit 1
agentctl smoke g15 > "$OUT/smoke.log" 2>&1 || { echo 'FAIL: smoke (see smoke.log)' >&2; exit 1; }
agentctl touch g15 > "$OUT/touch.log" 2>&1 || { echo 'FAIL: touch (see touch.log)' >&2; exit 1; }
touch_run="$(sed -n 's/^Saved to: //p' "$OUT/touch.log" | tail -1)"
[[ -n "$touch_run" ]] || { echo 'FAIL: touch run directory missing' >&2; exit 1; }
"${LAYER_SORT_TEST_PYTHON:-/root/device-tests/.venv/bin/python}" "$ROOT/tools/qa/qa-focus.py" \
  --before "$touch_run/before.png" --reference "$ROOT/docs/evidence/g15/smoke.png" \
  > "$OUT/focus.json" || { echo 'FAIL: touch began outside verified G1 title (see focus.json)' >&2; exit 1; }
echo "PASS: provenance, install, smoke, touch; evidence: $OUT"
