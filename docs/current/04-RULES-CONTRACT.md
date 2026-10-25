# Layer Sort — G2 rules contract (DRAFT FOR OWNER APPROVAL)

**Status:** PROPOSED, NOT APPROVED; planning only, no gameplay implementation authorized.  
**Owner decision required:** accept/amend this contract via a dated ADR, update `00-START-HERE.md` and affected active files, then separately authorize G2.  
**Sources:** `00-START-HERE.md` B02/B03/B06/B09/B10, Q05 and §3; `02-ENGINEERING.md` S01–S04; `03-PRODUCTION.md` PLAN-G2/G3/G5/G6; `05-QA-TEST-CATALOG.md` RULE-01..15. Existing decisions are labelled **EXISTING**; exact serialization/algorithms/limits below are **PROPOSALS** until accepted. No GPLv3 reference is used.

## 1. Scope and terms

- **EXISTING:** Core Classic play is offline, portrait, typed GDScript; player selects source then destination. A tube holds a bottom-to-top sequence of discrete colour layers with uniform capacity inside a level. A valid pour moves the contiguous top block of one colour, limited by destination free space. Goal: every tube empty or completely full with one colour. Hints indicate a valid action, never execute it. No random loss.
- **EXISTING:** `GameState`, not Scene Nodes, owns logical state. All commands go through validation; the order is input → validate → commit → deterministic mechanic evaluation → win/timeout → snapshot/save → presentation. G2 implements *Classic* only; Circuit latch rules already described in §3 of `00-START-HERE.md` are for G5, not silently implemented in G2.
- **PROPOSED notation:** `tubes[i]` is an array from bottom to top, length `0..capacity`; colour IDs are stable non-negative integers defined by a level palette, not display colours. `N` tubes are indexed `0..N-1`; immutable logical snapshots never hold a rendering Node.

## 2. Validate and transfer one Classic pour

**EXISTING guards:** reject absent/out-of-range/same source and destination, empty source, full destination, destination top colour different from source top (unless destination empty). Capacity is common across tubes in this level.

**PROPOSED precise transition (requires approval):**

1. Accept one source→destination command only in `READY`. During `LOADING`, `COMMITTING`, `ANIMATING`, `PAUSED`, `RECOVERY`, `WON`, or `TIMED_OUT`, reject without logical mutation. Visual source selection alone is not a committed move.
2. Count the source's contiguous top layers of the same colour (`block_size >= 1`). Calculate `free = capacity - len(destination)`; `moved = min(block_size, free)`. Never skip layers or reorder the source/destination stacks. If `moved == 0`, reject; otherwise remove exactly `moved` from the source top and append them in bottom-to-top order to the destination.
3. Validate against one immutable pre-move snapshot and commit exactly once. One accepted pour increments `move_count` and `event_sequence` once; an invalid command does not alter board, move count, history, save, seed, or event sequence. Emit a typed rejection reason for UI; no animation or SFX changes the committed outcome.
4. After commit, evaluate mechanics (none for Classic), then win/timeout. A win needs *all* tubes empty or full and monochrome. A partly filled monochrome tube is not solved. If optional timed mode exists later, define the simultaneous win/timeout priority before shipping timed levels (see owner decisions).

**PROPOSED selection policy:** tap source selects it; tapping a different non-empty source changes selection without a move; tap destination submits the command. Selection/hover/highlight are presentation state, not persisted game state. Exactly when a same-tube second tap deselects and when an invalid destination retains selection require owner/UX confirmation; tests must not assume them before decision.

## 3. Undo, restart and restoration

- **EXISTING:** Undo restores previous *complete logical* state including future mechanics such as Circuit latch/sensor state. Restart is required in G2; animations never own state. `GameState` is immutable or defensively copied; an interrupted animation restores the last committed snapshot.
- **PROPOSED:** Before each accepted command, push a deep-copied logical snapshot (`tubes`, capacity, level/content/rules versions, seed/PRNG state if applicable, mechanic flags, move count, timer logical state, event sequence). An invalid or merely selected action creates no history. Undo restores the previous snapshot atomically; empty-history Undo is a no-op with a typed reason. It does **not** re-run mechanics or consume randomness. Whether undo itself increments a separate audit/transaction counter is undecided; `event_sequence` inside a restored state must be compared to its snapshot, not inferred from wall clock.
- **PROPOSED:** Restart restores the canonical initial board/mechanic state from the same packaged level/version/seed, resets attempt-local move count/history, and leaves durable completion/unlock progress untouched. Specify whether a Restart is itself undoable and whether timing restarts before coding (owner decisions). No save may contain a half-applied pour; render in-flight animations may be cancelled after process death and the committed board shown.

