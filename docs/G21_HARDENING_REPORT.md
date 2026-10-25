# G2.1 engineering quality and hardening report

**Scope:** bounded hardening of the existing G2 Classic prototype. No G3,
Circuit, Firebase, save migration, production signing, new provider or new
infrastructure work was performed. PR #1, PR #2, PR #3, `main` and the
historical C# spike remain unmerged and unchanged.

## Baseline verified

| Item | Verified value |
|---|---|
| Branch | `feat/g2-core-gameplay` |
| Baseline G2 head | `8ac9e2f` (clean tree at audit start) |
| PR #3 | <https://github.com/Yoseftext/layer-sort/pull/3>, open, base `feat/agent-qa-orchestration` |
| G2 APK-producing commit | `437cd1f`; CI run `40194773406`; 68 headless checks |
| G2 device evidence | OPPO CPH1937, API 30, Classic fixture PASS |
| Parent PRs | #1 `f85172c`, #2 `4b2d313`; both open |
| Protected refs | `main` `6c13a07`, `spike/godot-csharp-android` `c50ca09` |

The earlier G2 evidence was re-read, not reused as G2.1 proof. Commits produced
by this pass: `a5cc47e` (hardening), `bf8dc8e` (test/QA corrections), `6fccd14`
(status fix and marker anchor), `b9f7584` (APK packaging boundary), plus a
documentation/evidence commit. The final tested code head is `b9f7584`.

## Audit before edits

Severity is based on the baseline, not on the final fixed state.

| Severity | Baseline location | Problem and evidence | Minimal correction |
|---|---|---|---|
| HIGH | `scripts/ui/classic_game.gd` input/lifecycle (`_ready`, `_on_tube_pressed`, no `_notification`) | A source selected before backgrounding stayed selected on return; the next destination tap could submit a move the player did not intend. No pause/focus policy existed. | Cancel selection and settle the committed state on focus loss/pause; block input until resume. |
| HIGH | `scripts/ui/classic_game.gd` and native tube `Button`s | No explicit conflicting-touch policy. Two fingers could feed sequential `pressed` callbacks into the source/destination flow. | Track touch contacts; cancel selection while contacts overlap; keep the domain animation lock. |
| MEDIUM | `scripts/application/game_session.gd` history | Every legal cyclic pour appended a full snapshot forever. Long sessions grew memory without bound. | Finite explicit limit, rejection when full, no silent history truncation. |
| MEDIUM | `scripts/application/level_loader.gd` path/read | Prefix-only path check allowed traversal-like paths; the whole file was read before the size check; non-finite colour values could reach numeric conversion. | Canonical packaged path, pre-read byte limit, finite/integer colour checks. |
| MEDIUM | `scripts/ui/classic_game.gd` load failure | A bad level only logged an error and left an empty screen. | Visible load error; no `READY` marker; no session. |
| MEDIUM | `tests/g2/classic_rules_test.gd` | Missing regression coverage for loader type/range/structure failures, snapshot ownership, bounded history, Restart during Win, focus cleanup, conflicting contacts and stale timers. | Add focused tests; keep the existing suite. |
| MEDIUM | `export_presets.cfg`, export step in `.github/workflows/android-build-g2.yml` | Found during final provenance: `export_filter="all_resources"` packaged docs/evidence JSON, imported evidence textures and compiled test scripts under `assets/`; the same policy would ship any imported tooling. This bloated the APK and made docs-only commits change the APK hash. | Exclude `docs/`, `tests/`, `tools/`; add a CI guard that requires both level JSONs and forbids those folders; rebuild and re-test the APK. |
| LOW | `scripts/presentation/tube_view.gd`, `classic_game.gd` layout | Two conflicting minimum tube widths (106 and 100). | One declared 100 px G2 minimum width. |
| LOW | `scripts/ui/classic_game.gd` rapid rejection | A rejected tap during the animation lock replaced the committed result with “Pour in progress” and never cleared it after unlock. Observed in a G2.1 rapid screenshot. | Retain the committed-result status instead of writing a transient message. |
| LOW | `scripts/ui/classic_game.gd`, `tools/qa/g2-device.py` | Fixed margins and image-strip coordinates only validate the owner's 720×1600 OPPO; no safe-area/dp abstraction. | Document as prototype-only; no speculative layout framework. |
| LOW | `scripts/domain/game_state.gd`, `move_rules.gd`, `game_session.gd` | Defensive full copies per command/read allocate small objects (fixture: 5 tubes, 12 layers), not per frame. | Keep; measure bounded history once in CI. No caching/pooling. |

