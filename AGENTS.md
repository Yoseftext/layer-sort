# AGENTS.md — Layer Sort

Android puzzle game (colored layers in glass tubes). Godot 4 **Standard** + **typed GDScript**, Android **Portrait only**, **offline-first**. No C# in the product.

## Documentation authority and operating constraints
1. `AGENTS.md` defines agent operating constraints. Its protected-main merge contract follows ADR-0007; a project plan or acceptance report is not exact merge authorization.
2. `docs/current/00-START-HERE.md` is the single active project entry point and routes readers to the controlling decisions.
3. Approved, later owner-authorized ADRs define project decisions and supersede earlier decisions within their stated scope. Draft ADRs/contracts and file recency alone do not grant authority.
4. Other active specifications must conform to the controlling ADR; placement in `docs/current/` does not override an approved later ADR.
5. Never resolve conflicts silently. Record the discrepancy, controlling ADR and affected specifications. If authority is ambiguous or an operating constraint prevents a proposed action, stop that action and request an explicit owner decision; update the relevant records before execution.
6. `docs/archive/` and dated gate records are historical evidence, not current authorization. The GPLv3 reference game is never opened or copied.

## Reading order (efficiency rule; changes no decision)
- G0/G1: read `docs/current/00-START-HERE.md` and `docs/current/03-PRODUCTION.md` (sections 2, 3, 6, 7). Open other files only when a gate needs them.
- G1.5 (agents/QA/tooling): read `docs/current/04-AGENT-OPERATIONS.md`; use `docs/current/05-QA-TEST-CATALOG.md` for test IDs and report fields; Shizuku only per `docs/current/06-SHIZUKU-TERMUX.md`.
- Later gates: read the sections the gate names (UX → `01-UX-ART.md`, engineering/risk/Firebase → `02-ENGINEERING.md`).

