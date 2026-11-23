# Architecture Decision Records

| ADR | Date | Status | Subject |
|---|---|---|---|
| [ADR-0001](ADR-0001-g1.5-agent-orchestration.md) | 2026-10-24 | Accepted with known limitations by owner 2026-10-25; merge not approved | G1.5 agent orchestration, QA automation and Shizuku preparation |
| [ADR-0002](ADR-0002-level-progression.md) | 2026-10-25 | Approved progression; G2 subsequently authorized in ADR-0003, PR merges not approved | Level introductions, five Classic tutorials, 20-level MVP split across G3/G5 |
| [ADR-0003](ADR-0003-g2-classic-prototype.md) | 2026-10-25 | Owner-authorized G2 Classic implementation; no merge/G3 approval | Reversible prototype details, two independent QA tracks |
| [ADR-0004](ADR-0004-optical-clarity.md) | 2026-10-26 | Owner-approved one-screen production slice; wider rollout awaits review | Optical Clarity gameplay art direction |
| [ADR-0005](ADR-0005-real-game-ui.md) | 2026-10-29 | Owner-approved bounded presentation update | Real Game UI refinement |
| [ADR-0006](ADR-0006-g4-checkpoint-acceptance.md) | 2026-11-03 | Owner-accepted checkpoint; minor polish deferred; no merge/G5 authorization | G4 checkpoint and integration boundary |
| [ADR-0007](ADR-0007-protected-main-owner-authorized-agent-merge.md) | 2026-11-03 | Owner-approved governance decision; no individual merge authorized | Protected main and exact owner-authorized agent merge |
| [ADR-0008](ADR-0008-dynamic-antigravity-compatibility.md) | 2026-11-14 | Owner-approved for implementation and independent review; no merge authorized | Dynamic Antigravity CLI compatibility gate |
| [ADR-0009](ADR-0009-godot-prroot-runtime-launcher.md) | 2026-11-14 | Owner-approved for implementation and independent review; no merge authorized | Godot PRoot runtime compatibility launcher |

An ADR is accepted only after the owner approves it. Drafts do not silently
change `docs/current/` or `AGENTS.md`; owner-approved ADRs define decisions
within their explicit scope. Protected-main integration remains governed by
ADR-0007 and requires exact authorization for each PR.
