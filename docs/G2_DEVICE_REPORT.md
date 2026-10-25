# G2 Classic prototype — independent QA tracks (2026-10-25)

**Branch:** `feat/g2-core-gameplay` stacked on `feat/agent-qa-orchestration` at `4b2d313`; PR #1/#2 remain open and unmerged. **G2 gameplay build tested:** CI head `437cd1ffcb5394e1ff65b8d6fc16864a238951b8`, [run 40194773406](https://github.com/Yoseftext/layer-sort/actions/runs/40194773406), `com.yoseftext.layersort.dev`, version `0.2.0-g2` (code 2), SHA-256 `1f6751e4f8e7fa556f61c937d90080ce99b910868148a06c9acb700df2355247`, same stable debug signing certificate as G1. Later documentation-only commits require separate CI status checks; do not confuse a newer CI artifact with this installed/tested APK.

## Responsibility / dependency map

| File | Single primary responsibility |
|---|---|
| `scripts/domain/tube_model.gd` | Bottom→top layer stack and top contiguous-group count. |
| `scripts/domain/game_state.gd` | Logical board snapshot/copy and G2-only deterministic debug identity. |
| `scripts/domain/move_rules.gd` | Pure Classic validation and copied-state atomic pour. |
| `scripts/domain/win_rules.gd` | Empty/full monochrome board win oracle. |
| `scripts/application/level_loader.gd` | Strict versioned fixture JSON parsing and validation; rejects unknown mechanics. |
| `scripts/application/game_session.gd` | Command boundary, immutable-view snapshot, animation lock, Undo history, Restart. |
| `scripts/presentation/tube_view.gd` | Temporary visual tube/layer drawing and native Button hit target; never owns state. |
| `scripts/ui/classic_game.gd`, `scenes/game/classic_game.tscn` | Minimal G2 touchscreen selection, status, Undo/Restart, Win; sends commands to session only. |
| `content/levels/level_001.json`, `level_002.json` | Independently editable manual **test fixtures**, not the 1–5 tutorial campaign. |
| `tests/g2/classic_rules_test.gd` | Headless positive/negative rules, replay, undo, restart, lock and both fixture solutions. |
| `.github/workflows/android-build-g2.yml` | Existing pinned G1 toolchain copied for isolated G2 headless+APK build. Original G1 workflow untouched. |
| `tools/qa/g2-device.py`, `tools/qa/qa.py`, `tools/qa/test_qa.py` | Locked Appium G2 device test, configurable CI artifact name in provenance, local QA regression fixture. |
| `project.godot`, `export_presets.cfg` | Select G2 test scene and update **debug** build version/preset, same local app ID/cert/portrait/engine. |

Dependency direction: `TubeModel` → `GameState` → `MoveRules`/`WinRules` → `GameSession` → scene input/UI; `LevelLoader` creates the initial state. `TubeView` reads snapshots only. No scene, shader, Firebase or RNG dependency in the domain. No persistent save code or Circuit mechanic is included.

**Level schema v1:** one UTF-8 JSON file per fixture with `schema_version`, stable `level_id`, `content_version`, `capacity`, `palette`, `tubes_bottom_to_top`, explicit `mechanics: []`. Colour IDs are palette indexes; layers are stored bottom→top. G2 loader requires capacity 4, 2–6 colours, 3–6 tubes, 1–2 empties, four copies of every colour, an unsolved board, and no unknown fields or mechanics. This is deliberately narrow for manually checked fixtures, not a permanent schema/generator contract. The optional future rules/version/hash/save/PRNG details in `04-RULES-CONTRACT.md` remain proposed. A small bounded independent local search found a ten-move Classic solution for each fixture; the headless suite replays both with production move rules and checks Win. **No assertion that 20 MVP levels or G6 generator certificates exist.**

**Reversible G2 choices (ADR-0003):** same-tube second tap deselects, invalid destination retains selection, Restart clears history (not Undoable), Undo/Restart cancel the short visual input lock. Debug `identity()` is not a production save or canonical SHA format. These do not lock unresolved owner UX/PRNG/save decisions.

## Track A — Code & CI QA: PASS for G2 Classic prototype

