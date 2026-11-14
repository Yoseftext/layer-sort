# Antigravity task workflow

Antigravity 1.5.8 is the primary runtime. Workspace agent definitions in
.agents/agents are authoritative. The packaged agent copies are historical;
do not enable the global layer-sort-agent-kit plugin alongside workspace agents.
The policy source remains in .agents/plugins/layer-sort-agent-kit/scripts.
No new framework, service, or dependency is required.

## Run a task

Use a reviewed infrastructure checkout (INFRA) and a dedicated registered
worktree (TASK) immediately under the primary repository's .worktrees directory.
Preserve existing changes. One writer owns each task; the Reviewer is read-only.
The operator prepares grants; agents cannot grant themselves new paths.

One-time migration: run agy plugin disable layer-sort-agent-kit. Other global
plugins are unchanged. The launcher checks the kit is disabled and establishes
workspace trust for this session only; global CLI settings are never rewritten.

Example (replace task name and exact files with the requested work):

~~~sh
INFRA=/root/projects/layer-sort/.worktrees/agent-runtime-audit
TASK=/root/projects/layer-sort/.worktrees/TASK
git -C "$INFRA" worktree add -b task/TASK "$TASK" HEAD
node "$INFRA/tools/agent-guard/prepare-task.mjs" "$TASK" TASK-ID scripts/domain/move_rules.gd tests/g2/classic_rules_test.gd
bash "$INFRA/tools/agent-guard/safe-agy.sh" "$TASK" -- \
  --agent layer-sort-lead --output-format stream-json \
  -p 'Requirement, allowed paths, acceptance tests, independent review and handoff'
~~~

Start tasks from the reviewed infrastructure branch. For another game branch,
integrate the reviewed tooling into an isolated branch first; preserve owner
changes and do not reuse stale Hooks from historical worktrees. Bare agy in an
old checkout is not the supported entrypoint.

The worktree must contain the reviewed workspace Hook template. Preparation
validates exact relative files and existing parent directories; directories and
wildcards are not grants. It creates a private content-addressed snapshot under
the primary .git/agent-runtime-policy, never in version-controlled source.
The snapshot contains policy plus task ID, exact files, base HEAD, session ID,
and a 30-minute expiry. Only one active task pointer exists per worktree.
An open task must be explicitly closed before replacement.

The launcher derives CLI permissions and its post-check from that same snapshot,
uses accept-edits mode, and defaults to a 1200-second session limit (override
LS_SESSION_TIMEOUT up to 1800 seconds within remaining grant lifetime).
Task prompts, model, effort and output options are supported; authority-changing
flags and resume across task leases are rejected. New CLI versions require a
compatibility check before this version gate is updated.

Writes and partial edits use native write_file/edit_file with absolute Path.
Read-only inspection, scoped Git patch output, existing Godot headless scripts
under res://tests, and selected deterministic project tests pass the Hook.
Shell chaining, unrestricted interpreters, network commands, Git mutations,
protected paths and device mutation are outside normal agent authority.
To add a necessary test command, review a scoped policy change rather than give
blanket shell access. Executing project tests runs project code with the host
user's privileges: this is not an OS sandbox.

## Completion and recovery

The Lead must obtain implementation, actual test outputs and an explicit
independent review verdict before delivery. A CLI success or GUARD_OK alone is
not engineering acceptance. A timeout or unfinished specialist is BLOCKED.
Integration and committing the reviewed patch remain operator actions; merging
main requires the owner's exact authorization.

Every completed launch revokes its grant, including failure paths after lease
acceptance. To abandon a prepared task or recover after a process crash:

~~~sh
node "$INFRA/tools/agent-guard/runtime-config.mjs" close "$TASK"
~~~

Then inspect state and prepare a fresh task. Concurrent prepare is serialized by
a per-worktree lock. If preparation is forcibly killed, inspect the task pointer
and lock before manually clearing that stale lock; never race a live preparer.

Exit 2 detects scope/index/HEAD changes. Exit 3 means verification or startup
failed. Other nonzero agent exits propagate. Evidence directories are retained;
no automatic rollback discards work. Helpers are frozen before the session,
snapshots are checked before and after, and grant revocation precedes the final
state comparison. Keep private evidence out of commits and clean it deliberately.

The Hook prevents supported tool requests. The post-check detects persistent
Git-visible changes, including quoted names, modes, links, index and HEAD.
Neither prevents arbitrary same-user tampering, TOCTOU races, ignored-file writes,
transient reverted changes, or writes outside the inspected worktree. A manifest
proves consistency, not independent authenticity. Use OS isolation for untrusted
code; worktrees alone do not provide it.

## Verify

~~~sh
node --test tools/agent-guard/test-state.mjs tools/agent-guard/test-launcher.mjs
bash tools/agent-guard/test-guard.sh
LS_PROJECT_ROOT=/root/projects/layer-sort node .agents/plugins/layer-sort-agent-kit/scripts/test-policy.mjs
git diff --check
~~~

Tests use isolated disposable Git repositories and emulate the actual CLI
metadata/settings protocol. They never replace real Antigravity E2E acceptance.
Godot/Android CI and physical-device QA are separate gates. Device operations use
tools/device-tests/agentctl only, with exact authorization for mutations.

## Verified operating boundary

The actual CLI1.5.8 Lead/Implementer/Reviewer cycle passed with native partial
edits, focused tests, two negative controls and grant closure. See
docs/AGENT_RUNTIME_E2E.md. Local Godot import currently aborts even for a minimal
project; use verified CI for Godot validation until that environment fault is
resolved. Do not report a local Godot pass. Physical device QA remains blocked
by the approved-device identity mismatch. Sentry has no authenticated project
access in this session. These gates are explicit, not implied by GUARD_OK.
