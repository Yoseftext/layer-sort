# G3-C owner playtest refinement

Base PR #10 / `92462569ee9c327d0895cb60b1eea53fb9de029c`; branch `feat/g3c-player-ux`. Owner reports are physical OPPO CPH1937 / Android 11 evidence of usability problems, not a device acceptance run of this fix.

## Root causes and changes

1. **Map touch routing and composition.** Previous list depended entirely on ScrollContainer receiving GUI input through buttons; there was no explicit touchscreen gesture ownership or drag-versus-activation contract. Cloud reproduction also demonstrated emulated mouse activation alongside ScreenTouch input: a drag opened a level. `TouchLevelScroll` owns one raw touch before button GUI handling, uses a 12-logical-pixel drag threshold and cancels multi-touch; it suppresses duplicate emulated mouse events inside its bounds and gates native callbacks after touch. Mouse/wheel outside the region remain native. A drag never emits the manual activation; taps require release on the same enabled tile. No global input or Android config changed. No inertia is claimed.

   `LevelMapScreen` now has a responsive three-column grid at 720, fewer columns at narrow widths, readable locked/available/completed/star/current states and stable numerical LTR sequence with localized text. The existing navigation safe-area wrapper remains. A maximum 60 tiles per page bounds node count for future catalogs; navigation buttons support further pages. No new chapters/levels added. Fourteen tiles can fit without scrolling at the standard viewport; GUI regression uses a synthetic 60-ID catalog to force a real scroll from an unlocked tile, then tests locked rejection and real tap activation. Synthetic IDs are not shipped campaign layouts.

2. **Play and data retention.** `_on_play` always opened entry level and `go_home` cleared/persisted an empty active snapshot. Those caused the confusing Continue/Play split and loss of resumability. Home now exposes one Play button: validated unfinished active snapshot first; otherwise first unlocked incomplete level; completed campaign opens the explicitly labelled replay map. Home/Map exits retain active snapshot; Restart explicitly resets the attempt through the existing confirmation. The leave dialog accurately explains retention. A failed write keeps memory and reports failure/retry; disk remains protected by unchanged G3-B repository. Unsupported/corrupt loads block gameplay and retain localized recovery error. An invalid or already-won active snapshot is never restored as unfinished. Legacy internal Continue signal/metadata remain for compatibility, but there is no Continue control.

3. **Selection and fast input.** Invalid nonempty destinations now become the source immediately; same source deselects and empty targets never become a source. Existing selection lift tweens lower/raise old/new tubes; no domain mutation or move increment. Presentation settles in 480 ms (100 ms reduced) instead of 620. One latest tube index replaces previous intent during the lock, is revalidated through normal current-state interaction after settlement, and cannot queue pours indefinitely. Undo/Restart/Pause, confirmation requests, focus loss, multi-touch, Win and scene exit clear pending intent. Existing domain atomic commit/history/rules remain unchanged.

4. **Liquid and audio.** `PourTrail.transfer_progress` is a shared eased 0.25–0.75 phase for source depletion and target rise. Rendered close-up review also found a stale stream endpoint: first-move tutorial dismissal removed a layout row, moving the board after mouth coordinates had been captured. The hint now hides inside a reserved slot, and trail coordinates follow live source/destination mouths; regression checks preserve board geometry and endpoint equality. Stream starts at the visible tilted lip edge and lands inside target mouth; a bounded surface arc adds a subtle response without simulation. Sound begins on actual transfer onset, not lift. Pour WAV is now 270 ms of deterministic low-pass turbulence and five decaying bubble chirps, under the existing CC0 dedication. Generator and actual waveform/hash provenance updated; same four voices, mute/focus/pause limits. Native speaker timbre/latency require owner listening. Stylized tilted layers remain, no fluid solver or new dependency.

## Files and checks

- `touch_level_scroll.gd`: bounded gesture ownership, cancellation and activation gate.
- `level_map_screen.gd`: bounded grid composition/state and adaptive page layout.
- `home_screen.gd`, `navigation_coordinator.gd`, `ui_text.gd`: single Play policy, retention, truthful localized messages.
- `classic_game.gd`: selection and latest-intent orchestration; no domain rule changes.
- `pour_trail.gd`, `tube_view.gd`: shared eased transfer, lip bridge and bounded surface response.
- Audio generator/WAV/README: original reproducible replacement cue.
- `tests/feedback/`: focused domain/navigation and genuine touchscreen-style GUI regressions; real GUI frame samples at controlled normalized transfer progress explicitly distinguish them from real-time performance measurements.
- Existing tests: Home restore now presses Play; G3-A/B navigation fixtures use isolated repositories because preserving active state exposed cross-suite shared-save contamination. Existing assertions and rule suites retained.
- Existing workflow: same toolchain/export/package/signing/size checks, extra bounded feedback tests and captures copied into logs only after export.

Exact results/source/CI/APK hashes and before/after evidence accompany final delivery. Earlier failed attempts retained. No phone rerun, human audio acceptance, physical scrolling latency or Android GPU claim. Existing shutdown resource warnings remain visible; no broad audit initiated. G15-QA-001 OPEN.

Compatibility: levels 1–14 bytes/content versions, save schema, completion/best records, package identity, signing, engine and renderer unchanged. No migration or save deletion. Rollback with a revert on a new branch or close this PR, preserving saves and PR #10. Rolling back restores old Home discard/entry-level behavior, so back up save bytes and prefer forward fixes. No merge/main/protected changes or G5.
