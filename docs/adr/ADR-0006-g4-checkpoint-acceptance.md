# ADR-0006 — G4 checkpoint acceptance and integration boundary

Date: 2026-11-03. Owner: Layer Sort owner, explicit G4 Exit Gate instruction. Status: owner-approved checkpoint acceptance; integration/merge not approved.

PR15 at c961972365258baa34cae279dfc10ab46edce2f7 is ACCEPTED WITH MINOR NON-BLOCKING POLISH DEFERRED. The owner reports all 10 physical-device test groups passed; [the PR comment](https://github.com/Yoseftext/layer-sort/pull/15#issuecomment-6606381017) records the groups. These are owner-run results, not tests performed by this agent, and no raw device logs or instrumented benchmark were independently acquired in this task. Keep accepted gameplay intact and defer minor polish.

PR15 stays Open / Draft. Only stacked-PR audit, CI trigger reliability, documentation reconciliation and reviewable merge-readiness delivery are authorized. No merge, retargeting, rebase, main change, device operation, G5/G6 implementation, Firebase/billing, production signing or store release. The owner separately authorized clean isolated worktrees while preserving every tracked/untracked byte in /workspace/layer-sort-ui.

Godot 4.7.2 Standard, typed GDScript, Android Portrait, Compatibility and offline-first remain fixed. ADR-0002 progression is unchanged: Classic 1–14, first automatic Circuit 15, develop Circuit with ordinary Classic 16–20, 20 total MVP levels. Future G5 scope is Circuit proof and completing 15–20; it is not implementation authorization. Detailed 04-RULES-CONTRACT.md remains Draft. G15-QA-001 stays OPEN; Shizuku optional; Firebase future optional Spark-only.

This supersedes earlier active statements that implementation has not begun, G2 is not yet authorized, or PR15 still awaits owner visual acceptance. Those statements remain historical in dated ADRs/reports. No historical test result is rewritten. Rollback: revert this documentation reconciliation on a review branch; preserve the accepted gameplay and save files.

## Authority clarification — PR17 documentation remediation

This clarification records the owner's documentation consistency instruction; it does not amend approved gameplay decisions or grant merge authority. AGENTS defines agent operating constraints. `docs/current/00-START-HERE.md` is the active entry point. Approved, later owner-authorized ADRs supersede earlier project decisions within their scope; other active specifications conform. Conflicts must be recorded explicitly, never silently resolved.

**OWNER DECISION REQUIRED — MAIN POLICY:** AGENTS prohibits merging to or modifying main, while the dependency proposal starts with PR #1 targeting main. That proposal is descriptive and blocked. A separate explicit owner decision must establish the integration destination and authorized actor/policy before integration can proceed. This ADR does not relax the prohibition or authorize any merge. Historical G1/G1.5/G2 restrictions record the scope at their dates; they do not revoke later authorizations or reopen accepted PR15 work. All acceptance facts and deferred/unauthorized scope above remain unchanged.
