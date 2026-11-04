# G4 integrated gameplay visual production

Base: owner-accepted cloud scope PR #8, `d190e317930f242c629d4ac88542d6ad1ce2f391`; new branch `feat/g4-visual-production`. Existing stacked PRs stay open/unmerged. This is a reviewable integrated art/audio slice, not OPPO or final aesthetic acceptance.

## Implemented visual system

Original CanvasItem vector glass has a rounded base, elliptical lip, inner and outer contours, paired reflections and translucent depth. Liquid fills are continuous rather than detached blocks, with meniscus highlights and anti-aliased per-colour dot markers. Selection lifts/eases over 140 ms with a rounded focus outline; invalid moves retain a short red rim cue and translated status. Newly completed tubes get a green check and bounded 350 ms pulse. Default low detail has no particles, textures or shaders; a session setting adds optional reflection accents.

The compact HUD keeps a full-width bilingual title and puts level/moves in one row. The original navy/cyan/gold palette, shared buttons and confirmation dialogs remain. The new results card shows an original star emblem, localized congratulation, real level/move count and recorded star count, a Map action and any unsaved-progress warning. Badge fade lasts 900 ms, can be skipped immediately by the existing action, and falls to 100 ms with Reduced Motion. No invented reward or next-level button is shown.

During a valid pour the domain/session commits and saves **once**, before animation. A copied source snapshot lifts, tilts around its lip and moves above the destination. A short stream joins the two lips while the displayed source drains and receiver rises. Tilt is clamped against horizontal screen space; the cup returns in 620 ms. The original authoritative arrays remain untouched by rendering, and existing input locking remains. Reduced Motion settles in 100 ms without a moving cup/stream. Undo, Restart and focus loss cancel the ghost and settle to the correct snapshot. This is stylized 2D transfer, not a physical fluid solver; tilted surfaces rotate with the cup.

## Responsibilities

| File | Responsibility |
|---|---|
| `scripts/presentation/tube_painter.gd` | Cached vector glass/liquid brushes and geometry, shared by static tubes and ghost |
| `scripts/presentation/tube_view.gd` | Snapshot display, selection/error/completion feedback, accessibility target |
| `scripts/presentation/pour_trail.gd` | Copied visual transfer, lip trajectory, tilt and receiver interpolation; no game command |
| `scripts/presentation/victory_badge.gd` | Original single-star vector emblem |
| `scripts/ui/win_dialog.gd` | Bilingual results composition and bounded badge fade |
| `scripts/ui/classic_game.gd` | HUD composition, existing command bindings and presentation completion/cancellation |
| `scripts/audio/game_audio.gd` | Four reusable voices, local mute and independent focus/pause gating |
| `scripts/application/app_settings.gd`, `scripts/ui/settings_screen.gd` | Session sound/motion/reflection preferences and controls |
| `scripts/ui/navigation_coordinator.gd` | Scene ownership, preference propagation, navigation cues and result binding |
| `scripts/ui/ui_text.gd`, `content/about/credits.json` | Translations and audio attribution |
| `tools/assets/generate_ui_audio.py`, `content/audio/` | Original deterministic short PCM sound assets and provenance |
| `tests/visual/production_test.gd`, `tests/test_audio_assets.py` | Animation/audio correctness and asset reproducibility/peak checks |
| Existing cloud smoke and Android workflow | Reused actual-pointer renders, expanded preference/Arabic result coverage and G4 checks |

The Classic scene retains its existing UI orchestration instead of rewriting working G2/G3 systems; detailed drawing, animation, badge and audio live in narrow reusable components. No domain/GameSession rules, fixture layouts, progression/save schema, application ID, signing, engine pin, ABI or renderer changed. Development metadata remains 0.3.2-g3b/code 5; source/hash identifies this artifact. Release numbering remains a later owner step.

## Audio assets and lifecycle

Six original effects cover selection, pour, invalid, completion, win and UI navigation. Source is original mathematical synthesis, not downloaded samples or AI-generated audio. Wave assets are explicitly dedicated under **CC0-1.0**, with no required attribution; the in-game credit still identifies them. Source, duration, format, peaks, optimization and exact hashes are in `content/audio/README.md`, and dedication is `content/audio/LICENSE.txt`. Generator uses only Python standard library. Files are mono 22,050 Hz signed 16-bit PCM, 70–780 ms, no loops or soundtrack.

Four preallocated AudioStreamPlayer voices prevent unbounded players. Mute stops existing cues; background/pause stops cues and future playback requires both application resume and focus. Opening Pause stops gameplay audio while permitting menu feedback. Resume does not replay stale cues. Game voices are released on scene exit. No Master-bus/global singleton change, service, plugin or native dependency was added. System audio routing, speaker quality and latency require device listening; Dummy-driver tests establish routing/lifecycle only.

Preferences are explicitly **session-only**, as shown in Settings; existing save compatibility and schema are preserved. No silent migration or new persistence infrastructure is introduced.

## Verification and evidence policy

Reuses the PR #8 720×1600 GUI harness with actual pointer events and uniquely isolated saves/capture directories. Before captures are preserved from that baseline; after captures show gameplay, tilt/stream stages, completion, EN win and Arabic win with a real injected failed save. Every final capture index records exact source, engine, dimensions, timestamps and hash. Images are inspected, not inferred from test counts. All captures remain outside the project until export completes.

G4 tests check copied-state stability, bounded receiver rise, input lock, Undo/Restart ghost cleanup, stale callback cancellation, Reduced Motion, exactly one completion cue per newly completed tube and no completion cue on Undo. Audio tests cover mute, disordered focus/pause notifications, no automatic resume replay, mono/size/peak bounds and byte-exact regeneration. Existing G2/G3-A/G3-B and APK tests are retained. Existing CI runs the full regression, new G4 checks, GUI smoke, Android export and unchanged size/signature/content guards.

Two issues found in bounded independent review were repaired with regressions: resume previously overrode lost focus in audio; Undo restoring a full tube previously caused a false completion cue. No additional general audit or QA system was created. Earlier parse/test attempts and screenshots are retained. Brief engine exit immediately after WAV playback can report native WAV playback retention in the Dummy mixer; a separate 40-cue start/stop/free probe retired cleanly. This is not evidence of an in-game leak or proof of Android cleanup; retain logs and inspect device lifecycle behavior.

## Remaining acceptance

Final source/CI, exact APK comparison and Linux sample observations accompany delivery. Linux llvmpipe timing is not Android GPU/FPS/thermal/battery evidence. No unmeasured performance optimization is claimed. Default low detail avoids refraction, particles, heavy shaders and continuous idle redraw. Frame-time, touch/audio latency and sustained memory remain OPPO checks.

Minimal phone acceptance: exact-hash update without clearing saves; EN/AR composition/safe areas; rapid touch and Back/Pause/Undo/Restart during pour; mute, focus loss/call/background and resume without stale audio; real speaker evaluation of all six cues; sustained low-tier frame pacing and memory/logcat. G15-QA-001 remains OPEN. Production font selection, richer art direction and final audio/aesthetic approval remain owner work; current typography uses the existing licensed engine/system fallback without new external font assets.

Rollback: close this stacked PR or revert its commits on a new branch. Preserve PR #8 and prior stack, real save bytes and earlier evidence. No merge, main/protected change, G3-C, new mechanic or store/release work.
