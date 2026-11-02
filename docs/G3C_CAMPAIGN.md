# G3-C Classic campaign

Owner-authorized slice stacked on PR #9 / `4a8caf7f9dc852cdf381dec6dac38aa78bc28cf3`; branch `feat/g3c-classic-campaign`. No merge/main change or G5 work.

Fourteen individual validated capacity-four Classic fixtures. IDs 1 and 2 and content-version 1 bytes remain identical for G3-B save compatibility (hash guards in solver); no save schema change or reset. Existing completed records naturally unlock level 3. Tutorials 1–5 introduce selection, matching, block transfer, Undo/Restart, and completion via bilingual nonblocking help. A bounded static ring/finger appears after three seconds and disappears on first committed move. Hints can be hidden. Settings offers Replay Tutorials from Home; paused Settings retains its existing session-return behavior.

Compatibility tradeoff: legacy levels 1/2 still require ten optimal moves; their instructional interaction is short, but they are longer than newly authored tutorial boards 3–5 (3/5/7 moves). They were deliberately not replaced or relabelled. Human difficulty/onboarding acceptance remains pending.

Levels 6–10 require 6/7/8/9/10 optimal pours. Levels 11–14 require 11/12/13/14, using four colours and six tubes. Counts are an objective proxy, not proof of perceived difficulty. Offline candidate selection freezes layouts in separate files; no runtime/procedural generation or new mechanics. New content uses the existing original palette/audio/vector assets, no external assets/dependencies.

## Responsibilities

- `content/levels/level_003.json` through `level_014.json`: individual puzzle data only; catalog only identifies/order levels.
- `scripts/ui/tutorial_guide.gd`: translated lesson, optional hint and idle pointer presentation; never commits state.
- Classic scene: mounts guide only for 1–5; existing G4 rendering and G2 commands unchanged.
- Map: scrollable list for all 14; existing unlock/request rules retained.
- Settings/navigation: replay entry via existing validated level-open route.
- `tools/content/verify_campaign.py`: bounded breadth-first search using canonical tube-permutation keys; records optimal depth, discovered states and concrete indexed solution. No heuristic/pruning beyond identical state symmetry. Frozen results in `tests/campaign/solutions.json`.
- `tests/campaign/campaign_test.gd`: validates every file through real LevelLoader and replays each solver solution through authoritative GameSession/MoveRules, sequential unlock/duplicate completion and legacy progression checks.
- `tests/campaign/campaign_visual_test.gd`: real EN/AR renders for 3/4/5/6 tube boards, nonblocking tutorial commits, hint dismissal, tube bounds and scroll reachability.

## Verification

Commands: `python3 tools/content/verify_campaign.py`; pinned Godot `--headless --path . --script res://tests/campaign/campaign_test.gd`; GUI with existing Xorg :99 and `VISUAL_CAPTURE_DIR` plus `--audio-driver Dummy --script res://tests/campaign/campaign_visual_test.gd`. Existing G2/G3-A/G3-B/G4 suites and Python asset/APK tests retained in final CI. All destructive save tests run in isolated XDG/user paths. Early local runs found stale unsupported/previous-progress files in historical fixed test directories; evidence retained, clean isolated reruns pass. No real user/device saves deleted.

CI extends existing workflow only, keeps capture files outside project until after export and preserves APK size/signature/content checks. Final source/run/artifact/hash and actual screenshots accompany delivery. No unsupported claim of power-loss durability or OPPO acceptance. Prior native resource-retention warnings remain documented, no broad re-audit attempted.

Limitations: no human playtest, phone safe-area/audio/GPU/lifecycle acceptance; optimal depth does not measure puzzle frustration. Current compatibility-preserved tutorial order has longer first two boards. Preferences remain session-only. No Circuit/15+, rewards redesign, final font or Android config change. G15-QA-001 OPEN.

Rollback: revert this slice on a new branch or close its draft PR; retain PR #9 and existing stack. Saves containing newly completed IDs 3–14 cannot be read by the older two-level catalog; back up save bytes and prefer forward fixes after campaign use. Never delete saves to make a rollback appear successful.
