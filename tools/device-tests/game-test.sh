#!/usr/bin/env bash
# G1 runtime check: launch the GDScript APK, verify startup/portrait/rendering,
# keep it alive for the requested duration, and preserve all evidence.
set -Eeuo pipefail

PKG="${LAYER_SORT_PACKAGE:-com.yoseftext.layersort.dev}"
READY_MARKER="${LAYER_SORT_READY_MARKER:-LAYER_SORT_G1_READY}"
TICK_MARKER="${LAYER_SORT_TICK_MARKER:-LAYER_SORT_G1_TICK}"
TAP_MARKER="${LAYER_SORT_TAP_MARKER:-LAYER_SORT_G1_TAP}"
GODOT_VERSION="${LAYER_SORT_GODOT_VERSION:-4.7.2.stable.official}"
LAUNCH_COMPONENT="${LAYER_SORT_LAUNCH_COMPONENT:-com.godot.game.GodotAppLauncher}"
DURATION="${1:-30}"
BASE="${LAYER_SORT_DEVICE_TEST_BASE:-/root/device-tests}"
PY="${LAYER_SORT_TEST_PYTHON:-/root/device-tests/.venv/bin/python}"
NOTIFY="/data/data/com.termux/files/usr/bin/termux-notification"

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || (( DURATION < 5 || DURATION > 7200 )); then
    echo "Usage: game-test SECONDS (5 to 7200)"
    exit 2
fi

mkdir -p "$BASE/runs"

# Shared phone reservation: never run a second device test concurrently.
exec 9>"$BASE/test.lock"
flock -w 900 9 || {
    echo "ERROR: Phone busy for more than 15 minutes."
    exit 75
}

RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
OUT="$BASE/runs/$RUN_ID"
mkdir -p "$OUT"
ln -sfnT "$OUT" "$BASE/latest-run"

START_TIME="$(date -Is)"
START_EPOCH="$(date +%s)"
PID_START=""
PID_END=""
TICKS=0
READY_COUNT=0
TAP_COUNT=0
REASON=""
ORIENTATION="UNKNOWN"
ORIENTATION_RAW=""
SCREEN_W=0
SCREEN_H=0
MEAN_BRIGHTNESS=0
SAMPLED_COLORS=0
RENDERER=""
VERSION_NAME=""
VERSION_CODE=""
FATALS=""
FG_START=""
FG_END=""
FG_BEFORE=""
WAKE_END=""