**No BLOCKER found.** The pure pour rule copies its input, validates indexes,
colour and capacity, moves only the contiguous top group and increments the
move count once. Win evaluation requires full monochrome tubes. Invalid moves
return the unchanged input state to trusted domain callers; the session never
exposes it. Undo/Restart copy ownership was sound but under-tested. No domain
node/scene dependency, circular source dependency, new dependency, secret or
unused plugin abstraction was found by source inspection.

## What was fixed and why

| Commit | Change | Reason |
|---|---|---|
| `a5cc47e` | Focus/pause notification handling and contact tracking in `classic_game.gd`; selection cancellation; input suspension; conflicting-contact policy. | Removes the two HIGH input/lifecycle risks while preserving the existing UI flow. |
| `a5cc47e` | Finite `MAX_HISTORY = 512` with explicit `HISTORY_FULL` rejection; external read-only `animation_locked`; no silent drop. | Bounds memory without losing Undo semantics. This is a reversible G2 safety limit, not a save/progression specification. |
| `a5cc47e` | Canonical path and size checks, finite/integer colour checks, visible load error, consistent 100 px tube width. | Defensive content boundary and clearer failure. |
| `a5cc47e` | New loader, ownership, bounded-history, Win/Restart, focus, contact and timer regressions. | Closes actual coverage gaps rather than increasing test count for its own sake. |
| `bf8dc8e` | Corrected the cyclic stress fixture; added one four-tap rapid sequence in a single W3C action request. | The first stress fixture was illegal (test-oracle error); the device test needed to exercise the input lock, not Appium command latency. |
| `6fccd14` | Retained committed-result feedback after rapid rejected taps; anchored rapid evidence to the preceding Restart marker. | Removes a screenshot-confirmed stale status and makes logcat evidence robust to buffer rotation. |
| `b9f7584` | `exclude_filter="docs/*, tests/*, tools/*"` and a CI packaging assertion that both level JSONs are present and those folders are absent. | Keeps internal evidence/test code out of the shipped APK and makes the APK independent of documentation commits. |

The first G2.1 CI run `40214515717` **failed** because the new stress test tried
to pour colour 1 onto colour 0; that was a test-oracle error, not a domain bug.
The failed run remains in CI. The corrected stress test cycles one legal layer
between two empty tubes. The first G2.1 OPPO run also **failed** the rapid-input
oracle because a cumulative logcat count rotated out; that failure is preserved
and led to the Restart-anchored check, not to a reinterpretation as PASS.

## Intentionally left unchanged

- The domain transition (`MoveRules.pour`), Win predicate, tube model and
  session command shape were not rewritten; they were already correct and
  independently tested.
- The minimal portrait scene, temporary original art, English copy and fixed
  OPPO layout remain prototype presentation. No Splash, Home, Settings, About,
  Level Map, shaders, audio, premium glass or G3 navigation was added.
- No Circuit, Frozen, Shift or Connected mechanic; no solver/generator; no
  production save, migration, permanent hash or PRNG specification.
- No caching, pooling, threads or performance framework. The measured 512-
  snapshot workload did not justify one.
- No change to CI pin, debug certificate, package identity, Android settings,
  Appium/Supervisor/Termux/Shizuku configuration or phone services.
- `docs/current/04-RULES-CONTRACT.md` remains a draft; its permanent
  hash/PRNG/save/UX details are still unapproved.

## Architecture before and after

Direction remains:

`UI/input (classic_game.gd, tube_view.gd)` → `application (GameSession)` →
`domain (MoveRules, WinRules, GameState, TubeModel)`.

