# Agent runtime audit and bounded guard repair — 2026-11-13

Verdict: **NOT_READY** for the full autonomous workflow. This patch fixes
reproduced guard defects; it is not full production or device acceptance.

## Baseline and scope

- Actual device: Linux ARM64, Debian/Android PRoot; Antigravity CLI 1.5.8,
  Node v24.22.0.
- Repair branch: repair/agent-runtime-audit, based on
  cdf49968ec5705434eb6616135f6af23c9a3ff2b (the PR20 head).
- PR20 was already merged at 4aa223fc9575a9d25c3cb0d00bddb6161fca243b.
- The primary checkout remains feat/g5-p1-layer-circuit at c48e6185, with its
  pre-existing inventory and puzzle-validator changes preserved.
- No gameplay, levels, signing identities, merge, release or phone operation
  is part of this patch. Historical worktrees were not deleted or migrated.

## Findings and repairs

| Severity | Root cause and evidence | Result |
|---|---|---|
| HIGH | Git display porcelain was sliced as a literal filename. A pre-existing filename containing a double quote hashed as GONE before and after a real content change. | Use NUL-delimited status records and structured snapshots. Quote/rename/type/mode/index tests pass. |
| HIGH | Failed collection/comparison could be lost in shell pipelines/substitutions. | Explicitly check collection and comparison exits. Failure before launch prevents execution; failure afterward cannot print GUARD_OK. |
| HIGH | Hook preflight matched a command substring rather than enabled JSON structure. | Validate one enabled PreToolUse entry, exact matcher/command and bounded timeout. |
| HIGH | A newly introduced helper was agent-writable and then executed after the session. Independent review caught this before acceptance. | Freeze reviewed helper before launch; verifier replacement cannot run injected code or conceal an outside write in the regression. |
| HIGH | Agent could modify the original post-check allowlist during execution. | Freeze the allowlist before launch; regression rejects the added path. |
| MEDIUM | Each changed file was allocated completely for hashing. | Actual Antigravity Implementer added bounded synchronous SHA-256 reads and finally-closes the descriptor; multi-megabyte regression passes. |

The launcher also detects index changes and parses its complete main function
before execution. One diagnostic was invalidated by editing the old launcher
while Bash was reading it; its results were excluded. Another scope violation
was caused by concurrent maintainer edits and is not evidence of agent escape.

## Verification and review

Operator validation on the actual device:

- node --test tools/agent-guard/test-state.mjs tools/agent-guard/test-launcher.mjs:
  **PASS**, 10 tests, exit 0.
- bash tools/agent-guard/test-guard.sh with the inspected pin/fixture environment:
  **PASS**, 9 tests, exit 0.
- LS_PROJECT_ROOT=/root/projects/layer-sort node
  .agents/plugins/layer-sort-agent-kit/scripts/test-policy.mjs:
  **PASS**, exit 0.
- git diff --check: **PASS**, exit 0.
- Plugin strict validation: PASS; informational generic-logo note.

Raw validation and file hashes are retained privately in the worktree's ignored
.runtime/agent-audit-validation.json. The independent Codex reviewer inspected
this record and matched all five code/test hashes before returning scoped
**ACCEPT**. That acceptance does not cover full runtime readiness or a merge.

## Real execution and remaining acceptance gaps

Lead session afac19f2-6b1d-4c4b-b9a9-b3473546ee41 delegated the hashing task
to Implementer 76994b7d-e557-4dfb-baee-6af51c51e045. Real helper/test changes,
operator-run tests and independent review were observed. The Lead initially
returned SUCCESS after delegation, before delivery; subsequent timeouts and
stale partial summaries mean unattended end-to-end completion remains unverified.

Default-runtime session 43d840fb-a3d1-425a-88d2-41b57a327965 actually attempted
node --version and an ungranted file write. PreToolUse denied both; the command
error explicitly blocked node. The launcher then reported agent exit 0 and no
changed paths. However, the write denial cited a missing task grant while the
installed pin inspected by preflight contained one. **The active loading and
precedence issue remains OPEN; preflight of one file does not prove runtime
authority.** Automatic agreement between task registry and launcher allowlist
also remains unimplemented.

Disabling the global Layer Sort plugin removed Lead from discovery despite
workspace agent files being present. The workspace-only experiment was not
accepted. Original installed-plugin files and activation were restored, the
temporary installed task grant revoked, and the experimental workspace Hook
cleared. Lead discovery returned. The current bounded architecture keeps the
existing installed plugin as the runtime and removes this repair worktree's
stale cross-worktree Hook; other loading sources still need investigation.
Partial-edit acceptance and independent native Reviewer handoff remain NOT RUN.

## Cloud CI and device gate

Previous PR20 runs, inspected directly through GitHub:

- Guard: https://github.com/Yoseftext/layer-sort/actions/runs/43366243163 — PASS.
- Android: https://github.com/Yoseftext/layer-sort/actions/runs/43366243144 — PASS,
  including export and artifact uploads.

Those jobs actually checked out synthetic merge
29312d8eb541807cd15e0e367293ed3b3ce4cb00, combining cdf49968 with base 144c744b.
Do not attribute that APK solely to the head SHA or the later main merge.

Artifact 14024137085 was retrieved into the separate Cloud workspace. Downloaded
ZIP SHA-256 matched GitHub metadata:
c585b237489550b6339c335834d31db1599f8184dadcaa749bcb20ca1b046fa6.
Contained APK hash matched CI:
a66dbcffd95763bb1cc6536a4a2b61c1659d7020b42a28e9b1058f0c8bf73395.
CI reports com.yoseftext.layersort.dev, versionCode 5, versionName 0.3.2-g3b.
Extracted certificate SHA-256 matched CI:
de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e.
This is certificate metadata verification, not independent verification of every
APK signature scheme or a bit-for-bit build reproducibility experiment.

New-repair CI is separate from these earlier results. Physical install, device
connectivity, screenshots, logcat and physical QA were NOT RUN. The existing
agentctl has no install command. The device gate is BLOCKED / NOT IMPLEMENTED.

## Limits and next steps

These are application checks and post-run detection, not OS isolation. Ignored
files, outside paths, reverted transient writes, same-UID tampering and TOCTOU
races remain outside the detector's guarantee. Mode coverage concerns paths
surfaced by Git, not every permission bit on otherwise clean tracked files.

Resolve actual Hook/agent discovery authority, partial edits and complete
headless handoff before claiming readiness. Keep native runtime evidence distinct
from Cloud CI and owner-reported device QA. Sentry could not be queried without
configured authentication/project context. No secrets or private transcripts
are included here. See tools/agent-guard/README.md for operation and recovery.
