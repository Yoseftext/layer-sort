# Cloud graphical QA and targeted repairs

Base: PR #7, `395d46f8281e8ee5de0a32fdf3262a5322caf48f`, APK SHA-256 `d204f3bec321764a11cf904bc5d801a2c531279d1901632946ac41820ce53fd0` verified from the actual retained APK. Baseline CI runs 40782240276 / 40782247525 passed. Branch `feat/cloud-visual-qa` stacks on PR #7; no merges or protected-branch changes.

## Demonstrated environment

Godot **4.7.2 Standard** downloaded from the exact lock-file upstream release; ZIP SHA-512 matches `ENGINE_VERSION.lock`. Default installed Godot 4.6.3 was not used for these results. Xorg 1.21.1.16 with the existing dummy driver, X11 display :99, xrandr mode 720×1600, Mesa 25.0.7 llvmpipe/OpenGL 4.5 Compatibility. No new installed package/plugin, production renderer or export-setting change. Existing Xorg/dummy tools suffice; Xvfb is absent locally and used by the existing Ubuntu CI. No adb, Android SDK/emulator or /dev/kvm detected locally; Android execution is UNVERIFIED. OpenCode executable absent although four project agent definitions exist; existing native remediation_review agent performed read-only source review, not a claimed OpenCode/visual run.

The reusable `tests/visual/cloud_smoke_test.gd` loads the real main navigation scene and actual gameplay components in a graphical Godot process. It injects mouse motion/press/release through `Input.parse_input_event` and checks authoritative snapshots. Dialogs are embedded in the test window to match Android composition and permit capture. No assertions infer a phone result. Saves are isolated before coordinator readiness in a uniquely named repository; screenshots require an empty, distinct attempt directory. Production `user://` save files are never used. A second coordinator verifies disk-backed Continue; this is **not** an Android process-kill test.

## Defect register

| ID / severity | Reproduction / root cause | Fix and regression |
|---|---|---|
| CV-01 P1 | Pointer click on gameplay Restart after a move immediately resets state/history; only Pause routed through confirmation | ClassicGame restart request signal bound to existing coordinator confirmation. Pointer cancel preserves snapshot; pointer confirm resets. Standalone G2 scene keeps its existing direct command fallback |
| CV-02 P2 | Pause → Settings → Arabic → Back → Resume leaves Pause/game in English | Relocalize existing game labels/accessibility names without recreating session; recreate Pause in selected language. Pointer EN→AR→EN regression |
| CV-03 P2 | Settings/About Arabic wraps into a very narrow central column | Shared VBox takes available width with explicit margins and vertical centering. Actual AR/EN before/after screenshots |
| CV-04 P2 | Dialog action controls retain tiny default fonts/targets; title backdrop transparent after shared panel styling | Shared button styling on dialog actions, larger type/targets, embedded title border, explicit foreground for interactive states. Actual restart/exit/win screenshots; pointer action isolation |
| CV-05 P2 | Winning save failure can show warning and win dialogs together | Defer win while save warning is visible; resume after warning dismissal or successful retry. Injected storage failure on valid winning move, pointer warning dismissal, two screenshots |
| CV-06 P2 | Safe-area margins show default gray instead of approved navy | Root background behind safe-area surface; rendered corner-pixel regression |
| CV-07 P2 | Arabic About version appears visually reordered | Unicode LTR isolation around actual project version without changing version metadata |
| CV-08 P3 | Reduced-motion label uses much smaller default type | Match settings text size; 96-unit target retained |

No Classic/domain rules, GameSession, level layouts, progression schema, signing, package identity, renderer or engine pin changed. No external art/assets/licenses/dependencies introduced. Cloud software performance is not OPPO GPU performance.

## Reuse and evidence

After importing with the pinned binary:

```sh
QA_SOURCE_COMMIT="$(git rev-parse HEAD)" VISUAL_CAPTURE_DIR=/tmp/unique-empty-attempt DISPLAY=:99 \
  /path/to/pinned/godot --audio-driver Dummy --path . --script res://tests/visual/cloud_smoke_test.gd
```

The suite captures Splash, Home, Map, EN/AR Settings, AR About, gameplay, selection, invalid feedback, early/middle/settled pour, Pause, toolbar/Pause restart dialogs, resumed Arabic, completed tube/reduced motion, Win, unlocked Map, exit confirmation, Continue and injected winning-save warning/recovery. `capture-index.json` records source identity, engine, display, actual image dimensions, timestamps, stream progress and PNG SHA-256. Capture timing is observed rather than assumed; slow software rendering may settle a scheduled animation frame before readback.

Single linear scenario function is intentional for chronological input/capture provenance; helpers handle input, captures and assertions. Existing short component test remains. Full G2/G3-A/G3-B regressions run once per repair batch, plus existing APK report tests; CI adds graphical smoke to the pinned existing export workflow. Captures stay outside project until **after** export to prevent evidence entering APKs.

Before attempts and failed driver runs are retained separately; no golden approval is implied. Initial harness issues (unnamed Map Home target, missing temporary fixture directory, querying controls before layout) are QA-driver failures, not product defects. Final exact-commit CI/APK/measurements and screenshot assessment are recorded in the evidence handoff.

## Remaining phone acceptance

Track B UNVERIFIED; G15-QA-001 OPEN. Minimum OPPO run: exact APK/certificate/hash, update install preserving saves; Android Back and modal touch isolation; notch/gesture/inset and density checks EN/AR; focus/background or process kill during pour/win and Continue; real GPU frame pacing/memory/audio focus. Storage-failure tests only in isolated fixtures, never the owner's save. Native Android dialogs/lifecycle are not established by embedded Linux windows.

No thermal/battery/Android FPS claim. Existing stream cue is not a tube-tilt simulation; production fonts/audio/completion shimmer/full win card remain outside this repair slice. Owner visual approval remains required. Roll back by closing this stacked PR or reverting its commits on a new branch; preserve saves and all earlier PRs.