- **Before:** the session owned state/history/Undo/Restart and an animation
  lock, but history was unbounded and the lock was publicly writable. The UI
  owned selection and animation tokens but had no lifecycle/contact policy. The
  loader accepted a broad path prefix and read before checking size.
- **After:** the session still owns authoritative state, immutable snapshots,
  bounded history, Undo/Restart and the commit gate. The lock is externally
  read-only. The UI owns transient selection, contacts, animation tokens and
  lifecycle cancellation; it renders only `GameSession.snapshot()` copies.
  Domain modules still have no Godot node, device, animation or UI-coordinate
  dependency.
- **Invariant:** a valid command commits once; an invalid command returns an
  explicit reason and does not mutate state or history. Animation affects input
  admission only, never logical legality. Undo/Restart restore exact copied
  states and are safe at empty history, after Win and during the lock.
- **No new layer or interface:** this is the existing architecture with its
  boundaries enforced and its tests completed.

## Future mechanic extension seam

Circuit is **not implemented**. The minimum justified seam is:

1. **Metadata:** a future schema version and explicit mechanic descriptor in
   each level file; the current loader rejects non-empty `mechanics` in G2.
2. **State:** mechanic-specific state copied by `GameState.copy()` and included
   in replay identity only under a later approved format.
3. **Preconditions/consequences:** mechanic checks inside an atomic transition
   before Win evaluation; Classic validation must stay untouched.
4. **Undo:** history continues to store complete immutable snapshots, so a
   mechanic state change undoes with the move that caused it.
5. **Tests:** deterministic snapshots/replays and rejection tests for the new
   precondition, alongside unchanged Classic tests.

No strategy/plugin framework or unused mechanic classes were added. A future
mechanic extends these boundaries; it does not infer behaviour from level index
or add UI coordinates to the domain.

## Level content architecture

- One independently editable, versioned JSON file per fixture:
  `content/levels/level_001.json`, `level_002.json`. No GDScript per level.
- `tubes_bottom_to_top` means **index 0 is the bottom layer**; the last element
  is the top layer that can be poured. `palette` entries are colour IDs used by
  index.
- G2 schema/content version 1, capacity 4, 3–6 tubes, 1–2 empty tubes, exact
  colour quantities, no already-solved board, and no advanced mechanics.
- Validator rejects missing/extra fields, unsupported versions, invalid IDs or
  palettes, non-4 capacity, non-finite/fractional/out-of-range colour IDs,
  overlarge or malformed tubes, wrong empty counts, wrong colour quantities and
  solved starting states. Regression tests cover the missing/type/range/
  structure cases and path rejection.
- These are G2 fixtures only, separate from the approved future 20-level
  campaign. No generator or campaign content was created.

## State and input audit

| Case | Result |
|---|---|
| Invalid action mutates state | Rejected path returns unchanged input; session returns only copies. Tested. |
| Capacity/colour conservation | Pour moves at most free capacity and preserves colour counts. Tested. |
| Valid move commits once | Animation lock + history assertion; rapid UI callbacks rejected. Tested. |
| Undo restores prior state | Exact identity and move count restored. Tested. |
| Undo after Win | Winning move can be undone to the prior board. Tested. |
| Repeated Undo at empty history | Returns false; no state change. Tested. |
| Restart restores initial | Exact initial identity and empty history. Tested. |
| Restart during/immediately after animation | Token invalidation and lock reset; stale timer cannot commit. Tested. |
| Rapid repeated taps | Domain lock tested headlessly; one real four-tap W3C sequence committed exactly one move on OPPO. |
| Multi-touch/conflicting input | Contact overlap cancels selection and blocks commands; headless tests only, not full hardware multi-touch coverage. |
| Selection cancellation/stale selection | Same-tube tap, focus loss and conflicting contacts clear it. Tested. |
| Background/foreground | Focus loss clears selection, cancels animation token and settles lock; resume re-enables input. Headless tests; not device-lifecycle stress. |
| Visual sync after command/interruption | Every command and lifecycle handler refreshes from a fresh snapshot. Screenshot review found no stale board. |