## 4. Determinism, ordering and state identity

- **EXISTING:** One deterministic logical transition per validated command. During `ANIMATING` block another move. Ordered mechanic evaluation and win/timeout occur before save or visual/audio notifications. Repeated actions from the same state must yield the same logical result; do not involve frame delta, locale, display colour, or wall-clock time in Classic rules.
- **PROPOSED canonical identity:** Serialize an explicitly ordered versioned logical payload with `rules_version`, `level_id`, `content_version`, `capacity`, ordered tube arrays (bottom→top), `active_mechanics`, future flags/charges/links, seed/PRNG state, `move_count`, deterministic timer state, and `event_sequence`. Exclude selection, animations, audio, file timestamp, hash field and unrelated account/device identifiers. Use fixed integer ranges, UTF-8 identifiers, sorted named-field encoding and a specified digest (candidate: SHA-256 of canonical UTF-8 JSON); no Godot Dictionary iteration order or `hash()` output. Pin exact byte format and integer bounds with cross-platform golden fixtures before implementation.
- **PROPOSED test semantics:** same initial level/version/seed plus identical accepted command stream yields bit-exact canonical logical state and digest on headless CI and device. Undo restores the pre-move logical digest; an optional separate save revision counter is outside the gameplay digest. State hash is an integrity/replay tool, not an anti-cheat/security guarantee.

## 5. Level data and seeded reproducibility

**EXISTING:** initial teaching levels are curated/reviewed, first levels use 4 layers per tube and 3–4 colours with 1–2 empty tubes; each level pins a rules version. A shipped level requires solver/validator proof. A later generator is behind G6, not a prerequisite to write G2 Classic domain logic.

**PROPOSED illustrative JSON (not an approved schema or a level):**

```json
{
  "schema_version": 1,
  "level_id": "classic_example",
  "content_version": 1,
  "rules_version": 1,
  "chapter": "classic",
  "capacity": 4,
  "palette": ["c0", "c1", "c2"],
  "tubes_bottom_to_top": [[0, 1, 0, 2], [2, 0, 1, 2], [1, 2, 0, 1], [], []],
  "mechanics": [],
  "seed": 0
}
```

Validator rejects unknown versions/mechanics for active rules, duplicate/invalid IDs, empty palette, out-of-range colour IDs, negative/over-capacity stacks, inconsistent layer counts (if enforced by the approved level policy), unsupported dimensions, or a board with no certification when required. A zero seed denotes a *curated* example here, not a promise of a zero-seed generator. Size limits, allowable palette and canonical ID encoding must be agreed before accepting arbitrary external JSON. Never load executable code or network data from a level file.

**PROPOSED PRNG contract for any later generated level:** choose/pin a documented fixed-width algorithm, seed width and endian/overflow semantics (candidate: PCG32 with a named stream), plus golden vectors across CI/device. No global Godot RNG, wall-clock seed, unspecified shuffle, or platform-dependent iteration for rule transitions. Record `(generator_version, rules_version, seed, stream, solver_certificate)` with generated content. Changing algorithm or ordering bumps generator/content version; already shipped content keeps its old version or a deterministic fallback. **Selection of PRNG, integer bounds and vectors is an owner approval item, not a settled choice.**

## 6. Solver / generator boundary (G6 work, contract prep only)

- **EXISTING:** tutorials curated; no unsolved level ships. A later generator passes Solver + Validator + Difficulty Rating + Playtest. Solver state includes every mechanic and available action at that gate (including Shift charges); no solver can certify a partial mechanic model. User-visible hint indicates a valid move; it does not apply it.
- **PROPOSED:** solver consumes immutable initial state plus pinned rule version, produces legal command sequence and deterministic certificate/replay trace. Validate each step with the same production move rules, confirm final win and reject any result that exceeds resource limits or times out. `TIMEOUT/UNKNOWN` is **not** `UNSOLVABLE` and cannot justify publishing a level. Rate difficulty only after proof; offline/CI batches use bounded node/elapsed-time/memory budgets and checked-in fallbacks. Do not run unbounded generation on the phone.
- **OWNER TO SET:** exact node/time/memory budgets, search-order/tie-break rule, certificate version and target devices. Do not claim a numerical cutoff or solvability proof without a run.

## 7. Local save, recovery and migrations