# Foreground package from WindowManager. Godot runs in one activity, and a
# notification/launcher/app switch pauses it, which stops the heartbeat ticks.
foreground_package() {
    local line win comp
    line="$(adb shell dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus=' || true)"
    [[ "$line" == *Window{* ]] || return 0
    win="${line#*Window\{}"
    win="${win%%\}*}"
    comp="${win##* }"
    printf '%s\n' "${comp%%/*}"
}

wakefulness() {
    adb shell dumpsys power 2>/dev/null |
        sed -n 's/.*mWakefulness=\([A-Za-z]*\).*/\1/p' | head -1
}

finish() {
    RC="$1"
    trap - EXIT
    set +e

    END_TIME="$(date -Is)"
    ELAPSED="$(( $(date +%s) - START_EPOCH ))"

    if [[ ! -s "$OUT/logcat.txt" ]]; then
        adb logcat -d -v threadtime > "$OUT/logcat.txt" 2>/dev/null
    fi
    adb logcat -b crash -d -v threadtime > "$OUT/crash.txt" 2>/dev/null
    if [[ ! -s "$OUT/final.png" ]]; then
        adb exec-out screencap -p > "$OUT/final.png" 2>/dev/null || true
    fi

    if [[ -f "$OUT/logcat.txt" ]]; then
        TICKS="$(grep -c "$TICK_MARKER" "$OUT/logcat.txt" || true)"
        READY_COUNT="$(grep -c "$READY_MARKER" "$OUT/logcat.txt" || true)"
        TAP_COUNT="$(grep -c "$TAP_MARKER" "$OUT/logcat.txt" || true)"
        if [[ -z "$FATALS" ]]; then
            FATALS="$(grep -nE 'FATAL EXCEPTION|Fatal signal|libc: Fatal|SCRIPT ERROR|Parse Error|Failed to load scene' "$OUT/logcat.txt" || true)"
            if [[ -n "$FATALS" ]]; then
                printf '%s\n' "$FATALS" > "$OUT/fatal.txt"
            fi
        fi
    fi

    if [[ -z "$REASON" && "$RC" -ne 0 ]]; then
        REASON="Runtime check failed (exit $RC)"
    fi

    if (( RC == 0 )); then
        STATUS="PASS"
        TITLE="Layer Sort G1 - PASS"
    else
        STATUS="FAIL"
        TITLE="Layer Sort G1 - FAIL"
    fi

    jq -n \
      --arg status "$STATUS" \
      --arg run_id "$RUN_ID" \
      --arg package "$PKG" \
      --arg started "$START_TIME" \
      --arg ended "$END_TIME" \
      --arg reason "$REASON" \
      --arg pid_start "$PID_START" \
      --arg pid_end "$PID_END" \
      --arg orientation "$ORIENTATION" \
      --arg orientation_raw "$ORIENTATION_RAW" \
      --arg renderer "$RENDERER" \
      --arg version_name "$VERSION_NAME" \
      --arg version_code "$VERSION_CODE" \
      --arg foreground_start "$FG_START" \
      --arg foreground_end "$FG_END" \
      --arg foreground_before "$FG_BEFORE" \
      --arg wakefulness_end "$WAKE_END" \
      --argjson requested_seconds "$DURATION" \
      --argjson elapsed_seconds "$ELAPSED" \
      --argjson ready_count "$READY_COUNT" \
      --argjson tick_count "$TICKS" \
      --argjson tap_count "$TAP_COUNT" \
      --argjson screen_width "$SCREEN_W" \
      --argjson screen_height "$SCREEN_H" \
      --argjson mean_brightness "$MEAN_BRIGHTNESS" \
      --argjson sampled_colors "$SAMPLED_COLORS" \
      --argjson exit_code "$RC" \
      '{
        status: $status,
        run_id: $run_id,
        package: $package,
        started_at: $started,
        finished_at: $ended,
        requested_seconds: $requested_seconds,
        elapsed_seconds: $elapsed_seconds,
        pid_start: $pid_start,
        pid_end: $pid_end,
        ready_count: $ready_count,
        tick_count: $tick_count,
        tap_count: $tap_count,
        orientation: $orientation,
        orientation_raw: $orientation_raw,
        renderer: $renderer,
        version_name: $version_name,
        version_code: $version_code,
        foreground_start: $foreground_start,
        foreground_end: $foreground_end,
        foreground_before: $foreground_before,
        wakefulness_end: $wakefulness_end,
        screenshot: {
          width: $screen_width,
          height: $screen_height,
          mean_brightness: $mean_brightness,
          sampled_colors: $sampled_colors
        },
        exit_code: $exit_code,
        reason: $reason
      }' > "$OUT/status.json"

    echo "===== RESULT: $STATUS ====="
    echo "Package: $PKG"
    echo "Duration: ${ELAPSED}s"
    echo "Ready markers: $READY_COUNT; ticks: $TICKS"
    echo "Report: $OUT/status.json"

    if [[ -x "$NOTIFY" ]]; then
        timeout 12s "$NOTIFY" --id 4402 --title "$TITLE" \
            --content "Finished in ${ELAPSED}s; ticks: $TICKS; $STATUS" \
            --sound > "$OUT/notification.log" 2>&1 || true
    fi

    adb shell am force-stop "$PKG" >/dev/null 2>&1 || true
    exit "$RC"
}

trap 'finish "$?"' EXIT

echo "===== RUN: $RUN_ID ====="
echo "===== CONNECTING ====="

phone-connect | tee "$OUT/connect.txt"

{
    echo "===== adb devices -l ====="
    adb devices -l
    echo "===== ro.product.model ====="
    adb shell getprop ro.product.model
    echo "===== ro.product.device ====="
    adb shell getprop ro.product.device
    echo "===== ro.build.version.release ====="
    adb shell getprop ro.build.version.release
    echo "===== ro.build.version.sdk ====="
    adb shell getprop ro.build.version.sdk
    echo "===== wm size ====="
    adb shell wm size
    echo "===== wm density ====="
    adb shell wm density
} > "$OUT/device.txt" 2>&1

