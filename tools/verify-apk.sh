#!/usr/bin/env bash
# Verify a Layer Sort G1 APK without trusting the export exit code.
# Usage: verify-apk.sh APK [EXPECTED_CERT_SHA256_FILE]
set -Eeuo pipefail

APK="${1:?Usage: verify-apk.sh APK [EXPECTED_CERT_SHA256_FILE]}"
EXPECTED_CERT_FILE="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/device-tests/expected-debug-cert.sha256}"
EXPECTED_PKG="${LAYER_SORT_PACKAGE:-com.yoseftext.layersort.dev}"
EXPECTED_VERSION_NAME="${LAYER_SORT_VERSION_NAME:-0.1.0-g1}"
EXPECTED_VERSION_CODE="${LAYER_SORT_VERSION_CODE:-1}"
AAPT2="${AAPT2:-aapt2}"
APKSIGNER="${APKSIGNER:-apksigner}"

fail() {
    echo "APK_VERIFY_FAIL: $*" >&2
    exit 1
}

[[ -f "$APK" ]] || fail "APK not found: $APK"
[[ -s "$APK" ]] || fail "APK is empty: $APK"
[[ -f "$EXPECTED_CERT_FILE" ]] || fail "Expected cert file not found: $EXPECTED_CERT_FILE"

unzip -t "$APK" >/dev/null || fail "APK is not a valid zip"
ENTRIES="$(unzip -Z1 "$APK")"

grep -qx 'AndroidManifest.xml' <<< "$ENTRIES" || fail "AndroidManifest.xml missing"
grep -qx 'classes.dex' <<< "$ENTRIES" || fail "classes.dex missing"
grep -qx 'lib/arm64-v8a/libgodot_android.so' <<< "$ENTRIES" ||
    fail "lib/arm64-v8a/libgodot_android.so missing"

if grep -Eq '(^|/)libmonosgen|^assets/\.godot/mono/|\.dll$' <<< "$ENTRIES"; then
    grep -En '(^|/)libmonosgen|^assets/\.godot/mono/|\.dll$' <<< "$ENTRIES" >&2 || true
    fail "C#/.NET payload found in a Standard GDScript APK"
fi
if grep -Eq '^lib/(armeabi-v7a|x86|x86_64)/' <<< "$ENTRIES"; then
    fail "Unexpected non-arm64 ABI payload"
fi

BADGING="$("$AAPT2" dump badging "$APK")"
grep -q "^package: name='$EXPECTED_PKG'" <<< "$BADGING" ||
    fail "Package identity is not $EXPECTED_PKG"
grep -q "versionCode='$EXPECTED_VERSION_CODE'" <<< "$BADGING" ||
    fail "versionCode is not $EXPECTED_VERSION_CODE"
grep -q "versionName='$EXPECTED_VERSION_NAME'" <<< "$BADGING" ||
    fail "versionName is not $EXPECTED_VERSION_NAME"
grep -q "sdkVersion:'24'" <<< "$BADGING" || fail "minSdk is not 24"
grep -q "targetSdkVersion:'36'" <<< "$BADGING" || fail "targetSdk is not 36"
grep -q "native-code: 'arm64-v8a'" <<< "$BADGING" || fail "ABI is not arm64-v8a"

MANIFEST="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK")"
# `aapt2 dump badging` does not report activity-alias entries, and Godot's
# launcher is exactly that: an exported alias named GodotAppLauncher that
# targets GodotApp with the MAIN/LAUNCHER filter. Verify the manifest itself.
grep -q 'name(0x01010003)="com.godot.game.GodotAppLauncher"' <<< "$MANIFEST" ||
    fail "Godot launcher alias missing from AndroidManifest"
grep -q 'name(0x01010003)="com.godot.game.GodotApp"' <<< "$MANIFEST" ||
    fail "GodotApp target activity missing from AndroidManifest"
grep -q 'targetActivity(0x01010202)="com.godot.game.GodotApp"' <<< "$MANIFEST" ||
    fail "Launcher alias does not target GodotApp"
grep -q 'name(0x01010003)="android.intent.category.LAUNCHER"' <<< "$MANIFEST" ||
    fail "LAUNCHER intent category missing from AndroidManifest"
if ! grep -Eq 'screenOrientation.*=1$' <<< "$MANIFEST"; then
    grep -n 'screenOrientation' <<< "$MANIFEST" >&2 || true
    fail "AndroidManifest is not locked to portrait"
fi

SIGN_INFO="$("$APKSIGNER" verify --verbose --print-certs "$APK")"
grep -q 'Verifies' <<< "$SIGN_INFO" || fail "apksigner did not verify the APK"
ACTUAL_CERT="$(
    awk -F'certificate SHA-256 digest: ' '/certificate SHA-256 digest:/{print $2; exit}' \
        <<< "$SIGN_INFO" | tr -d ':' | tr 'A-F' 'a-f' | tr -d '[:space:]'
)"
EXPECTED_CERT="$(tr -d '[:space:]' < "$EXPECTED_CERT_FILE" | tr 'A-F' 'a-f')"
[[ -n "$ACTUAL_CERT" ]] || fail "Could not read APK signing certificate"
[[ "$ACTUAL_CERT" == "$EXPECTED_CERT" ]] ||
    fail "APK signing certificate $ACTUAL_CERT does not match stable debug cert $EXPECTED_CERT"

APK_SHA256="$(sha256sum "$APK" | awk '{print $1}')"
APK_SIZE="$(stat -c%s "$APK")"
PACKAGE_LINE="$(grep "^package:" <<< "$BADGING" | head -1)"
NATIVE_LINE="$(grep "^native-code:" <<< "$BADGING" | head -1)"
ORIENTATION_LINE="$(grep 'screenOrientation' <<< "$MANIFEST" | head -1)"
LAUNCHER_LINE="$(grep 'targetActivity(0x01010202)="com.godot.game.GodotApp"' <<< "$MANIFEST" | head -1)"

cat <<EOF
APK_VERIFY_PASS
apk=$APK
apk_size_bytes=$APK_SIZE
apk_sha256=$APK_SHA256
package=$EXPECTED_PKG
version_name=$EXPECTED_VERSION_NAME
version_code=$EXPECTED_VERSION_CODE
$PACKAGE_LINE
launcher_alias=com.godot.game.GodotAppLauncher
$LAUNCHER_LINE
$NATIVE_LINE
orientation=$ORIENTATION_LINE
signing_cert_sha256=$ACTUAL_CERT
csharp_payload=absent
EOF
