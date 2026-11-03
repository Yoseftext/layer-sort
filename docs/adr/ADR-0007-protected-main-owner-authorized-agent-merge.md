# ADR-0007 — Protected main and owner-authorized agent merge

Date: 2026-11-03. Owner: Layer Sort repository owner, explicit “Implement ADR-0007: Owner-Authorized Agent Merge” instruction. Status: OWNER APPROVED governance decision; no individual merge authorized by this instruction.

## Decision and supersession

Replace the prior owner-manual-only/blanket agent-main-merge prohibition with protected, owner-authorized agent execution through reviewed PRs. This supersedes the main-policy decision gate in ADR-0006 and the prior AGENTS prohibition only to the extent described here. Acceptance of PR15, its deferred minor polish and all non-governance scope remain unchanged. Main receives no direct pushes. No force pushes, protection bypass, or branch deletion without explicit owner authorization. Direct pushes to main are prohibited by repository governance. Technical branch-protection enforcement is **UNVERIFIED**; this policy does not assert that GitHub protections are enabled. No protection settings were changed.

## Observed policy versus technical enforcement

Read-only REST observation during this correction: `GET /repos/Yoseftext/layer-sort/branches?per_page=100` returned 19 branches, all with `protected: false`, including `main`. `GET /repos/Yoseftext/layer-sort/rulesets` returned HTTP 403; repository rulesets could not be independently verified. The 403 does not establish that rulesets are absent or enforced. Branch-protection enforcement remains **UNVERIFIED**; documented review/CI/owner-approval requirements must not be presented as proven GitHub enforcement.

## Target-specific technical verification gates

### A. PRs targeting main

Before any PR is merged into `main`, use authorized read-only access to verify effective branch protection and applicable rulesets, PR-only integration requirements, required CI checks and blocking review status. Record the technical enforcement evidence separately from documented policy. Require exact owner authorization under ADR-0007. If protection enforcement cannot be verified, **block integration into main**. A `protected: false` branch response or inaccessible rulesets is not proof of enforced PR-only integration.

### B. PRs targeting intermediate feature branches

For a stacked PR targeting an intermediate feature branch, require exact owner authorization, a reviewed PR, applicable CI checks passing and no unresolved blocking review comments. Verify any applicable protection or ruleset on the **actual target branch**, using authorized read-only access, and follow the full ADR-0007 authorization contract. If verification required for that target is unavailable, report that target-specific gate as unresolved and stop that merge. An unrelated inability to verify main's protections is **not a global blocker** for an intermediate feature-branch integration; never substitute main's status for checking the actual target.

In both cases the owner's approval must identify PR number, exact head SHA, target branch and confirmation of the intended reviewed changes. Any changed approval value requires renewed authorization. This scope clarification does not waive reviews, CI, applicable target protections, blocking-comment checks or exact owner approval. It grants no merge authorization and permits no changes to GitHub protection settings.


## Roles

- ChatGPT provides technical architecture guidance, independent change/risk review, test evidence assessment and a merge-readiness recommendation. A recommendation is not owner authorization; independence must be reported truthfully.
- The repository owner makes final product/engineering decisions, sets scope/priorities and explicitly authorizes each exact merge.
- Codex implements, tests and creates PRs, and may execute only the exact merge explicitly authorized by the owner after all preconditions pass.

## Exact merge authorization contract

Before executing a merge, record an explicit owner approval containing all four items:

1. PR number.
2. Exact full head commit SHA.
3. Target branch.
4. Confirmation that the reviewed changes are the intended changes.

Re-fetch the live PR immediately before execution and compare these values with the recorded approval. If any value changes, stop and obtain renewed authorization. General project approval, an accepted checkpoint, green CI or this ADR is insufficient. One approval never covers multiple PRs unless the owner explicitly authorizes each exact merge with the required information.

Required CI checks must pass for the current reviewed changes, and no unresolved blocking review comments may remain. Verify the PR diff, target, head, review state and applicable GitHub protections. If a check, permission or protection prevents execution, stop and report it; do not enable, disable or bypass protections without explicit owner authorization. Record the target tip used for integration and reassess any changed diff or stale evidence before proceeding. Never use a direct push to main as a substitute for a PR merge.

## After each authorized merge

Verify the resulting merge commit against the authorized PR/head, verify that the intended target branch contains the integrated result, and verify CI on that exact integrated commit. Do not present pre-merge CI as integrated-result CI. Report the resulting commit, target, run URLs, conclusions and any regression or verification blocker. Stop before the next PR and await its applicable explicit authorization; a failed integrated check never authorizes an automatic rollback or another merge.

## Current task boundary

This task changes documentation/governance only. It does not authorize merging PR17, PR16, PR15 or any other PR, modifying main, changing protections, gameplay, APK, saves, Firebase SDK/billing, or implementing G5/G6. G15-QA-001 remains OPEN and the detailed rules contract remains Draft. The existing PR17 base remains feat/real-game-ui at c961972365258baa34cae279dfc10ab46edce2f7.

If policy or authorization is ambiguous, record the discrepancy and request an owner decision rather than silently resolving it. Future changes require another explicit owner decision and corresponding governance updates.