- [Structured evidence](evidence/g2/track-a.json), [CI build 40194773406](https://github.com/Yoseftext/layer-sort/actions/runs/40194773406): `G2_RULE_TESTS status=PASS checks=68 failures=0` in `g2-rules.log`, `LAYER_SORT_G2_READY` in headless smoke. APK package/version/ABI/portrait/cert/C#-absence independently checked; downloaded CI artifact hash matches the local APK. No new SDK or paid dependency was installed.
- RULE-01..13 domain/fixture aspects: empty/full/mismatch/same/index, matching/empty/partial/contiguous moves, colour conservation, invalid non-mutation, win/non-win, Undo including winning/partial, exact Restart, rapid-input lock, deterministic two-step replay. RULE-15: malformed/unsupported level input and two individually loaded/replayed fixture files. **RULE-14 save/recovery is UNVERIFIED and deferred to G3**; G2 in-memory committed-state atomicity is covered, not crash-safe persistence. Advanced solver timeout half of RULE-15 is G6-deferred.
- Preserved initial failures: [run 40190490062](https://github.com/Yoseftext/layer-sort/actions/runs/40190490062) failed level JSON integer parsing; [run 40190795546](https://github.com/Yoseftext/layer-sort/actions/runs/40190795546) failed a wrongly specified mismatch test fixture. Both were corrected and then passed in later CI; not retroactively labelled PASS. Four stdlib QA oracle tests also ran locally with zero failures.

## Track B — Real Android Device QA: PASS for tested G2 APK/fixture

- **Actual device:** OPPO CPH1937, Android API 30, 720×1600 Portrait. APK installed via existing `agentctl install` queue; installed `base.apk` pulled and hashed **under the same `agentctl phone` reservation** as the Appium test, matching the above CI artifact SHA-256 exactly. No global service or Android setting changed.
- [Structured verdict](evidence/g2/track-b.json), [initial](evidence/g2/initial.png), [valid move](evidence/g2/valid.png), [invalid](evidence/g2/invalid.png), [Undo](evidence/g2/undo.png), [Restart](evidence/g2/restart.png), [Win](evidence/g2/win.png), and [captured stepwise Godot markers](evidence/g2/markers.log). Raw PID-scoped logcat and all original screenshots are private at `/tmp/opencode/g2-track-b-final/`. Appium checked current package, portrait, and focused Android window **before every tap**; no interruption occurred during the final run.
- Observed: `LAYER_SORT_G2_READY`; a real tap moved one layer `0→3` (board pixels changed); a subsequent mismatched colour was rejected **without changing tube interiors**; Undo and Restart each restored the exact visible initial board, with identical debug identity in the captured markers; a ten-move touch sequence solved the fixture and logged `LAYER_SORT_G2_WIN`. Visual inspection of actual device screenshots confirmed an unobstructed placeholder scene and distinct coloured layers. Final PID-filtered logcat had **zero fatal/script-error lines**. This does **not** certify all Android profiles, Arabic copy, accessibility, or production art.
- Earlier Track B reports remain private: first run misclassified focus because the QA runner queried the wrong OPPO dumpsys section; second exposed Android RTL reversing the logical tube row (fixed with explicit LTR board order); third test attempted mismatch against a full tube and the game correctly logged `FULL_DESTINATION`; fourth reused a running PID and lacked a fresh READY marker. The final runner force-stops **only the project app** and captures markers at each step before logcat rotates. None of those early failures is erased or called a gameplay PASS.

## Limits, rollback, gate recommendation

- **G15-QA-001 stays OPEN** as the separate external-overlay focus issue. The final G2 run did not encounter an overlay; a clean single run does not close the prior issue. Do not infer device success from Track A or infer future stability from Track B.
- G2 is a **playable Classic prototype with a tested fixture**, not five tutorials, a 20-level campaign, a solver certificate for release content, G3 save/navigation, Circuit, premium art, Firebase or a publishable release. Owner aesthetic review and future language/accessibility checks are outstanding.
- **Recommendation: CONDITIONAL G2 acceptance** for the prototype, based on distinct Track A and B PASS evidence; defer permanent schema/save/hash and release-content certification. Owner review/approval still required; no PR merge or G3 authorization follows from these results.
- Rollback: close/revert only the G2 stacked PR using a normal reviewed commit. PR #1/G1 smoke scene and PR #2/G1.5 configuration remain reachable; the existing `main`, historical C# spike, CI toolchain, Appium and phone services are untouched. A G2 debug APK was installed over the prior dev app using its stable debug cert; install the known G1 debug artifact through `agentctl install` if the owner wants to return the phone to G1 (not done automatically).
