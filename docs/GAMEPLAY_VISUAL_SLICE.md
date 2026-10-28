# Gameplay visual slice

Base: `feat/g3b-remediation`, `87b562e09b48871fe295e80cfb0fe27f3529c8ab`; PR #6 remains draft/open against `feat/g3b-progression`. Visual branch: `feat/g4-gameplay-visual`. This is one representative gameplay slice, not full G4 acceptance.

## Bounded audit

Reviewed Classic/session, dual-slot saves and future-version protection, navigation/lifecycle, export filters and artifact verification. No additional proven domain or persistence defect required a change to the remediation head. Existing successful baseline workflows: 40466302976 and 40466309539. Phone acceptance remains UNVERIFIED. G15-QA-001 stays OPEN.

## Changes and responsibilities

| File | Responsibility |
|---|---|
| `scripts/presentation/tube_view.gd` | Draw copied tube layers, glass/highlights and colour-independent dot marks; selection/focus and invalid feedback |
| `scripts/presentation/pour_trail.gd` | Temporary curved liquid stream; no session/domain access |
| `scripts/ui/classic_game.gd` | Gameplay composition, command binding, presentation completion/cancellation |
| `scripts/ui/navigation_coordinator.gd` | Save committed results immediately; show win after presentation, defer while paused |
| `scripts/application/app_settings.gd` | Session-only motion preference alongside existing language preference |
| `scripts/ui/settings_screen.gd`, `ui_text.gd` | Bilingual motion control and pouring status |
| `tests/visual/gameplay_visual_test.gd` | Render/capture, selection, input lock, reduced motion and focus/win regressions |
| `tests/g3b/navigation_test.gd` | Commit versus drawing timing and delayed win regression |
| `.github/workflows/android-build-g3b.yml` | Existing pinned export/verification plus visual tests and actual desktop renders |

The session commits exactly once before animation. Drawing retains the previous snapshot until the 620 ms stream completes; reduced motion omits the stream and completes in 100 ms. Undo/restart invalidate pending callbacks; focus loss settles drawing to committed state, and focus return resolves a pending win. No Classic rules, save schema, level fixtures, renderer, package identity, signing or dependencies changed. Version remains 0.3.2-g3b/code 5 for this development slice.

## Verification and evidence

Local Godot 4.6.3 (environment tool, not a pin change): G2 1149, G3-A 53, G3-B navigation 20, progression/save 28, remediation 14, visual 14 assertions; Python APK report 2 tests. Commands: `godot --headless --path . --script res://tests/<suite>.gd`, each navigation suite with a fresh `XDG_DATA_HOME`; `python3 -m unittest tests/test_apk_report.py`; `git diff --check`. Pinned 4.7.2 CI is the authoritative export check. CI captures are actual Godot Compatibility desktop renders under Xvfb, not phone captures or mockups.

Earlier failed attempts are retained in execution logs: reused local save directory invalidated fresh-install test assumptions; isolated rerun passed. A small-window bounds assertion compared logical canvas coordinates against physical window pixels; it now compares the logical viewport. A new lifecycle test initially mistook a repeated move for the final move; indexed iteration fixes the test driver. No production assertion was weakened.

## Assets, limitations and device handoff

No external art/font/audio assets were introduced. All new glass/liquid graphics are original CanvasItem primitives; no new license/attribution obligation or texture compression setting. Existing engine/default font licensing is unchanged. Premium font selection, audio/haptics, completion shimmer, full win card and animated tube tilt remain further visual work; this slice uses a stream cue and settled layer update. No performance benchmark or full accessibility acceptance is claimed. Existing headless ObjectDB-at-exit warnings remain unclassified; actual app leakage is UNVERIFIED.

Phone checklist: verify CI commit/APK SHA and stable certificate; acquire existing lock; preserve installed saves; update install without clearing data; inspect EN/AR at OPPO resolution, safe areas, text and contrast; select/reject/pour, rapid taps, Undo/Restart, Pause/Settings/Resume and Android Back; background/foreground during final pour; confirm one win/unlock and Continue after process restart; collect screenshots/logcat and individual verdicts. Measure frame pacing/memory on the phone. Track B UNVERIFIED until this occurs.

Rollback: close the visual PR or revert its commits on a new branch; retain PR #6 and saves. Do not downgrade a real installation without preserving save bytes and verifying schema compatibility. No PR merged, no protected branch changed, no G3-C started.
