# Antigravity task workflow

Antigravity CLI is the primary runtime. Runtime compatibility is determined by the fingerprint and compatibility gate in ADR-0008. Workspace agent definitions in
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

## Dynamic compatibility gate

The launcher does not pin a single Antigravity version. Before an agent session,
it fingerprints the absolute executable path, SHA-256, version, ELF Build ID,
interpreter and resolved shared-library hashes, host runtime, launcher, Hook,
policy, agent definitions and compatibility tests. Project documentation, skill
text and this guide do not change the compatibility key. The cache is refreshed
when Antigravity, the agent definitions, or the guard and test code changes.

The compatibility cache and audit log live outside Git at
`~/.local/state/safe-agy/` (or `$XDG_STATE_HOME/safe-agy/`). The directory is
0700 and state files are 0600. The cache retains the latest five successful
fingerprints. Cache writes use atomic rename; checks use flock with a bounded
mkdir fallback. JSONL audit events include cache hits, pass/fail, hash mismatch,
execution and recognized soft warnings. This is a same-user application-level
boundary, not OS isolation.

Use `bash tools/agent-guard/safe-agy.sh --status` for a read-only status report
and `bash tools/agent-guard/safe-agy.sh --check` to force the complete test
suite. A cache miss runs unit tests plus active probes in a disposable
Git worktree using the real Antigravity CLI. The probe discovers a Gemini model
from `agy models`, preferring Flash with low effort. If that model reports quota
exhaustion before using any tool or changing the fixture, the probe retries once
with another available Gemini model. Model discovery failure blocks the probe.
This applies only to the compatibility probe. Normal tasks use the model chosen
by the user, and project subagents inherit that model. Four separate implementer
delegations test the exact allowlisted write, out-of-scope write, external
state-store write, and prohibited Node command. A separate read-only Reviewer
must inspect the resulting file and return ACCEPT. The harness verifies actual
tool arguments and results from structured subagent transcripts, not only the
Lead's summary. A new fingerprint is approved only when all probes pass and
Git-visible changes match the exact grant. Timeout, missing evidence or unsupported host
returns UNKNOWN; a proven unauthorized write is a hard failure.

Recognized deprecation and host warnings are reported as soft warnings only
when all required probes pass and their exact contextual evidence is present.
The prompt-truncation warning is accepted for the exact Flutter/Firebase
manifest paths and message after successful delegation, even when its source line
changes. The known fallback to the default Gemini directory, canceled analytics
requests, and the configuration-service timeout fallback are recorded when
delegation succeeds. Startup auth-cache warnings
and exact `errorreport.go:307` token-source / `Failed to poll ListExperiments`
errors are accepted only when they precede explicit OAuth success and a
successful model-stream request is recorded. `admin controls not applicable` is accepted
only for a verified consumer account with no quota project. The missing
`/usr/bin/cs` helper, PRoot background-updater skip, two named optional global
MCP servers with missing executables, and exact Markdown-agent discovery
fallback are recorded as limitations only under their tested host/project
conditions. The project must declare no MCP servers before optional global
MCP failures can be soft. Go warning and error severity lines are both
captured; unknown signatures, changed logger/source paths, unresolved auth,
enterprise/unknown admin-control context, or failed probes remain UNKNOWN.
These rules do not suppress arbitrary warnings. The evidence stores auth
booleans, not account identifiers. Failure evidence stores transcript hashes
and a redacted, bounded warning summary; it does not persist the combined raw
debug transcript, account email, bearer token, or API key. The structured
JSONL subagent stream is retained separately only for tool-result verification
under the private state directory with mode 0600. The launcher sets
`AGY_CLI_DISABLE_AUTO_UPDATE=true` for its session. Antigravity CLI updates are
manual; use `agy update` when desired, then allow the compatibility gate to
verify the new executable before launch. Security-hook failures, fingerprint
mismatches, unexpected writes and incomplete evidence never become soft
warnings. The launcher uses a verified open file descriptor for the final Antigravity exec
(`/proc/self/fd/3`); this closes the pathname replacement window between the
final hash and exec, but cannot prevent in-place mutation by the same OS user.
It rejects every non-empty `LD_*` variable and Node/Bash startup overrides
(`NODE_OPTIONS`, `NODE_PATH`, `BASH_ENV`). After the active compatibility
suite passes, it recomputes the full executable, dependency, policy, test and
host fingerprint; any mid-test change prevents cache approval. Frozen launcher
helpers and test snapshots are also compared byte-for-byte with their reviewed
source files before and after compatibility evaluation.

Example (run from the reviewed infrastructure checkout; replace the task name and exact files with the requested work):

~~~sh
INFRA="$(git rev-parse --show-toplevel)"
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
flags and resume across task leases are rejected. A changed CLI executable, dependency, host, launcher, policy, or test fingerprint requires a compatibility check under ADR-0008 before agent execution. The version string is recorded as metadata, not used as a standalone allowlist.

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
Neither prevents arbitrary same-user tampering, in-place executable mutation,
ignored-file writes, transient reverted changes, or writes outside the inspected
worktree. Descriptor-based launch narrows pathname TOCTOU but is not an OS
sandbox. A manifest proves consistency, not independent authenticity. Use OS
isolation for untrusted code; worktrees alone do not provide it.

## Verify

~~~sh
bash tools/agent-guard/test-compatibility.sh --regression
bash tools/agent-guard/test-guard.sh
LS_PROJECT_ROOT=/root/projects/layer-sort bash .agents/plugins/layer-sort-agent-kit/scripts/test-policy.sh
bash tools/agent-guard/safe-agy.sh --status
git diff --check
~~~

Unit tests use isolated disposable repositories. The forced compatibility
check also runs active negative probes against the real Antigravity CLI in a
disposable registered Git worktree; mocks alone never approve a fingerprint.
Godot/Android CI and physical-device QA are separate gates. Device operations use
tools/device-tests/agentctl only, with exact authorization for mutations.

## Verified operating boundary

The actual CLI1.5.13 Lead/Implementer/Reviewer Godot cycle passed with native partial
edits, focused tests, two negative controls and grant closure. See
docs/GODOT_RUNTIME_REPAIR.md (the earlier cycle is in docs/AGENT_RUNTIME_E2E.md). The maintained local runner now passes cold project import and actual Godot
regressions while preserving denied /dev access. Use the prepared runner; the
original binary still contains the upstream camera-scan bug. Physical device QA remains blocked
by the approved-device identity mismatch. Sentry has no authenticated project
access in this session. These gates are explicit, not implied by GUARD_OK.

## Stable executable selection

The launcher checks compatibility of the installed CLI and freezes a verified
copy for each session. It disables automatic updates for that invocation and
checks the frozen executable before and after the agent runs. The installed CLI
is selected by default. An operator can explicitly set AGY_BIN to an alternate
reviewed executable; it must pass the same compatibility check. The launcher
removes an unchanged disposable copy on exit and retains changed copies for
inspection. Session metadata identifies the exact executable; an agent command
agy --version may resolve the global installation.

For a fresh Godot task worktree, run a headless import through the returned
private Godot runner before registering the task lease. This initializes class
caches and UID/import metadata before scope snapshots. See
[Godot runtime instructions](../godot-runtime/README.md).
