# G1 — Native Android Smoke on the OPPO

Date: 2026-10-24
Scope: G1 only (`docs/current/03-PRODUCTION.md` §2). `main` is not modified.
Verdict: **PASS** for the G1 criteria below.

## Tested artifact

- Branch: `feat/gdscript-foundation`
- Tested source commit: `5905e7648fbae86bd98bf8db5ca385863b0c3f8c`
- CI run: [40102066642](https://github.com/Yoseftext/layer-sort/actions/runs/40102066642) — success
- APK: `layer-sort-g1-debug.apk`
  - Size: `28316466` bytes
  - SHA-256: `0b118493c17f4e86dad582bda1dbb967ae7d0f526ed4ead44c092da26421a41e`
- The APK pulled back from the phone (`pm path` → `adb pull`) has the
  **same SHA-256** as the CI artifact, byte for byte.
- This report and its screenshots are added in a later docs-only commit. They
  do not change `project.godot`, `export_presets.cfg`, `scenes/`, `scripts/`,
  or the device-test tools, so the tested artifact above remains the artifact
  produced by the tested source commit.
- Package: `com.yoseftext.layersort.dev`, version `0.1.0-g1`, versionCode `1`
- Launcher: `com.yoseftext.layersort.dev/com.godot.game.GodotAppLauncher`
- minSdk `24`, targetSdk `36`, ABI `arm64-v8a`, portrait
- Debug certificate SHA-256:
  `de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e`
- No C#/.NET payload: `tools/verify-apk.sh` found no `libmonosgen`, no managed
  `.dll`, and no Godot mono assets.

`tools/verify-apk.sh` also checks the launcher alias and
`screenOrientation=1` from `AndroidManifest.xml`, because `aapt2 badging` does
not report Godot's `activity-alias`.

## Device

- OPPO `CPH1937`, Android 11 (API 30), 720×1600, density 320
- Godot Engine `v4.7.2.stable.official.ed1daf0bf`
- OpenGL ES 3.2 — Compatibility renderer on Qualcomm Adreno 610

## Device tests

All checks ran through the shared phone reservation (`agentctl` /
`phone-queue`); no phone service was changed.

### Install and update

- `firstInstallTime`: `2026-10-24 16:43:24` (first G1 CI APK)
- `lastUpdateTime`: `2026-10-24 17:25:29` (this artifact)
- Three CI builds installed over the same package without uninstalling; the
  stable debug certificate produced no signature mismatch.
- `cmd package resolve-activity` returns
  `com.yoseftext.layersort.dev/com.godot.game.GodotAppLauncher`.

### Smoke — PASS

Evidence (test host): `/root/device-tests/agent-runs/20261024-142608-14759-opencode-smoke`

- Foreground package: `com.yoseftext.layersort.dev`
- Orientation (Appium and ADB): `PORTRAIT`
- Window/screenshot: 720×1600; mean brightness 44.74; 259 sampled colours
- `LAYER_SORT_G1_READY`: 1
- No `FATAL EXCEPTION`, `Fatal signal`, `SCRIPT ERROR`, `Parse Error`, or
  `Failed to load scene` in logcat.
- Screenshot: [`docs/evidence/g1/01-smoke.png`](evidence/g1/01-smoke.png)
  (SHA-256 `774ccda8ebd2cb41d2e144b6df9854f89580d36ff25f2d2ea24944f4b0f5db39`)

### Touch — PASS

Evidence (test host): `/root/device-tests/agent-runs/20261024-142633-15302-opencode-touch`

- Real Appium tap at `(360, 800)`.
- `LAYER_SORT_G1_TAP 1` in logcat.
- Visible change: status changed to `Touch verified`, counter to `Taps: 1`.
- Before/after crop SHA-256:
  `1066d425…d5d3` → `f1462e4b…d1ed` (changed).
- No fatal/script errors in logcat.
- Screenshot: [`docs/evidence/g1/02-touch-after.png`](evidence/g1/02-touch-after.png)
  (SHA-256 `6733d95f3023295671f61ca0233af80e4f7aae209c042e825bfe3cd2aeb10436`)

### Runtime — PASS

Evidence (test host): `/root/device-tests/runs/20261024-142657-15807`

- Requested 30 s; observed 36 s.
- PID `15954` at start and at end (no restart, no kill).
- `LAYER_SORT_G1_READY`: 1; heartbeat ticks: 5.
- Orientation: `PORTRAIT` (raw 0).
- Foreground package sampled every 2 s: `com.yoseftext.layersort.dev` for all
  samples; device `Awake` throughout.
- Chrome was foreground *before* launch; the explicit game launch took focus
  and held it for the whole run.
- Final screenshot: 720×1600, mean brightness 44.74, 259 colours; SHA-256
  `774ccda8…db39` (same frame as the smoke screenshot).
- Crash buffer: empty. No fatal, script, or scene-load errors.

## Test-environment incident (recorded, not an app failure)

An earlier runtime run (`/root/device-tests/runs/20261024-135528-2967`) failed
with `Too few runtime ticks: 0 < 3`. The log shows the launcher receiving HOME
at 16:55:35 and Chrome resuming task 964 at 16:55:38. The Godot process
(`3190`) stayed alive; it was paused by the app switch. There was no crash and
no script error.

`tools/device-tests/game-test.sh` was hardened after that run:

- launch with the explicit `GodotAppLauncher` component instead of `monkey`;
- verify the device is awake and dismiss the keyguard before launch;
- check foreground package after `READY`, every 2 s while monitoring, at the
  end, and at the final check;
- check `mWakefulness` in the same samples;
- fail with a specific focus/sleep reason instead of only "too few ticks";
- keep focus samples in the run directory (`foreground.txt`) and record
  `foreground_before/start/end` in `status.json`.

## What was not verified

- Release/production signing or Play distribution; G1 uses debug signing only.
- Devices other than the OPPO `CPH1937` / Android 11.
- Gameplay, pour rules, undo, saves, Firebase, or offline sync (G2+).
- Accessibility AR/EN and UX goldens (G3+); the G1 scene is English-only.
- Performance targets, battery, and thermal behaviour.

Owner decisions still open and **not** decided here: final production
`applicationId`, MVP level count, approval of the pinned Godot Standard
version, and the future rules contract.

## Reproduce

```bash
gh run download 40102066642 --repo Yoseftext/layer-sort \
  -n layer-sort-g1-debug-apk -D /tmp/layer-sort-g1
sha256sum /tmp/layer-sort-g1/layer-sort-g1-debug.apk
bash tools/verify-apk.sh /tmp/layer-sort-g1/layer-sort-g1-debug.apk \
  tools/device-tests/expected-debug-cert.sha256
agentctl install /tmp/layer-sort-g1/layer-sort-g1-debug.apk
agentctl smoke opencode
agentctl touch opencode
agentctl runtime 30
```

## Rollback

- `main` and `spike/godot-csharp-android` are untouched. Do not merge this PR
  to abandon the G1 branch; the branch remains available for review.
- The previous G1 APK (CI run `40096717773`, SHA-256 `395fd3c7…51ce`) can be
  reinstalled over the current build because the debug certificate is stable.
- The C# spike app keeps its separate ID `com.yoseftext.layersort` and is not
  affected by installs of `com.yoseftext.layersort.dev`.

## Privacy and licensing

- No keystore, password, or token is stored in Git.
- The scene, script, and screenshots are original work for this project; the
  GPLv3 reference game was not opened or copied.
