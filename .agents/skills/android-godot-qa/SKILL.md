---
name: android-godot-qa
description: Use for authoritative Android builds, APK provenance, and bounded Layer Sort physical-device QA through the package-scoped agentctl wrapper.
---

# Android Build and Device QA

## Authoritative build

Inspect `ENGINE_VERSION.lock` and the active GitHub Actions workflow before building.

The checked-in G3-B/G5 workflow uses:
- GitHub Actions `ubuntu-24.04`
- Pinned Godot 4.7.2 Standard Linux `x86_64` archive and matching export templates
- JDK 17.0.21+9
- Android compile SDK 36 and Build Tools 36.1.0
- Android ARM64 output

The local Debian PRoot is ARM64 with Godot 4.7.2, Java 21.0.13, and a different Android SDK package set. Local export is supplemental only. Do not install SDK 36 to imitate CI.

## Device identity and single entrypoint

The verified target is OPPO CPH1937 / product OP4B80L1 / Android 11 / API 30. The only approved game package is:

`com.yoseftext.layersort.dev`

Use only `tools/device-tests/agentctl`. It uses the existing ADB server at `127.0.0.1:5037` and the shared lock `/root/device-tests/test.lock`. It does not start/restart ADB, connect/disconnect devices, start Appium, or create a replacement lock.

Supported commands:
- `fetch-build --run-id <ID> --commit <40-hex-SHA>` downloads and verifies the
  exact successful push/manual-dispatch GitHub Actions debug build. It stores
  the APK and provenance under `.runtime/device-qa/artifacts/`; it does not
  access the phone or install the APK. Older build artifacts without a
  provenance manifest are rejected. Use a fresh run for the exact commit.
- `plan-gesture <rapid|simultaneous|drag|hold> --size <WIDTH>x<HEIGHT> --points <X>,<Y>[:<X>,<Y>...]` builds a bounded W3C input plan without contacting a device. This is planning evidence only; it does not execute or measure touches. Choose viewport and points from the actual build and screen, then require a reviewed adapter and exact device authorization before execution.
- `visual-match --run <screenshot-run> --template <reviewed-name>` computes an offline template similarity and bounding box using the isolated, version-locked visual environment. It never captures, taps, proves provenance, or decides visual quality. No reviewed game templates or actual-device comparisons exist yet. See `tools/visual-qa/README.md`.
- `status`, `battery`, `thermal`
- `screenshot` only when Layer Sort is verified in the foreground
- `logcat` filtered to the Layer Sort process PID and selected markers
- `launch`, `stop`, `tap`, `swipe` only with exact owner approval and an approval ID

The proposed wrapper also contains owner-operated `inspect-installed` and `install-build` actions. The Antigravity Hook denies both: a phone run requires exact-patch review, tests, and explicit authorization for the candidate and current installed state. The install revalidates GitHub's archive digest, the APK, the expected certificate and device identity; it refuses a downgrade or different previous hash. The `--owner-approved` flag is a record, not proof of consent. Never claim an install or device test from a mocked test result.

The wrapper does not expose arbitrary shell, arbitrary ADB arguments, package selection, uninstall, clear-data, permission changes, global settings, or service management. Unsupported commands must fail closed.

The device-qa specialist is read-only and has no command execution tool. The Lead executes wrapper commands. Mutating actions require the owner's explicit approval for that exact run; use `--owner-approved --approval-id <ID>` only after approval is recorded. A flag is audit metadata, not proof of owner identity.

## Input semantics and thermal readings

- ADB `input tap/swipe` is synthetic input. It measures in-game hit-testing only; it does not measure finger/touchscreen accuracy.
- Input is rejected unless the exact game package is foreground and coordinates are inside the current display bounds.
- ADB timeouts and unavailable thermal data produce `UNKNOWN`, never an invented `FAIL` or `PASS`.
- Android thermal status 3 or higher is not ready for performance baseline. Re-measure only after the device has rested.
- Performance claims must use Godot runtime monitors plus supported Android battery/thermal diagnostics. Do not infer FPS or CPU temperature from unavailable `dumpsys` fields.

## Appium decision

Appium 3.8.0, UiAutomator2 8.7.0, Appium Python Client 6.0.8, and Selenium 4.51.0 are present in the environment, but Appium is **Evaluated / Not Approved**. The Appium service was not running during the latest inventory. Do not start it, install drivers, or use it for this project without a new owner decision.

See `docs/current/07-ANDROID-QA-TOOLBOX.md` for tool selection, evidence limits, versions and the ordered device-testing plan. Prefer `model: inherit` and do not force an AI model.

## Evidence

Use test IDs and report fields from `docs/current/05-QA-TEST-CATALOG.md`.

A valid report distinguishes CI, local supplemental tests, physical-device QA, and owner-reported QA. Use `PASS`, `FAIL`, `SKIP`, `UNVERIFIED`, and `UNKNOWN` where the wrapper explicitly returns UNKNOWN. Preserve failed attempts and evidence; a later pass does not erase a prior failure.
