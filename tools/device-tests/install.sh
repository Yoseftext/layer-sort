#!/usr/bin/env bash
# Install/update the Layer Sort G1 device-test tooling.
# Backs up the old C#-specific scripts, never touches services or user data.
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_DIR/tools/device-tests"
BASE="${LAYER_SORT_DEVICE_TEST_BASE:-/root/device-tests}"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BASE/archive-csharp/$STAMP"

mkdir -p "$BASE" "$ARCHIVE" /usr/local/bin

for old in \
  "$BASE/appium-smoke.py" \
  "$BASE/appium-touch.py" \
  "$BASE/game-test"; do
    [[ -f "$old" ]] && cp -p "$old" "$ARCHIVE/" || true
done
for old in /usr/local/bin/agentctl /usr/local/bin/game-test /usr/local/bin/phone-connect; do
    [[ -f "$old" ]] && cp -p "$old" "$ARCHIVE/" || true
done

install -m 755 "$SRC/phone-connect" /usr/local/bin/phone-connect
install -m 755 "$SRC/agentctl" /usr/local/bin/agentctl
install -m 755 "$SRC/game-test.sh" /usr/local/bin/game-test
install -m 644 "$SRC/device_common.py" "$BASE/device_common.py"
install -m 644 "$SRC/appium-smoke.py" "$BASE/appium-smoke.py"
install -m 644 "$SRC/appium-touch.py" "$BASE/appium-touch.py"

bash -n /usr/local/bin/phone-connect /usr/local/bin/agentctl /usr/local/bin/game-test
/root/device-tests/.venv/bin/python -m py_compile \
  "$BASE/device_common.py" "$BASE/appium-smoke.py" "$BASE/appium-touch.py"

echo "Installed G1 device tests."
echo "  /usr/local/bin/agentctl"
echo "  /usr/local/bin/game-test"
echo "  /usr/local/bin/phone-connect"
echo "  $BASE/device_common.py"
echo "  $BASE/appium-smoke.py"
echo "  $BASE/appium-touch.py"
echo "Old scripts backed up to: $ARCHIVE"