## Track A — Code and CI QA: PASS

- **Final code head:** `b9f7584d700d016036e2143a07dbee09ee7a4ee3`.
- **CI:** [run 40226927770](https://github.com/Yoseftext/layer-sort/actions/runs/40226927770),
  conclusion `success`; PR check
  [run 40226931785](https://github.com/Yoseftext/layer-sort/actions/runs/40226931785)
  also `success` for the same commit.
- **Headless suite:** `G2_RULE_TESTS status=PASS checks=1149 failures=0`.
  This includes 1,024 repeated assertions from the 512-commit/512-Undo stress
  cycle; it is not 1,149 distinct scenarios.
- **Bounded history measurement:** `G21_BOUNDED_HISTORY elapsed_us=9064
  snapshots=512` on the CI runner. This is not Android performance evidence.
- **APK artifact:** SHA-256
  `e1a1e941ea2750eebc092106563dec1382bbc5c6697aaa131f300901151178a9`,
  size 28,342,813 bytes. `tools/verify-apk.sh` confirmed package
  `com.yoseftext.layersort.dev`, version `0.2.0-g2` (code 2), portrait,
  certificate
  `de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e`,
  `arm64-v8a`, and no C# payload.
- **Packaging scope:** `APK packaging scope PASS: levels present;
  docs/tests/tools absent.` Both `level_001.json` and `level_002.json` are in
  `assets/content/levels/`; no `assets/docs/`, `assets/tests/` or
  `assets/tools/` entries remain.
- **Source hygiene:** no sensitive filenames, private-key blocks, GitHub token
  patterns or added C# references in the G2.1 diff. No secret or dependency was
  introduced. No global service or permission was changed.

**Verdict: PASS.** This verdict covers code/headless/CI/APK inspection only. It
is not a device verdict.

## Track B — Real Android Device QA: PASS

- **Tested APK:** the Track A artifact, SHA-256
  `e1a1e941ea2750eebc092106563dec1382bbc5c6697aaa131f300901151178a9`,
  installed through the existing `agentctl` phone lock. The installed
  `base.apk` hash matched the expected and CI hashes inside the same
  reservation.
- **Device:** OPPO CPH1937, Android API 30, 720×1600 portrait. The app was
  foreground, portrait and emitted `READY`; no external overlay appeared in
  this final run. `G15-QA-001` remains **OPEN**.
- **Checks passed:** APK identity; launch/foreground/portrait/READY; valid
  pour; colour-mismatch rejection without a board change; Undo; Restart;
  rapid four-tap single-request input lock; ten-move solution/Win.
- **Rapid scenario:** one W3C touch action request, four 20 ms contacts at tube
  centres 0, 3, 1, 4. Exactly one move was committed (`0→3`) and the expected
  board was rendered; no accidental double input.
- **Visual review:** rapid screenshot showed `Moves: 1` and
  `Moved 1 layer(s)`, not a stale “Pour in progress”; Win showed `Moves: 10`
  and `Solved!` with four monochrome tubes and empty tubes. Tubes remained
  stable left-to-right under the device locale; touch indexes matched 0–4.
- **Runtime:** zero fatal/script-error lines in the final PID-filtered logcat.
  Captured logcat records the valid move, rejection, Undo, Restart, the rapid
  move, the second Restart, solution moves and Win; `markers.log` keeps the
  stepwise contract markers.
- **Evidence:** [Track B JSON](evidence/g21/track-b.json),
  [markers](evidence/g21/markers.log), and screenshots
  [initial](evidence/g21/initial.png), [valid](evidence/g21/valid.png),
  [invalid](evidence/g21/invalid.png), [Undo](evidence/g21/undo.png),
  [Restart](evidence/g21/restart.png), [rapid](evidence/g21/rapid.png),
  [Win](evidence/g21/win.png). Raw PID-scoped logcat and original screenshots
  remain private at `/tmp/opencode/g21-final-b9f7584/device/`.

**Verdict: PASS for this APK, fixture and device run.** This does not certify
other Android profiles, real-device lifecycle stress, full multi-touch hardware
coverage, accessibility, Arabic copy, or release art.

## APK and commit provenance

| Item | Value |
|---|---|
| Final tested code commit | `b9f7584d700d016036e2143a07dbee09ee7a4ee3` |
| Final evidence commit | recorded in PR #3 after this report (docs-only) |
| CI run / PR check | `40226927770` / `40226931785`, both success |
| APK SHA-256 | `e1a1e941ea2750eebc092106563dec1382bbc5c6697aaa131f300901151178a9` |
| APK size | 28,342,813 bytes |
| Installed APK SHA-256 | identical to CI artifact |
| Package / version | `com.yoseftext.layersort.dev` / `0.2.0-g2` (code 2) |
| Device | OPPO CPH1937, API 30, 720×1600 portrait |
| Track A artifact | `layer-sort-g2-debug.apk`, `arm64-v8a`, debug cert as above |

The prior G2 APK (`437cd1f`, SHA-256 `1f6751e4…`) and the intermediate G2.1 APKs
(`bf8dc8e`, `e6d0f636…`; `6fccd14`, `65b287…`) are **not** evidence for the final
code. The `6fccd14` APK was fully device-tested, but the later packaging fix
changed the APK, so `b9f7584` was rebuilt and re-tested from scratch.

## Preserved failures and corrections

| Failure | Treatment |
|---|---|
| G2.1 CI `40214515717` (`a5cc47e`): `RULE_FAIL: bounded history Undo` | Test-oracle error: the cycle poured colour 1 onto colour 0. Corrected fixture uses a legal single-layer cycle; failure remains in CI history. |
| G2.1 OPPO run 1 (`bf8dc8e`): rapid taps did not commit exactly one move | Logcat cumulative count rotated out. One rapid move was present; test was anchored to the preceding Restart marker. Not reported as a pass until rerun. |
| G2.1 OPPO run 2 (`bf8dc8e`): all checks passed, but rapid screenshot showed “Pour in progress” | Screenshot review exposed stale status after rapid rejection. Fixed in `6fccd14`; the device run was repeated on the new APK. |
| Final provenance check (`92d5eb2`, docs-only): rebuild produced a different APK | `all_resources` packaged `docs/`, tests and tooling, so evidence commits changed the APK. Fixed in `b9f7584` with an exclude filter and CI packaging assertion; the APK was rebuilt and fully re-tested on OPPO. |
| Earlier G2 failures (wrong focus query, RTL mirroring, full-destination oracle, stale READY) | Retained in G2 history; not erased or converted to passes. |
| G15-QA-001 external overlay/focus interruption | Remains OPEN. The `6fccd14` run saw an overlay without interruption; the final `b9f7584` run was clean. One clean run does not close the issue. |

## Remaining limitations

- `G15-QA-001` is still open; no external-overlay/focus-interruption closure is
  claimed.
- Track B covers one OPPO profile (720×1600, API 30, portrait) and one fixture.
  Safe areas, dp scaling, other densities, Android versions and tablets are
  unverified.
- Focus-loss/pause and conflicting-contact handling are covered by headless
  tests, not by a real-device lifecycle/multi-touch stress suite.
- History is capped at 512 snapshots for safety; this is not a permanent save,
  replay or progression specification.
- There is no crash-safe save, migration, campaign, tutorial set, solver
  certification, Circuit/Frozen/Shift/Connected mechanic, release signing,
  Firebase, localization or production art. These remain later gates.
- The 512-snapshot timing was measured on CI, not on Android; no performance
  optimization was justified or attempted.

## Recommendation

**PASS for the bounded G2.1 hardening scope.** Both independent tracks passed on
the same final code commit and APK, all BLOCKER/HIGH audit findings within scope
were fixed, and remaining issues are documented rather than hidden.

**Overall G2 acceptance remains CONDITIONAL** under the prior G2 report because
`G15-QA-001` is open, device lifecycle/multi-touch coverage is not exhaustive,
and the approved campaign, save and later mechanics are still unbuilt. No PR
merge, G3 start or scope expansion follows from this report; owner acceptance is
required.