echo "===== WAKING DEVICE ====="
adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
sleep 1
adb shell wm dismiss-keyguard >/dev/null 2>&1 || true
WAKE_START="$(wakefulness)"
if [[ "$WAKE_START" != "Awake" ]]; then
    REASON="Device is not awake (${WAKE_START:-unknown}); wake and unlock the phone"
    exit 1
fi
FG_BEFORE="$(foreground_package)"
echo "Foreground before launch: ${FG_BEFORE:-unknown}" > "$OUT/foreground-before.txt"

echo "===== LAUNCHING GDScript APP ====="
adb shell am force-stop "$PKG"
adb logcat -c
# Explicit component: the package's launcher is an exported alias that targets
# GodotApp, and monkey can be intercepted by the OEM app-switch manager.
adb shell am start -W -a android.intent.action.MAIN \
    -c android.intent.category.LAUNCHER \
    -n "$PKG/$LAUNCH_COMPONENT" > "$OUT/launch.txt" 2>&1 || {
        REASON="Explicit activity launch failed"
        exit 1
    }

for _ in $(seq 1 20); do
    PID_START="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
    [[ -n "$PID_START" ]] && break
    sleep 1
done

if [[ -z "$PID_START" ]]; then
    REASON="Game process not found after launch"
    exit 1
fi

READY_LOG=""
for _ in $(seq 1 45); do
    READY_LOG="$(adb logcat -d -v threadtime 2>/dev/null || true)"
    if grep -q "$READY_MARKER" <<< "$READY_LOG"; then
        break
    fi
    sleep 1
done

if ! grep -q "$READY_MARKER" <<< "$READY_LOG"; then
    REASON="GDScript ready marker not found within 45s"
    printf '%s\n' "$READY_LOG" > "$OUT/logcat.txt"
    exit 1
fi

FG_START="$(foreground_package)"
printf '%s %s\n' "$(date -Is)" "$FG_START" > "$OUT/foreground.txt"
if [[ "$FG_START" != "$PKG" ]]; then
    REASON="Game is not foreground after READY (${FG_START:-unknown})"
    exit 1
fi

adb exec-out screencap -p > "$OUT/start.png"

echo "Game PID: $PID_START"
echo "===== MONITORING ====="

while (( $(date +%s) - START_EPOCH < DURATION )); do
    sleep 2
    PID_END="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
    if [[ "$PID_END" != "$PID_START" ]]; then
        REASON="Game stopped or restarted during test (start=$PID_START end=$PID_END)"
        exit 1
    fi
    FG_END="$(foreground_package)"
    WAKE_END="$(wakefulness)"
    printf '%s %s %s\n' "$(date -Is)" "${FG_END:-unknown}" "${WAKE_END:-unknown}" \
        >> "$OUT/foreground.txt"
    if [[ "$FG_END" != "$PKG" ]]; then
        REASON="Foreground left the game during runtime (now ${FG_END:-unknown})"
        exit 1
    fi
    if [[ "$WAKE_END" != "Awake" ]]; then
        REASON="Device went to sleep during runtime (${WAKE_END:-unknown})"
        exit 1
    fi
done

FG_END="$(foreground_package)"
WAKE_END="$(wakefulness)"
if [[ "$FG_END" != "$PKG" ]]; then
    REASON="Game is not foreground at end of runtime (${FG_END:-unknown})"
    exit 1
fi
if [[ "$WAKE_END" != "Awake" ]]; then
    REASON="Device is not awake at end of runtime (${WAKE_END:-unknown})"
    exit 1
fi

adb exec-out screencap -p > "$OUT/final.png"
adb logcat -d -v threadtime > "$OUT/logcat.txt"
adb shell dumpsys package "$PKG" > "$OUT/package.txt" 2>&1 || true

TICKS="$(grep -c "$TICK_MARKER" "$OUT/logcat.txt" || true)"
READY_COUNT="$(grep -c "$READY_MARKER" "$OUT/logcat.txt" || true)"
TAP_COUNT="$(grep -c "$TAP_MARKER" "$OUT/logcat.txt" || true)"
MIN_TICKS=$(( DURATION / 10 ))
(( MIN_TICKS < 1 )) && MIN_TICKS=1

