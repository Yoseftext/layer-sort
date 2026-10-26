# G3-B integrated checkpoint

Scope: two individually packaged Classic fixture levels only. No G3-C content or final campaign. The map reads the validated catalog and shows locked, unlocked and completed entries. One completion star means a completed fixture; no tiered scoring/reward economy is implemented. The next catalog entry unlocks after its predecessor is won. Duplicate wins do not alter the first completion record. Invalid and locked IDs are rejected before replacing the active screen.

| File | Primary responsibility |
|---|---|
| `scripts/application/progression.gd` | Deterministic unlock/completion validation |
| `scripts/application/save_repository.gd` | Versioned two-slot local writes and recovery |
| `scripts/application/navigation_state.gd` | Route identity |
| `scripts/ui/navigation_coordinator.gd` | Screen/session/save orchestration |
| `scripts/ui/level_map_screen.gd`, `scenes/navigation/level_map.tscn` | Map presentation |
| `scripts/ui/home_screen.gd` | Home entry actions |
| `scripts/ui/classic_game.gd` | Emit committed-state and win signals from G2 interaction |
| `scripts/application/game_session.gd` | Restore a validated committed board; undo history starts empty after process death |
| `scripts/ui/ui_text.gd` | English and Arabic strings |
| `tests/g3b/progression_test.gd` | Progression and save recovery regression
| `tests/g3b/navigation_test.gd` | Map, locked entry and Pause-to-Map regression |
| `.github/workflows/android-build-g3b.yml` | Pinned CI/APK provenance |
| `export_presets.cfg` | G3-B debug package version |

Save schema v1: `{payload:{save_schema_version:1, sequence, completed:{level_id:{stars:1,best_moves}}, active:{level_id,content_version,move_count,tubes}}, checksum}`. The checksum is SHA-256 of Godot's sorted-key JSON rendering of the parsed payload. It detects damage, not tampering. A save writes to the alternate slot via a temporary file, flushes and closes it, then renames it. Recovery selects the highest valid sequence. A malformed or unsupported future schema never gets migrated or overwritten as if valid; if both slots fail, Home shows an error and gameplay is disabled to preserve bytes. A single failed slot falls back to the last valid one. No prior released save schema exists, so v1 has no migration. Future versions require a new explicit stepwise migration and fixtures before promotion. Unknown future versions fail closed. Settings language remains session-only under the G3-A contract.

Continue restores the last committed board after process restart, with move count and level version validated against packaged content. Animation and selected tube are discarded; undo history is empty after restore. Pausing and visiting Settings keep the live session. Pause can return to Map after the same unsaved-attempt confirmation. Leaving to Home clears the active attempt only after the existing confirmation. A win clears Continue, records completion once, and opens the updated map after acknowledgment. Save failures are logged; full-storage and process-kill behavior still need device proof.

Verification commands: `godot --headless --path . --script res://tests/g2/classic_rules_test.gd`; equivalent commands for `tests/g3a/navigation_test.gd`, `tests/g3b/navigation_test.gd` and `tests/g3b/progression_test.gd`. CI builds the pinned Godot 4.7.2 Android APK and checks manifest, signing, arm64, zip contents and excludes docs/tests/tools. Track B must install that exact APK under the phone lock and exercise Home → Map → locked rejection → win/unlock → Continue → Pause/Resume → force-stop/restart, Arabic/English, safe areas, screenshots and logcat. G15-QA-001 remains OPEN.

Limitations: only two fixture levels; no tiered stars, save of undo history, cloud sync, production content or anti-cheat. Rollback: switch back to the G3-A branch/build without deleting the two `user://save_*.json` files; an older build has no reader for them. Preserve both slots for forward migration and device diagnostics. No PR is merged and no protected branch is modified.
