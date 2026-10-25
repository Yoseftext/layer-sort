#!/usr/bin/env bash
# One bounded touch check, installed APK provenance and foreground evidence.
# Never masks the original agentctl verdict; uses existing device lock.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
usage() { echo 'Usage: qa-touch.sh --apk FILE --run-id CI_ID --sha256 HASH --out DIR'; }
APK='' RUN='' SHA='' OUT=''
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --apk|--run-id|--sha256|--out)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      case "$1" in
        --apk) APK="$2" ;;
        --run-id) RUN="$2" ;;
        --sha256) SHA="$2" ;;
        --out) OUT="$2" ;;
      esac
      shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$APK" && -n "$RUN" && -n "$SHA" && -n "$OUT" ]] || { usage >&2; exit 2; }
mkdir -p "$OUT"
python3 "$ROOT/tools/qa/qa.py" provenance --apk "$APK" --run-id "$RUN" \
  --sha256 "$SHA" --installed --out "$OUT/provenance" > "$OUT/provenance-console.json" || exit 1
# No retry: every unexpected focus/marker verdict remains a real failure.
agentctl touch g15-acceptance > "$OUT/touch.log" 2>&1 || { echo 'FAIL: agentctl touch (see touch.log)' >&2; exit 1; }
run="$(sed -n 's/^Saved to: //p' "$OUT/touch.log" | tail -1)"
[[ -n "$run" && -f "$run/status.json" ]] || { echo 'FAIL: missing touch status' >&2; exit 1; }
"${LAYER_SORT_TEST_PYTHON:-/root/device-tests/.venv/bin/python}" "$ROOT/tools/qa/qa-focus.py" \
  --before "$run/before.png" --reference "$ROOT/docs/evidence/g15/smoke.png" \
  > "$OUT/focus.json" || { echo 'FAIL: off-game foreground evidence' >&2; exit 1; }
python3 - "$run/status.json" "$OUT/focus.json" <<'PY'
import json,sys
status=json.load(open(sys.argv[1]));focus=json.load(open(sys.argv[2]))
assert status['status']=='PASS' and status['foreground_package']=='com.yoseftext.layersort.dev'
assert status['tap_marker_count']>=1 and status['screenshot_change']['changed'] is True
assert focus['status']=='PASS'
print('PASS: foreground, TAP logcat marker and visual touch change; '+sys.argv[1])
PY