## Current scope
- G4 is integrated and accepted: PR18 merged at `144c744b92c3e66f71ad44a0d5b962121c72bba1`; owner-reported Android QA passed 10/10. Preserve accepted G4 presentation and the deferred minor polish from ADR-0006.
- G5-P1 Level15 is accepted by owner-reported physical-device QA (12/12 PASS). G5-P2 Levels16–17 at `6e3f10f8a3fec017aed756d96e69471eb3da238d` are **ACCEPTED — OWNER-REPORTED PHYSICAL DEVICE QA**, dated 2026-11-04: 13/13 PASS, zero reported failures. Exact groups and limitations: [G5-P2 acceptance](docs/G5_P2.md#owner-reported-physical-device-qa-acceptance--2026-11-04). These are not agent-run phone tests, benchmarks or logcat inspection.
- G5-P3 Levels18–20 at `8f3a49c1f84a982da060a06f9d47df02f249d0f3` are accepted by **OWNER-REPORTED PHYSICAL DEVICE QA:12/12 PASS**. This is separate from CI, agent testing and performance instrumentation; detailed group names were not supplied in the aggregate P3 report.
- **Current owner-authorized work: G5-Final visual/audio audit and proposal documentation only.** See [G5-Final proposal](docs/G5_FINAL.md). No visual/audio implementation, asset import or dependency is authorized yet. Preserve accepted Levels1–20, mechanics, navigation, G4 identity and schema1 saves.
- G6, production release and any further PR merges remain unauthorized. The PR18 protection exception applied only to that exact merge.
- The G0–G2 bullets below summarize historical gate scope; they do not revoke subsequent explicit owner authorizations.
- G0: new branch `feat/gdscript-foundation` from a safe base, record the baseline, do not touch `main`.
- G1: Godot Standard portrait smoke scene, pinned engine + export templates (`ENGINE_VERSION.lock`), APK built by GitHub Actions, installed on the connected OPPO via `agentctl` / `phone-queue` / Appium, with screenshot + logcat. Done criteria are in `03-PRODUCTION.md` section 2.
- G1.5: project-scoped OpenCode agents (`.opencode/agents/`), QA workflows under `tools/qa/`, dependency inventory, negative-test evidence, screenshot review, and optional Shizuku preparation. Policy: `docs/current/04`–`06`, `docs/adr/ADR-0001`. No gameplay, Firebase, signing, or paid services.
- G2: Classic domain, minimal playable portrait scene, individually versioned fixture levels, unit tests and **separate** CI versus locked real-device evidence; G15-QA-001 remains OPEN.

## Hard rules
- No direct pushes to `main`. No force pushes or history rewrites. No branch/tag deletion without explicit owner authorization; never run `rm -rf` on the repo or phone. Preserve `spike/godot-csharp-android`. Integration must use reviewed PRs with required CI passing and no unresolved blocking review comments. Do not change or bypass GitHub protections without explicit owner authorization.
- Codex may execute a merge only after explicit owner approval identifies the PR number, exact full head SHA, target branch, and confirms the reviewed changes are intended. Re-fetch and verify immediately before merging; any changed approval value requires renewed authorization. General project approval is insufficient; never merge multiple PRs under one approval unless each exact merge is explicitly covered.
- After an authorized merge, verify the resulting merge commit, intended target branch and CI on the exact integrated result; report outcomes/regressions and stop before the next PR pending its applicable authorization. See [ADR-0007](docs/adr/ADR-0007-protected-main-owner-authorized-agent-merge.md).
- No billing, Firebase/Play accounts, production signing, ads, IAP, paid APIs, or new credentials. No secrets in Git.
- Do not change phone services (Termux, ADB, Appium, supervisor) without owner approval. Use the device lock/queue.
- Never claim "PASS / works / fixed" without tool logs. Report what was verified, what was not, and why.
- G1.5+ agents and QA scripts follow `docs/current/04-AGENT-OPERATIONS.md`: strict `PASS|FAIL|SKIP|UNVERIFIED`, deliberate negative tests, APK/commit provenance, one phone-mutating session at a time, and no unrestricted Shizuku bridge or root claim.
- Every PR: scope IDs, commit, build link, screenshots, test output, install/touch/logcat evidence, rollback note (see `03-PRODUCTION.md` section 6).
- Keep PRs small. One concern per PR. No unrelated refactors.

## Decisions and open items — owner decides, agent does NOT decide
1. **Resolved by owner ADR-0002:** 20-level Core MVP, Classic 1–14 (only 1–5 tutorials), automatic Circuit starts at 15; Circuit/ordinary Classic alternate through 16–29, Frozen starts 30, Shift 45, Connected 60. G3 covers Classic 1–14; G5 completes 15–20. No G2 implementation authorization follows from this decision.
2. Final `applicationId` (use a local debug id; it must not collide with the old spike app).
3. G1 smoke pinned Godot Standard 4.7.2 and a stable debug keystore in CI; do not change the pin or credentials without a reviewed decision.
4. `docs/current/04-RULES-CONTRACT.md` is a **draft awaiting owner approval**; approved Classic baseline and G2 implementation are authorized in ADR-0003, but its proposed permanent hash/PRNG/save/UX details are not.
5. G1.5 is **ACCEPTED WITH KNOWN LIMITATIONS**; G15-QA-001 remains OPEN. Shizuku native-Termux `rish id` yielded `uid=2000(shell)` by owner report; Debian/QA bridge remains optional, unverified, and not approved.

## Output of each session
Commit hash, branch, PR link, build link, device evidence, exact blockers. Nothing else is "done".

## Governance roles — ADR-0007

ChatGPT supplies architecture guidance, independent change/risk review, test-evidence assessment and a merge-readiness recommendation. The repository owner retains final decisions, scope/priorities and exact per-merge authorization. Codex implements/tests/opens PRs and executes only an explicitly authorized exact merge. The current G5-Final audit authorizes documentation only, with no runtime polish implementation, merge, direct main modification, protection change or G6.
