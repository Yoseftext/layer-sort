# Guard operation and current acceptance limits

The primary runtime remains Antigravity CLI. These scripts provide startup checks
and post-execution detection, not an operating-system sandbox. This repair does
not certify the complete agent workflow or physical-device QA.

## Authority and scope

- Agent definitions and policy source are version-controlled in the agent kit.
- The installed plugin's enabled PreToolUse Hook must point to one reviewed,
  frozen policy snapshot. The manifest proves consistency, not independent authenticity.
- The task registry in that pinned policy is the write authority. Editing another
  worktree's policy source does not update the running Hook.
- A task needs one registered nested Git worktree and exact file grants.
  The launcher's allowlist is an additional post-check and must match that grant.
  Automatic agreement checking and grant expiry are not implemented.
- In this repair worktree, workspace hooks.json is empty; the installed plugin
  owns enforcement. Other historical worktrees have not been migrated.
- Source, private runtime pins, session evidence and credentials are separate.
  Never commit private runtime state or credentials.

## Start a bounded task

1. Use a reviewed infrastructure checkout for the launcher. Do not start from
   an unreviewed task worktree containing an agent-modified verifier.
2. Inspect dirty/untracked changes and preserve them. Create a dedicated task
   worktree under the primary repository's .worktrees directory.
3. Have the maintainer register exact task paths in the policy, review/test it,
   deploy a new snapshot, verify its manifest, and wire the installed plugin to it.
   Preserve the previous snapshot/configuration for rollback.
4. Create an operator-owned file containing exactly one granted relative path per
   line. Do not include secrets, directories, globs, Git metadata or .agents paths.
5. Supply the actual pin explicitly when it differs from the legacy default:

```sh
SNAP_DIR=/absolute/path/to/reviewed/policy-snapshot \
  bash /trusted/infrastructure/tools/agent-guard/safe-agy.sh \
  /root/projects/layer-sort/.worktrees/TASK /operator/task-paths.txt -- \
  --agent layer-sort-lead --mode accept-edits --print-timeout 300s \
  --output-format stream-json -p 'Bounded task, paths and acceptance criteria'
```

Do not use --dangerously-skip-permissions. A successful CLI exit or GUARD_OK is
not task acceptance: inspect denied_actions, actual changes, tests and reviewer
evidence. Headless CLI 1.5.8 may end a Lead turn while a specialist is still active.
Check specialist completion before treating any post-check as final; unattended
headless lifecycle completion remains unverified.

## Verify

Operator commands (not blanket permissions granted to agents):

```sh
node --test tools/agent-guard/test-state.mjs tools/agent-guard/test-launcher.mjs
bash tools/agent-guard/test-guard.sh
LS_PROJECT_ROOT=/root/projects/layer-sort node .agents/plugins/layer-sort-agent-kit/scripts/test-policy.mjs
git diff --check
```

test-guard.sh requires the installed pin and plugin wiring to agree, or explicit
SNAP_DIR, INST_DIR and PLUGIN_HOOKS fixture settings as used in CI.

## Failure and recovery

Exit 2 means a detected scope/index/HEAD violation; exit 3 means startup,
collection or comparison could not be verified. Preserve evidence and inspect
the changes. No automatic rollback occurs. The agent's nonzero exit also
propagates even when scope checks finish.

The launcher freezes its helper and allowlist before execution. It detects
changed file contents, Git-visible mode changes, symlink targets, staged index entries and HEAD.
Control characters in filenames fail closed because the allowlist is line-based.
Ignored files, paths outside the task worktree, transient reverted changes,
same-user tampering and TOCTOU races remain outside this detector's guarantee.

Session snapshots and bounded test fixtures are retained for diagnosis. Review
and remove old evidence through ordinary operator housekeeping; do not publish it.
Restore backed-up plugin configuration if reverting a runtime deployment. Close
or revoke a temporary task grant after completion. Merge and device installation
remain separate owner-controlled gates.