if (( READY_COUNT < 1 )); then
    REASON="Ready marker missing from final logcat"
    exit 1
fi
if (( TICKS < MIN_TICKS )); then
    REASON="Too few runtime ticks: $TICKS < $MIN_TICKS"
    exit 1
fi

ORIENTATION_RAW="$(adb shell dumpsys input | awk '/SurfaceOrientation:/{print $2; exit}')"
case "$ORIENTATION_RAW" in
    0|2) ORIENTATION="PORTRAIT" ;;
    1|3) ORIENTATION="LANDSCAPE" ;;
    *)   ORIENTATION="UNKNOWN" ;;
esac
if [[ "$ORIENTATION" != "PORTRAIT" ]]; then
    REASON="Device orientation is $ORIENTATION (raw $ORIENTATION_RAW)"
    exit 1
fi

STATS="$("$PY" - "$OUT/final.png" <<'PY'
import sys
from PIL import Image, ImageStat

with Image.open(sys.argv[1]) as image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    mean = sum(ImageStat.Stat(rgb).mean) / 3.0
    colors = len(rgb.resize((64, 64)).getcolors(maxcolors=4096) or [])
print(width, height, f"{mean:.2f}", colors)
PY
)" || {
    REASON="Could not read final screenshot statistics"
    exit 1
}
read -r SCREEN_W SCREEN_H MEAN_BRIGHTNESS SAMPLED_COLORS <<< "$STATS"

if (( SCREEN_H <= SCREEN_W )); then
    REASON="Screenshot is not portrait: ${SCREEN_W}x${SCREEN_H}"
    exit 1
fi
if awk -v mean="$MEAN_BRIGHTNESS" 'BEGIN { exit !(mean < 5.0) }'; then
    REASON="Final screenshot looks black (mean $MEAN_BRIGHTNESS)"
    exit 1
fi
if (( SAMPLED_COLORS < 4 )); then
    REASON="Final screenshot has too few colours ($SAMPLED_COLORS)"
    exit 1
fi

if ! grep -q "Godot Engine v$GODOT_VERSION" "$OUT/logcat.txt"; then
    REASON="Pinned Godot startup line missing from logcat"
    exit 1
fi

RENDERER="$(grep -iE 'OpenGL|GLES|Vulkan|Compatibility' "$OUT/logcat.txt" | grep -i godot | head -1 || true)"
if [[ -z "$RENDERER" ]]; then
    REASON="No renderer evidence in logcat"
    exit 1
fi

FATALS="$(grep -nE 'FATAL EXCEPTION|Fatal signal|libc: Fatal|SCRIPT ERROR|Parse Error|Failed to load scene' "$OUT/logcat.txt" || true)"
if [[ -n "$FATALS" ]]; then
    printf '%s\n' "$FATALS" > "$OUT/fatal.txt"
    REASON="Fatal log lines found"
    exit 1
fi

VERSION_NAME="$(awk -F= '/versionName=/{print $2; exit}' "$OUT/package.txt" | tr -d '\r ')"
VERSION_CODE="$(awk -F= '/versionCode=/{print $2; exit}' "$OUT/package.txt" | awk '{print $1}' | tr -d '\r ')"
if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" ]]; then
    REASON="Could not read installed package version"
    exit 1
fi

PID_END="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
if [[ "$PID_END" != "$PID_START" ]]; then
    REASON="Game process changed at final check (start=$PID_START end=$PID_END)"
    exit 1
fi

FG_END="$(foreground_package)"
WAKE_END="$(wakefulness)"
if [[ "$FG_END" != "$PKG" ]]; then
    REASON="Foreground left the game before the final check (${FG_END:-unknown})"
    exit 1
fi
if [[ "$WAKE_END" != "Awake" ]]; then
    REASON="Device is not awake at the final check (${WAKE_END:-unknown})"
    exit 1
fi

echo "===== G1 RUNTIME PASSED ====="
echo "Orientation: $ORIENTATION ($ORIENTATION_RAW)"
echo "Renderer: $RENDERER"
echo "Version: $VERSION_NAME ($VERSION_CODE)"
echo "Ticks: $TICKS; ready: $READY_COUNT; taps: $TAP_COUNT"
exit 0
