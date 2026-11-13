# Layer Sort runtime repair evidence

This report distinguishes the phone runtime from cloud CI. The primary device
is Linux ARM64 Debian/PRoot on Android. Antigravity 1.5.8 and Node 24.22.0 were
observed directly. No main merge is authorized or performed.

## Baseline and scope

The primary checkout was feat/g5-p1-layer-circuit at c48e6185, ahead eight, with
owner changes in tools/inventory.md, tests/g5/puzzle_validator_test.gd and
untracked content tooling. These are preserved. Competing worktrees include
agent-system-access, agent-system-clean, integration and agent-write-e2e.
PR20 was already merged. Repair branch repair/agent-runtime-audit starts from
agent-system-clean cdf49968; review is PR22. The remote main observed was
4aa223fc9575a9d25c3cb0d00bddb6161fca243b.

## Findings register

| Severity | Observed problem and root cause | Repair and evidence |
|---|---|---|
| High | Human Git status parsing missed changes in a pre-existing quoted filename. | NUL-delimited records, content/mode/link/index/HEAD snapshots; quoted-file regression. |
| High | Unchecked collection/comparison failures could report GUARD_OK. | Explicit failure propagation and exact repository-root checks; before/after failure regressions. |
| High | Agent could replace a verifier later executed by the launcher. | Freeze both helpers before execution; replacement/injection regression. |
| High | Workspace/plugin/pinned policy sources disagreed; missing-grant denials persisted despite source edits. | Workspace-only Hook, disabled overlapping kit, private content-addressed task snapshots, one task pointer. |
| High | A worktree absent from trustedWorkspaces did not discover the project Lead. | Session-only trust; actual agy agents probe discovers layer-sort-lead. Global settings unchanged. |
| High | Actual edit_file uses Path but was unconditionally blocked. | Same exact path validation for write_file and edit_file; positive/negative policy probes. |
| High | Lead ended before its worker delivered; command policy contradicted its duties. | Coordinator command tools and explicit native wait/inbox and reviewer handoff protocol; real E2E is a separate required gate. |
| High | Proposed launcher allowed alternate executable names to skip checks. | Independent review caught it; all executables use the same version/plugin/settings protocol. |
| High | Proposed prepare replaced pointers while older grants remained live. | Independent review caught it; serialized preparation, explicit close, active-pointer agreement. |
| Medium | CLI authority flags had alternate spellings. | Positive allowlist for task-facing flags; single-dash/compound override regressions. |
| Medium | Policy grants were duplicated and never expired. | CLI scopes and post-check derive from the same 30-minute lease; launch always revokes accepted grants. |

## Chosen architecture

Use workspace .agents/agents and skills, one workspace PreToolUse dispatcher,
and the policy source in the kit scripts directory. The global kit is disabled;
other plugins remain untouched. Historical packaged agent definitions are not
an additional authority. A reviewed infrastructure checkout prepares and runs
one dedicated nested worktree. No external framework or service was added.

Private .git/agent-runtime-policy contains snapshots, manifests, task pointers
and revocation markers. Credentials, CLI settings and session logs are never
committed. The Hook prevents supported tool requests; the post-check detects
persistent Git-visible deviations; worktrees support recovery and review.
Neither is OS isolation. Same-user attacks, TOCTOU, ignored or transient changes
and paths outside the task worktree remain limitations.

See [operating instructions](../tools/agent-guard/README.md).

## Verification record

First repair a18b7a8 passed local state/launcher, guard and policy checks and
independent review. PR22 CI succeeded for that head:
- guard run 43491964706
- Godot/Android run 43491964795

Those runs do not validate subsequent protocol changes. During protocol work,
an intermediate Bash syntax failure was caught by tests and independent review,
then corrected (bash -n exit 0). Retained private logs distinguish that failure
from the corrected focused run: launcher 11/11 PASS; policy PASS; state 6/6 PASS.
Final protocol, native agent E2E and new-head CI evidence must be recorded before
claiming the workflow accepted.

## APK and device gate

