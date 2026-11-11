# Architecture Decision Records

| ADR | Date | Status | Subject |
|---|---|---|---|
| [ADR-0001](ADR-0001-g1.5-agent-orchestration.md) | 2026-10-24 | Accepted with known limitations by owner 2026-10-25; merge not approved | G1.5 agent orchestration, QA automation and Shizuku preparation |
| [ADR-0002](ADR-0002-level-progression.md) | 2026-10-25 | Approved progression; G2 subsequently authorized in ADR-0003, PR merges not approved | Level introductions, five Classic tutorials, 20-level MVP split across G3/G5 |
| [ADR-0003](ADR-0003-g2-classic-prototype.md) | 2026-10-25 | Owner-authorized G2 Classic implementation; no merge/G3 approval | Reversible prototype details, two independent QA tracks |

An ADR is accepted only after the owner approves it; proposals do not silently
change `docs/current/` or `AGENTS.md`.

- [ADR-0004 — Optical Clarity gameplay art direction](ADR-0004-optical-clarity.md): owner-approved one-screen production slice; wider rollout awaits review.

- [ADR-0005 — Real Game UI refinement](ADR-0005-real-game-ui.md): owner-approved bounded presentation and About-return update above PR #14.

- [ADR-0006 — G4 accepted checkpoint and integration boundary](ADR-0006-g4-checkpoint-acceptance.md): owner-reported 10/10 physical groups; PR15 accepted with deferred polish, no merge/G5 authorization.

- [ADR-0007](ADR-0007-protected-main-owner-authorized-agent-merge.md): owner-approved protected-main policy; Codex executes only exact owner-authorized PR merges after checks/review prerequisites, then verifies integrated CI. No merge authorized by the documentation instruction.

- [ADR-0008](ADR-0008-antigravity-primary-agent-runtime.md): owner-approved selection of Antigravity CLI (`1.5.5`) as the primary agent runtime (superseding OpenCode runtime selection in ADR-0001), unified `agents/<name>/agent.md` layout, multi-file explicit Worktree task grants, and verified partial-edit/discovery tool boundaries.
