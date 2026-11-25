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
- `status`, `battery`, `thermal`
- `screenshot` only when Layer Sort is verified in the foreground
- `logcat` filtered to the Layer Sort process PID and selected markers
- `inspect-installed` reads the fixed debug package state and, when installed, verifies its APK identity

The wrapper also contains `install-build`, `launch`, `stop`, `tap`, and `swipe`, but the current Antigravity Hook denies all phone mutations. An operator-run phone session requires exact-patch review, tests, explicit authorization for the candidate and current installed state, and the shared phone lock. The installer revalidates GitHub's archive digest, the APK, the expected certificate and device identity; it refuses a downgrade or different previous hash. The `--owner-approved` flag is a record, not proof of consent. Never claim an install or device test from a mocked test result.

The wrapper does not expose arbitrary shell, arbitrary ADB arguments, package selection, uninstall, clear-data, permission changes, global settings, or service management. Unsupported commands must fail closed.

The device-qa specialist is read-only and has no command execution tool. The Lead can execute only Hook-approved wrapper commands; agent phone mutations remain blocked until a reviewed scoped execution path exists. For an operator-run action, `--owner-approved --approval-id <ID>` is audit metadata after explicit approval, not proof of owner identity.

## Input semantics and thermal readings

- ADB `input tap/swipe` is synthetic input. It measures in-game hit-testing only; it does not measure finger/touchscreen accuracy.
- Input is rejected unless the exact game package is foreground and coordinates are inside the current display bounds.
- ADB timeouts and unavailable thermal data produce `UNKNOWN`, never an invented `FAIL` or `PASS`.
- Android thermal status 3 or higher is not ready for performance baseline. Re-measure only after the device has rested.
- Performance claims must use Godot runtime monitors plus supported Android battery/thermal diagnostics. Do not infer FPS or CPU temperature from unavailable `dumpsys` fields.

## Appium decision

Appium 3.8.0, UiAutomator2 8.7.0, Appium Python Client 6.0.8, and Selenium 4.51.0 are present in the environment, but Appium is **Evaluated / Not Approved**. The Appium service was not running during the latest inventory. Do not start it, install drivers, or use it for this project without a new owner decision.

## Evidence

Use test IDs and report fields from `docs/current/05-QA-TEST-CATALOG.md`.

A valid report distinguishes CI, local supplemental tests, physical-device QA, and owner-reported QA. Use `PASS`, `FAIL`, `SKIP`, `UNVERIFIED`, and `UNKNOWN` where the wrapper explicitly returns UNKNOWN. Preserve failed attempts and evidence; a later pass does not erase a prior failure.
