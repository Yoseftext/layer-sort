# Android/Godot QA toolbox — evidence and selection

This document is an engineering inventory and implementation order, not phone-run authorization. Last inspected 2026-11-24. Source of truth for actual device permissions and acceptance remains [04-AGENT-OPERATIONS.md](04-AGENT-OPERATIONS.md). Never represent a plan or mocked test as device evidence.

## Current environment

- Phone reported by owner: OPPO CPH1937, Android 11 / API 30, Shizuku Next and ADB. Actual connectivity, device helpers, and physical touch behavior are **UNVERIFIED** in this task.
- Debian ARM64/PRoot Python 3.13.5. On 2026-11-24 `/root/device-tests/.venv/bin/python` could import Pillow 13.0.0, Appium Python Client 6.0.8, Selenium 4.51.0 and pytest. The system Python is a different environment; it must not be assumed to contain the Appium client.
- The existing [inventory](../../tools/inventory.md) reports Appium 3.8.0 and UiAutomator2 8.7.0 installed; its device service is **Evaluated / Not Approved**. No Appium session was started during this task.
- Existing Godot G2 tests check the animation lock and conflicting fingers in process; legacy `tools/qa/g2-device.py` creates one W3C rapid-tap request, but its G2 coordinates, markers, device access, and Appium setup have not been adapted or approved for the current wrapper.

## Tools and why

| Tool | Contribution | Decision for this environment |
|---|---|---|
| [Godot tests / InputEventScreenTouch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html) | Fast deterministic rules and simulated events in the engine. | Keep the existing tests and expand them where they find concrete gaps. They do not test Android's input stack or a physical finger. |
| [Appium + UiAutomator2 W3C Actions](https://appium.io/docs/en/latest/guides/gestures/) | One request can describe rapid pointer ticks and synchronized virtual fingers; supports collecting screenshots. | Reuse the installed client after separately reviewing session options, helper APKs, permissions, exact target and service lifecycle. The generated plan is not an executed test. Android or driver timing can differ from requested ticks; measure it. |
| Android ADB `screencap`, `logcat`, [screenrecord](https://developer.android.com/tools/adb) | Device screenshots, relevant crash evidence and short recordings. | Current `agentctl` already provides scoped screenshot/logcat reads. Video requires a reviewed bounded wrapper and device-run authorization. Android screenrecord has a three-minute maximum and does not record audio. |
| Pillow | Compare screenshots and create visual evidence without a large new dependency. | 13.0.0 is available in the existing test venv. Existing `tools/qa/qa.py visual` gives a basic pixel diff; animated masks, accessibility, layout decisions and qualitative visual review still need work and evidence. |
| [Perfetto](https://developer.android.com/topic/performance/inspecting-overview) | System trace for frame and resource investigations on supported Android versions. | Candidate for a bounded, on-demand performance workflow after checking device and output support. A trace is not itself an FPS or quality verdict. |
| [Android Monkey](https://developer.android.com/studio/test/other-testing-tools/monkey) | Repeatable seeded event stress, with package filters and bounded event counts. | Candidate for a controlled stress phase only after a wrapper is reviewed; random input needs state/log checks and cannot prove game rules. |
| [Airtest](https://github.com/AirtestProject/Airtest) / [Poco](https://airtest.doc.io.netease.com/en/) | Image-based game automation and engine-specific hierarchy inspection. | Not installed in either inspected Python environment. Consider image matching if a measured gap remains; Poco's listed engine support does not establish Godot support. Check Python 3.13, ARM64, APK/service effects, license, and pinning before any trial. |
| [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) / [GUT](https://github.com/bitwes/Gut) | Structured Godot scene/unit tests, assertions and reports. | Candidates, not installed. GdUnit4 is MIT; GUT is MIT. Verify the precise Godot 4.7.2 version and GDScript-only project fit before adding either. Do not replace current tests without evidence of benefit. |
| [OpenCV](https://docs.opencv.org/4.x/d4/dc6/tutorial_py_template_matching.html) | Template/image matching for visual QA. | Not installed in inspected Python environments. Optional only if Pillow/scene metadata cannot meet a measured need; validate Python 3.13/ARM64 wheels and resource cost in an isolated pinned environment first. |
| [scrcpy](https://github.com/Genymobile/scrcpy) | Optional visual remote control, including a virtual second finger. | Designed for a host and Android device; user has one phone. Investigate PRoot/display viability first; no claim it is usable here. |
| [minitouch](https://github.com/openstf/minitouch) | Alternative multi-touch input protocol. | Upstream says its standalone default does not work on Android 10+ without an additional service. Do not assume compatibility with Android 11 or enable a privileged bridge. |

## Ready now: bounded gesture planning

`tools/device-tests/agentctl plan-gesture` produces W3C JSON **offline only**. Allowed modes: `rapid` (2–8 points), `simultaneous` (two pointers), `drag` (two points), and `hold` (one point). Coordinates must be within the explicitly declared viewport. The request has no device connection, produces no taps, and cannot prove real timing.

```sh
tools/device-tests/agentctl plan-gesture rapid --size 720x1600 --points 100,200:300,200:400,200:500,200
tools/device-tests/agentctl plan-gesture simultaneous --size 720x1600 --points 100,200:300,200
```

The example numbers are illustrative, not measured Layer Sort hitboxes. For a real test derive coordinates from the actual installed build, screen and orientation; verify package foreground and app state first. Future execution should submit the actions as one request, measure actual elapsed time, read a project state/log oracle, and retain screenshot, log, APK hash and exact commit. Do not label a case PASS merely because input was sent.

## Order of work

1. Reconcile current G5 source with integrated infrastructure without discarding uncommitted files. Produce the exact CI candidate.
2. Complete independent review and integration of build verification and bounded install extension, then perform an exact owner-authorized device hand-off. Confirm installed APK bytes.
3. Design and review an agent/device task grant and bounded execution adapter; `--owner-approved` alone is not a consent mechanism. Decide Appium's helper/service scope before starting it.
4. Exercise deterministic rules and scene tests first. On the device, test launch, valid/invalid moves, undo/restart, win/progression/save, rapid taps, simultaneous touches, interruption/resume and offline behavior with expected/actual state and screenshots.
5. Add visual comparisons, bounded video and performance traces only as their measurement needs and capabilities are verified. Keep physical finger feel/usability as `OWNER_CHECK_REQUIRED`.
6. When Antigravity or a dependency changes, detect the new fingerprint, run compatibility checks, and apply only known, reviewed recovery steps. Unknown or incompatible changes stop with evidence; future changes cannot be guaranteed to self-repair.
