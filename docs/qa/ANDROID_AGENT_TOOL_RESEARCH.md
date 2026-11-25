# Android agent test tools — evaluation, 2026-11-25

Status: research and selection criteria only. No new tool installed, service started,
device setting changed, or touch injected as part of this evaluation. The goal is
a measured, reproducible game-test workflow inside Antigravity, not a claim that
any candidate has passed on the phone.

## Verified environment

- OPPO CPH1937 / OP4B80L1, Android 11 / API 30; Debian ARM64 in Android PRoot.
- Existing ADB 34.0.5 can see the wireless device; the project
  `agentctl inspect-installed` found the debug package absent on 2026-11-25.
- `adb`, Appium, Node, Python 3, FFmpeg and Python Pillow are present.
  `scrcpy`, `adbutils`, Python `cv2`, NumPy and `uiautomator2` were not
  found by the current shell/Python interpreter. This is not a system-wide
  inventory of every virtual environment.
- Read-only CLI inspection on 2026-11-25 confirmed Appium 3.8.0 and
  UiAutomator2 driver 8.7.0 as installed. The current Python interpreter
  cannot import `appium` or `selenium`; other environments were not checked.
  The service was not started and session capability is unverified.
  Current project policy records Appium as evaluated, not approved.
- ADB, phone locking, exact device/package checks and scoped authorization remain
  the project integration boundary. Neither a Python library nor a screenshot
  grants an agent unrestricted phone access.

## Candidates and decision

| Candidate | What it can help with | Device-specific questions and decision |
| --- | --- | --- |
| Existing ADB wrapper | Baseline launch, single taps, swipe, screenshots and game logs with a locked phone. | Available. Measure command-to-observed-response latency and failures; ADB-generated input does not measure the physical touch panel. Current plans in PR #29 are not execution evidence. |
| Appium + UiAutomator2 | W3C pointer actions can represent simultaneous pointers, holds and gestures. | Already installed according to inventory; actual service/driver/session, API 30, PRoot performance and Godot rendered-screen behavior remain unverified. A scoped review and applicable owner decision are required before starting it. Compare against ADB instead of assuming speed. |
| scrcpy | Screen mirroring and manual control; SDK mouse mode supports a simulated second finger for constrained pinch/rotation. | Apache-2.0; not on current PATH. Upstream desktop latency figures are not measurements on this phone/PRoot. Linux ARM64 packaging, display access and ADB connection must be verified. GUI pinch is not proof of an agent-operated arbitrary multi-pointer harness. |
| adbutils | Python API for ADB screenshots and gestures; MIT upstream. | Not found in current interpreter. It adds convenience, not a proven faster or independent multi-touch channel. Upstream screenshot defaults to returning a black image on some capture failures; use `error_ok=False` and explicitly validate image/foreground if evaluated. |
| Existing OpenCV visual matcher from PR #30 | Compare actual screenshots with reviewed references and masks. | Local Python has no `cv2` / NumPy. PR tests used synthetic fixtures; actual-device result and ARM64 dependency installation remain unverified. Never auto-approve or replace a reference image. |
| Perfetto / Android diagnostics | Investigate CPU, memory and rendering bottlenecks when compatible. | FrameTimeline requires Android 12+ and upstream says SurfaceViews are unsupported; do not promise it on this Android 11 game. Check available data sources and use bounded traces or package-scoped memory data only. |
| Minitouch + STF workaround | Socket-driven pointer injection is a potential candidate in older setups. | Upstream says Android 10+ needs STFService; its cited fallback agent explicitly says it does not support multitouch. Do not install or present it as a working Android 11 multitouch solution. |
| Maestro | Declarative external UI flows, screenshots and coordinates. | Its platform approach depends on Android system UI/accessibility semantics; Godot's exposed controls must be inspected, not assumed. Extra services and ARM64 availability need review. It is not proof of rapid multi-pointer play. |

## Proposed validation sequence

1. Finish one exact-commit APK build; verify run, artifact SHA-256, package,
   version, certificate and approved target. Distinguish debug build and device
   evidence. Preserve existing game data and lock the phone.
2. Record deterministic screen state, resolution, input coordinates and expected
   game result. Establish a short ADB baseline: repeated taps, swipe, hold,
   recovery and screenshots. Time injection and observed state separately;
   record sample count, median, p95, error/timeout counts, device temperature,
   workload and whether screen recording was active. Never equate command exit
   success with an in-game move.
3. Review a bounded Appium test with two pointers and exact target; verify state
   change and cleanup. Record any required helper APK/service before execution.
   Compare the same scenarios, device and evidence to the baseline. Stop on
   unexpected foreground, target mismatch or uncertain result.
4. Evaluate scrcpy in an isolated, pinned environment only if ARM64/display
   prerequisites are met; verify its actual frame rate, delay, and input behavior.
   Do not claim unattended multi-touch based on the desktop shortcut.
5. Integrate visual checks against a real captured game screen, with a named,
   reviewed baseline and animation masks. Record failed capture as UNKNOWN, not a
   black image or PASS. Preserve raw screenshots and relevant log excerpts.
6. Implement only the selected backends behind a narrow project interface and
   explicit session grants; create bounded negative tests. The lead should choose
   roles and inherit the model selected in Antigravity; no fixed model/API or
   hidden paid service. Real device acceptance is separate from unit tests.

No license/version/checksum/architecture entry here authorizes installation.
Before adding a dependency: record the exact version, upstream, license,
checksums or lockfile, supported ARM64/Android route, rollback and a small
repeatable test in the project inventory.

## Primary sources

- https://github.com/Genymobile/scrcpy
- https://github.com/Genymobile/scrcpy/blob/master/doc/control.md
- https://github.com/appium/appium-uiautomator2-driver/blob/master/docs/actions.md
- https://github.com/openstf/minitouch/blob/master/README.md
- https://github.com/openstf/STFService.apk/blob/master/app/src/main/java/jp/co/cyberagent/stf/MinitouchAgent.java
- https://github.com/openatx/adbutils
- https://github.com/openatx/adbutils/blob/master/adbutils/screenshot.py
- https://github.com/google/perfetto/blob/main/docs/data-sources/frametimeline.md
- https://developer.android.com/games/tools
- https://docs.maestro.dev/get-started/maestro-mcp