An earlier PR20 CI artifact was retrieved and hashed. It contains package
com.yoseftext.layersort.dev, versionCode 5, versionName 0.3.2-g3b according to CI.
APK SHA256 a66dbcffd95763bb1cc6536a4a2b61c1659d7020b42a28e9b1058f0c8bf73395.
Extracted certificate SHA256 de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e matches CI.
The workflow checked out synthetic merge 29312d8eb541807cd15e0e367293ed3b3ce4cb00,
not the PR head alone. Full signature-scheme validation, reproducible identical
build bytes, installation and physical QA are NOT RUN. Cloud artifacts and
physical-device verification are separate. No Sentry authenticated project
access was available; absence of runtime errors cannot be inferred.

## Current acceptance

Infrastructure regression checks are not full-cycle acceptance. Native useful
task completion, independent patch review, new-head CI, Godot runtime checks and
physical-device QA must each be reported from actual evidence. The real core agent cycle is now proven (see the completed-workflow follow-up).
The complete local Godot/device lifecycle remains NOT_READY while the import
crash and approved-device mismatch are unresolved.

## Live integration follow-up

Protocol repair commit 914fea519f09b84a9c31cd58385c6b9b30474d37 received independent scoped ACCEPT with launcher11/11, guard9/9, state6/6 and policy exit0. Native discovery found layer-sort-lead under session-only trust.

Native launch 226b9f3e-1d13-4119-a389-389ff61f0198 failed before execution because CLI1.5.8 advertised manage_inbox but its backend component registry rejected it. Commit18a80ed removes that explicit role tool; the next real Lead loaded and executed commands.

Session43a2d1f6-6808-462b-bb55-a72a4b3b05e8 delegated to Implementer956a58ff-f0b3-4fdd-bc6a-7604e1e50b5e. Actual edit_file produced a useful two-file buffer-size validation patch. A scoped independent source review found no blocker. However the Lead polled every6–8seconds and reran the broad suite; print timed out before native Reviewer. Exit3 propagated, GUARD_OK only described two scoped changed paths, and the lease was revoked. This is a failed full-cycle acceptance, not success. The patch and logs are preserved.

Commit1dc84dd adds the exact focused state-test command to both policy and CLI preapproval, removes the Lead status-list polling tool, specifies completion waiting and evidence reuse, and raises the default bounded session budget to1200seconds. Independent scoped code review ACCEPT. A fresh registered worktree agent-native-e2e is being used for a reproducible task from the original defect, without discarding the earlier patch.

### Observed local Godot/device blockers

Godot --version returned4.7.2.stable.official.ed1daf0bf. In an isolated worktree, headless --import aborted (SIGABRT after engine signal11, stack including libc free). The same failure occurs on a minimal empty project, excluding Layer Sort code as a required trigger. A bounded diagnostic with one worker thread, single-threaded scene and Dummy audio also aborted with the same stack. No production project or global engine setting was changed; the isolated diagnostic project file was restored. The subsequent G2 rules attempt exited1 because class registration was unavailable after the failed import. The underlying engine/PRoot memory fault remains unresolved; repeating the gameplay suite cannot establish a pass.

The authorized tools/device-tests/agentctl status returned UNKNOWN: expected exactly one approved OPPO CPH1937, found0 among1 online ADB devices. No raw ADB, package installation, input or system-setting changes were performed. The wrapper must establish an authorized matching device before physical QA.

## Completed real workflow

The final native task completed successfully with eight focused tests, both negative controls, native independent Reviewer ACCEPT, agent exit0 and two scoped changed paths. Grant closure and source hashes were independently checked. See AGENT_RUNTIME_E2E.md for the exact task, commits, session IDs, evidence and limitations. This supersedes the earlier pending-native gate; local Godot and physical-device blockers remain.

Final local integration check after the reviewed patch: state/launcher19/19 PASS, guard9/9 PASS, policy PASS, task ledger validate3records PASS, git diff --check exit0. No code changes followed these checks. Installed plugin files match their original backup, CLI settings SHA256 is unchanged, and the superseded experimental grant was revoked. The global Layer Sort kit intentionally remains disabled for the supported workspace workflow.
