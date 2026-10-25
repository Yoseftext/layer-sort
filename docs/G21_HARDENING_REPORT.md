# G2.1 source audit and bounded hardening

Baseline verified: `feat/g2-core-gameplay` at `8ac9e2f`, PR #3 targets
`feat/agent-qa-orchestration`; parent PRs remain open. Existing G2 evidence:
68 headless assertions and OPPO fixture PASS for APK commit `437cd1f`.
That baseline evidence is not a G2.1 verdict.

## Audit before edits (baseline locations)

| Severity | Location | Evidence / minimal correction |
|---|---|---|
| HIGH | `classic_game.gd:95–155` input/lifecycle | No focus-loss/background handler: select a source, leave app, return and tap another tube; stale selection submits a move. Cancel selection and settle committed state on focus loss; block input until resume. |
| HIGH | `classic_game.gd:95` and native tube Buttons | No explicit conflicting-touch policy. Two fingers can feed sequential `pressed` callbacks into the source/destination flow. Track touch contacts and cancel selection while multiple contacts overlap; keep domain animation lock. |
| MEDIUM | `game_session.gd:28` | Every legal cyclic pour appends a full snapshot forever. Bound history with an explicit rejection, never silently drop Undo state. |
| MEDIUM | `level_loader.gd:6–12,57–61` | Path prefix allows traversal; whole file read precedes size check; nonfinite colour values reach numeric conversion. Canonicalize packaged path, check bytes before read, reject nonfinite numbers. |
| MEDIUM | `tests/g2/classic_rules_test.gd:84–101` | Missing-field/type/fractional/overflow validation and interrupted/Win session lifecycle cases absent; add focused regressions and snapshot ownership checks. |
| MEDIUM | `classic_game.gd:17–20` | Load error only logs and returns an empty screen. Show a visible error, do not emit READY. |
| LOW | `tube_view.gd:15`, `classic_game.gd:54` | Two conflicting minimum widths (106 vs 100), plus fixture-specific device coordinates. Use one declared G2 width; don't build speculative layout infrastructure. |
| LOW | `classic_game.gd:97` | Rapid rejected taps overwrote the committed result with "Pour in progress" and never cleared it after unlock (seen in G2.1 rapid screenshot). Retain committed-result feedback instead. |
| LOW | `classic_game.gd:27–72`, `g2-device.py` | Fixed margins and coordinate/image strips only validate OPPO 720×1600. Other profiles and true dp/safe-area instrumentation remain later UX/device work. |
| LOW | `game_state.gd`, `move_rules.gd`, `game_session.gd` | Defensive full copies on commands/read are small (fixture: 5 tubes/12 layers), not per frame. No caching/pooling justified; measure bounded history workload in CI instead. |

No BLOCKER found. Pure pour copies the input, validates indexes/colour/capacity,
and moves only the top group. Win checks full monochrome tubes; loader rejects
already-solved/empty content. Undo/Restart copy ownership is sound but needed
more tests. Invalid pour returns its unchanged input reference to trusted domain
callers; session exposes only copies and explicit success/reject dictionaries.
No circular source dependency, Node in domain, new dependency, secret or need
for a plugin framework was found by source inspection. Existing command-pattern
permissions are not Git protection; owner merge approval remains mandatory.

## Scope and extension seam

Before/after direction stays UI/input → session → rules/state; TubeView renders
snapshots only. Circuit later needs explicit loader metadata validation, copied
mechanic state in GameState, preconditions/consequences in the atomic transition
before Win, and snapshot/replay tests. Extend those existing boundaries in G5;
do not change Classic validation, infer mechanics from level index, or introduce
unused strategy/plugin classes now. No production save/hash format is selected.

G2 fixture JSON remains separate from future campaign content: one independently
editable file per fixture, schema/content version 1, layers bottom→top, capacity
4, explicit empty mechanics. Artwork stays temporary. G15-QA-001 remains OPEN.

## QA results

Track A and Track B are independent; results will be appended after execution.
The first hardening CI [40214515717](https://github.com/Yoseftext/layer-sort/actions/runs/40214515717)
failed because the new stress test attempted to pour colour 1 back onto colour
0, so its alleged cycle was illegal. This was a **test-oracle error**, not a
domain bug: the corrected fixture cycles a single layer between two empties
while another partial tube keeps the board unsolved. The failure remains in CI.

## Fixed / intentionally unchanged

- Lifecycle/contacts cleanup in `classic_game.gd`, finite history and externally
  read-only lock property in `game_session.gd`, canonical packaged path and
  byte/numeric bounds in `level_loader.gd`, consistent 100px minimum tube width
  in `tube_view.gd`; no domain transition rewrite. Loader failures now show text.
- History accepts **512** committed snapshots; when full, a legal move is
  rejected with `HISTORY_FULL` and no mutation. Undo/Restart remain available.
  This G2 safety limit is reversible, not a permanent campaign/save decision.
  No history truncation and no hidden loss of Undo states.
- `classic_rules_test.gd` adds actual gap coverage: numeric/missing/structural
  rejection, external snapshot ownership, bounded cyclic commit/Undo, Restart
  during Win lock, focus cleanup, rapid callbacks, conflicting contact cleanup,
  and stale timer cancellation. A timed stress log records the 512-snapshot
  workload; we did not optimize or add caching/pooling based on tiny fixtures.
- `g2-device.py` adds one four-tap rapid sequence in a single W3C action request
  (four 20ms contacts), requiring exactly one move and the expected visual
  board; not four slow independent Appium calls. Existing real touch/Undo/
  Restart/ten-move Win sequence and APK hash check remain.
- Static source coupling and defensive copies remain appropriate. No Circuit,
  save migration, canonical permanent hash, asset dependency, G3 navigation,
  global service or permissions changes. Fixed OPPO layout/English copy remain
  prototype limitations. Full multi-touch hardware and lifecycle device stress
  are not implied by headless lifecycle/contact tests.
