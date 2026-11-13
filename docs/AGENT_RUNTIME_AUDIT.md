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
physical-device QA must each be reported from actual evidence. Until those
required runtime gates are proven, the system is NOT_READY.
