# ADR-0003 — G2 Classic prototype authorization and reversible details

- **Date:** 2026-10-25
- **Owner:** Layer Sort project owner (explicit G2 implementation request)
- **Status:** Owner-authorized G2 implementation; no PR merge or G3 authorization
- **Scope:** Classic rules, minimal portrait Android test scene, individually versioned fixture levels, headless rule tests and device evidence. ADR-0002 progression is unchanged.

## Decision boundary

| Classification | Decision |
|---|---|
| APPROVED CORE RULE | Source→destination Classic pour, contiguous same-colour top group, matching/empty destination only, capacity-limited partial pour, no mutation on reject, atomic commit, empty/full-monochrome win, Undo, Restart, input lock while animating. |
| IMPLEMENTATION DETAIL SELECTED (G2 only, reversible) | JSON schema v1 fixture files; internal bottom→top integer colours and defensive state copies; debug `GameState.identity()` string (not production hash); same-tube second tap deselects, invalid target retains selection; Restart clears history and is not Undoable; 280ms input lock with Undo/Restart cancelling it. These choices are **not** blanket approval of draft `04-RULES-CONTRACT.md` details. |
| DEFERRED TO LATER GATE | PRNG, generation/solver and certificates, production save/migration, timers, Circuit and later mechanics, premium UX/art/navigation/Firebase. G2 fixture levels are manual and separately validated by a bounded local proof, not certified shipped content. |
| REQUIRES OWNER DECISION BEFORE PERMANENT CONTRACT | Canonical hash encoding, persistent history and Restart undoability, detailed tap/selection UX, timer tie-break, PRNG/solver budgets, save schema and migration. None blocks this isolated test prototype. |

## Consequences

- `docs/current/04-RULES-CONTRACT.md` remains proposed for its implementation details. The owner authorized *implementation of the approved Classic baseline*, not every proposed algorithm in it.
- Headless/CI and real Android device QA are **independent tracks**. Never infer a device PASS from a green CI build. Preserve early failures and G15-QA-001 as OPEN. Only the existing debug package, CI toolchain and locked phone paths are used.
- A G2 PR stacks on `feat/agent-qa-orchestration`; PR #1/#2 remain open, `main` and C# spike untouched. No merge, G3 work or global service change is authorized.

## Rollback

Close or revert the G2 PR with a normal reviewed commit. The G1 smoke scene/CI and G1.5 QA remain on the parent branch. No production save, credential or phone service was changed.