- **EXISTING (`02-ENGINEERING.md` S03/S04):** store only committed state; attempt `save.tmp` plus safe flush/close and atomic rename where available, otherwise rotating `save_a/save_b`; keep last-known-good snapshot with version, checksum and sequence. On recovery choose latest complete valid snapshot. If recovery impossible, return to a safe chapter point without losing completed unlocks; surface errors. Maintain `save_schema_version`, stepwise migrations and fixtures from actual prior releases. Unknown fields are ignored safely; content changes retain `level_id/content_version` with packaged fallback or explicit completion mapping. No cloud dependency or fake encryption claim.
- **PROPOSED record:** `{save_schema_version, record_sequence, level_id, content_version, rules_version, seed, canonical_committed_state, attempt_history_or_replay_reference, completed_levels, settings_version, checksum}`. Checksum covers a specified canonical byte payload excluding checksum itself. On load, validate integrity, versions and data bounds *before* migration; migrate one version at a time into a new slot, verify replay/state invariant, then promote atomically. Do not overwrite the last valid slot until new data is proven valid. If a newer unknown schema appears, stop safely and preserve bytes; do not silently downgrade.
- **OPEN:** retention of undo history across restarts; exact record/slot layout and checksum algorithm; whether save/restart is synchronous or queued; how progress is separated from attempt state; no-release-yet baseline migration fixture. These need owner decisions/ADR before implementation. Force-stop during animation/save, truncated/corrupt slot, missing content version, full storage and offline startup are required later tests; G2's scope is the domain contract and a test scene, not a claim that G3 persistence is complete.

## 8. RULE-01..15 — proposed executable oracle definitions

Each test starts from a named canonical fixture, records command, expected/rejected result, board, move count, history and state hash; headless typed-GDScript assertions must be paired with one bounded device flow for the test scene. These definitions are **proposed** names/fixtures, not PASS evidence.

| ID | Input / oracle |
|---|---|
| RULE-01 | Empty source → typed reject; no state/hash/history/sequence change. |
| RULE-02 | Source and destination same index, negative or out-of-range index → reject without mutation. |
| RULE-03 | Full target → reject; no overflow even with matching top. |
| RULE-04 | Nonempty target with mismatched top → reject; empty target is legal when source valid. |
| RULE-05 | Matching nonempty target: transfer entire contiguous top block if space suffices; preserve bottom-to-top order. |
| RULE-06 | Partial pour: top block larger than free space moves **only** `free` layers; source remainder stays ordered. |
| RULE-07 | Source with a different-colour layer below the top block: never transfer that deeper layer in same command. |
| RULE-08 | Valid commit increments move count/sequence once and creates one undo snapshot; rejected/selection-only actions create none. |
| RULE-09 | Solved iff every tube empty or full and single-colour; partly full single-colour and mixed full tube do not win. |
| RULE-10 | Undo after one valid pour restores complete pre-command logical state/hash; empty-history Undo is safe no-op. |
| RULE-11 | Restart reconstructs pinned initial state and clears attempt-local history without erasing durable completion; exact undoability pending owner decision. |
| RULE-12 | Two identical seeded command streams yield identical canonical bytes/hash; changing locale, animation timing or presentation has no effect. |
| RULE-13 | Two fast taps / two-finger simultaneous commands during `COMMITTING` or `ANIMATING` cannot double-commit; at most one accepted logical transition. |
| RULE-14 | Interrupt during animation/save restores either fully committed snapshot or last-known-good snapshot; never a partial layer move; corrupted slot is rejected. |
| RULE-15 | Invalid level content/version/unsupported mechanic fails validation; any later solver `TIMEOUT/UNKNOWN` cannot be treated as solved/publishable. |

## 9. Decisions requiring the owner before lock or G2 implementation

1. **Level allocation:** `00-START-HERE.md` Q05 says Core MVP has 20 levels and Classic play; B09 and §3 place Classic at 1–19 and Circuit at 20–34. `03-PRODUCTION.md` G3 calls for 20 levels, while G5 separately proves Circuit with tutorial level 20 and G3 precedes G5. **Proposal under evaluation:** 20 total levels, 1–19 core teaching, level 20 first Circuit introduction. This matches B09 numbering but conflicts with a *Classic-only* G3/Core MVP and moves Circuit earlier than G5; owner must decide whether MVP is 19 Classic + one separately gated Circuit, 20 Classic with renumbered Circuit, or another explicitly documented allocation. Do not lock the proposal silently.
2. Canonical byte/hash encoding and integer/colour limits; selection and invalid-tap behaviour; undoable Restart/history persistence; optional timer tie-break (if introduced); PRNG algorithm/vectors and generator budgets; exact save slots/migration/checksum layout.
3. Approval path: dated owner-approved ADR + update to `00-START-HERE.md` and affected `03-PRODUCTION.md`/`02-ENGINEERING.md`/QA catalog, then separate G2 authorization. Neither this draft nor G1.5 acceptance authorizes code or resolving conflicts by implementation.
