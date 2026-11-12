# Layer Sort Agent Kit

Workspace-scoped Antigravity customizations for the Layer Sort repository.

## Current components

- **1 primary agent:** `layer-sort-lead` (read-only coordinator)
- **6 read-only specialist subagents:** repository audit, dependency audit, engineering audit, device QA planning, visual QA, independent review
- **1 implementation specialist:** `implementer` (Worktree-scoped `write_file` plus Hook-filtered `run_command`)
- **7 on-demand skills:** project context, typed GDScript, Android/Godot QA, dependency compatibility, security review, visual QA, engineering quality
- **1 workspace-scoped PreToolUse guard:** `.agents/hooks.json` (the plugin's own `hooks.json` is intentionally empty to avoid duplicate hook execution)
- **0 MCP servers**
- **0 external package dependencies**
- **1 focused GitHub Actions workflow:** `.github/workflows/agent-policy.yml` (Node.js v22.23.4 via pinned setup-node v7.1.0; prepares trusted `rg`, device-wrapper, and metadata-only Godot/Antigravity test fixtures; read-only permissions, no secrets; runs on relevant pushes/PRs and manual dispatch)

## Execution model and write authority — 2026-11-11

### Workspace agent discovery

- Per [ADR-0008](../../../docs/adr/ADR-0008-antigravity-primary-agent-runtime.md), **Antigravity CLI (`1.5.5`)** is the sole primary agent runtime for Layer Sort; `.opencode/` is retained only as historical G1.5 evidence.
- All eight agents use the uniform directory layout `.agents/agents/<name>/agent.md` (including `.agents/agents/layer-sort-lead/agent.md`) and are mirrored under `.agents/plugins/layer-sort-agent-kit/agents/<name>/agent.md`. The Lead's `agents:` dependencies reference directory names, not `.md` filenames.
- On the installed Antigravity CLI 1.5.5, the main coordinator (`layer-sort-lead`) exposes workspace-scoped `view_file(AbsolutePath)`, `list_dir(DirectoryPath)`, `find_by_name(SearchDirectory)`, and `grep_search(SearchPath)`. Delegated OneHarness subagents use `read_file(Path)`, `write_file(Path, Content, Overwrite)`, and `edit_file(Path, Target/Replacement | Edits)`.
- The global plugin entry (`~/.gemini/config/plugins/layer-sort-agent-kit`) remains `disabled` and the plugin's own `hooks.json` is empty (`{}`) so that workspace `.agents/` and `.agents/hooks.json` serve as the single active discovery and PreToolUse Hook source without duplicate execution.

### Agent roles

- `layer-sort-lead` remains read-only: `commandExecutionPolicy: off`; no file-write or shell tool is exposed. It delegates and integrates only under the approved governance process.
- The six audit/review/device/visual specialists remain read-only. The independent Reviewer must not review its own implementation.
- `implementer` is the only persistent implementation specialist. It has `write_file` and `run_command`, `commandExecutionPolicy: auto`, and `inheritMcp: false`. Its tools do not include Remote Desktop Commander, raw ADB, Appium, or other device-control connectors.
- `run_command` is subject to an exact executable/argument allowlist. System tools must use pinned absolute paths such as `/usr/bin/git` and `/usr/bin/rg`; bare command names are denied to prevent `PATH` hijacking. `agy`, Python, Node, `env`, and Godot are not agent commands. Godot execution is deferred until the agent-system acceptance gates are complete.
- The installed CLI session is in `request-review` permission mode; `--mode auto` is unavailable for this account. A live `run_command` probe was denied by the CLI permission layer before PreToolUse, so autonomous agent command execution is **UNVERIFIED**, not PASS. Do not switch to `eager` or `--dangerously-skip-permissions`; command execution requires explicit owner approval or a separately approved permission configuration.

### Worktree write boundary

- The Hook conditionally allows Antigravity's confirmed `write_file(Path)` tool and verified partial-edit tools (`edit_file(Path)` for OneHarness subagents; `replace_file_content(TargetFile)` and `multi_replace_file_content(TargetFile)` for Cortex). For any write or partial edit, `workspacePaths` must contain **exactly one** canonical path, and that path must be the root of one registered Git Worktree directly nested under `/root/projects/layer-sort/.worktrees/`. The main checkout may be used for read-only inspection but can never authorize a Worktree write.
- A write target must be an absolute, normalized path below that exact active Worktree. Its POSIX-relative path must exactly match one entry in the maintainer-owned `WORKTREE_TASK_WRITE_ALLOWLISTS` registry inside protected `scripts/policy.mjs`. The registry is keyed by the Worktree directory name and carries a task ID plus an explicit array of relative file paths (`files: [...]`) so a single task grant can cover multiple files. No directory grants, recursive grants, or wildcards are supported.
- Partial-edit tools (`edit_file`, `replace_file_content`, `multi_replace_file_content`) additionally require the target regular file to already exist without symlink or hard-link aliases and validate the replacement payload structure.
- Missing, invalid, duplicate, or empty task policies deny every write. The persistent `agent-system-access` registry entry and the temporary `agent-write-e2e` verification Worktree have empty allowlists; no standing write grant exists. Completed task grants (such as `g5-p2-accessibility`) remain removed. A maintainer must register a new task's exact files before an implementation agent is launched. Required parent directories must already exist.
- Main-checkout writes, other-Worktree writes, external paths, `..`, redundant path segments, symlink traversal, hard-link aliases, `.git`, `AGENTS.md`, `.agents/**`, `tools/device-tests/**`, `docs/adr/**`, `docs/current/00-START-HERE.md`, `docs/current/04-AGENT-OPERATIONS.md`, `docs/current/05-QA-TEST-CATALOG.md`, secrets, environment files, signing material, directories, and unregistered directories are denied. These protected paths cannot be granted by a task allowlist.
- `write_to_file`, `apply_patch`, directory creation, move, copy, rename, append, and delete tools remain denied.
- Use one writer and one dedicated Worktree per bounded task; do not share a Worktree between implementation tasks. The Hook remains a policy barrier, not fine-grained OS isolation, and cannot eliminate time-of-check/time-of-use races.
- The current verification Worktree is `/root/projects/layer-sort/.worktrees/agent-write-e2e`, branch `test/agent-write-e2e`. Workspace `.agents/hooks.json` uses `/usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/bash --noprofile --norc plugins/layer-sort-agent-kit/scripts/policy.sh` relative to Antigravity CLI's workspace-hook working directory (`<workspace>/.agents`), with a shell-level deny fallback; it contains no checkout-specific absolute path. The clean environment is applied before Bash starts, preventing inherited `BASH_ENV`, exported shell functions, `NODE_OPTIONS`, and caller `PATH` from affecting the policy process. `policy.sh` resolves its physical path from the hook working directory and rejects symlinked path components. `policy.mjs` validates normal-checkout `.git` directories or linked-Worktree `.git` markers and derives the common repository root. The same config is intended for the main checkout, nested verification Worktrees, and CI checkouts. A live Antigravity CLI 1.5.5 session completed workspace `read_file` and `invoke_subagent` calls through the relative Hook; the installed CLI 1.5.6 subsequently completed a real `read_file` call. `.github/workflows/agent-policy.yml` now runs the policy suite on relevant pushes and pull requests, with manual dispatch, read-only `contents` permission, no secrets, a pinned checkout action, and Node.js v22.23.4 installed at the fixed `/usr/bin/node` path consumed by `policy.sh`; CI verifies root ownership and mode `0755`. GitHub Actions run `43175359522` passed on branch `test/agent-write-e2e` at commit `3d07385` on 2026-11-12, including the Agent Policy regression suite and Hook wrapper tests. This validates the hosted CI workflow only; autonomous `run_command` and hook-process spawn failure remain UNVERIFIED. The plugin's own `hooks.json` is empty. A Worktree is a separate Git working directory, not an OS security boundary.

### Hook and OS-isolation boundary

- Owner decision **Option B** is active: there is **no OS isolation**. The PreToolUse Hook is a policy barrier, not a Sandbox, container, or kernel security boundary. It does not contain a compromised process or replace operating-system permissions.
- Antigravity sessions for this project use the session-only setting `--settings '{"enableTerminalSandbox":false}'`. This does not change the persistent global CLI setting.
- Remote Desktop Commander file operations are project-scoped, but its generic shell command runner remains privileged and is **not** an OS sandbox. Agents use `inheritMcp: false` and must not inherit the ChatGPT Remote Desktop Commander connector.
- The installed CLI is Antigravity 1.5.6; ADR-0008 retains 1.5.5 as its approved baseline, and the 1.5.6 read Hook has been smoke-tested. The policy wrapper itself emits a deny for malformed input, missing policy/runtime files, non-zero execution, and its 5-second timeout. Antigravity's behavior when the Hook process itself cannot be spawned remains **UNVERIFIED**; empty Hook output is a no-decision, not a deny. Do not describe the Hook as an OS sandbox or as a substitute for OS isolation.
- Never use `--dangerously-skip-permissions`; repository-root `AGENTS.md` explicitly prohibits it.

### Current write-probe evidence and qualification

- The policy unit suite verifies exact per-task file grants, exact active-Worktree binding, empty/invalid policies, non-listed paths, prefix lookalikes, cross-Worktree denial, missing parents, protected paths, symlink/hard-link rejection, directory rejection, and inherited-`BASH_ENV` startup isolation. The latest `test-policy.sh` run returned `POLICY_TESTS_PASS` and `HOOK_WRAPPER_TESTS_PASS`.
- The earlier positive probe under `--dangerously-skip-permissions` remains historical evidence only and is **not** compliant acceptance evidence.
- **Current-revision negative E2E — PASS (2026-11-11):** Antigravity discovered `layer-sort-lead`, which delegated to `implementer`. The implementer read a disposable file inside `agent-write-e2e`, then its actual `write_file` call was rejected by the active PreToolUse Hook. Exact denial: `No valid maintainer-owned task write allowlist is registered for this Worktree.` The operator verified the file hash was unchanged and removed the probe. No bypass flag was used.
- **Current-revision positive E2E — PASS (2026-11-11):** in a separate disposable Git Worktree, the maintainer registered task `AGENT-WRITE-POSITIVE-E2E-20261111` for exactly one file, `docs/agent-ledger/.agent-write-allow-probe.txt`. The implementer created that file using `write_file`, then read it using `read_file`; both returned success and the exact payload `POSITIVE_WRITE_E2E_20261111` matched. The coordinator independently read the same value. The temporary registry entry was removed, the disposable Worktree was removed, and no persistent grant remains.
- **Current-revision multi-file write + partial-edit (`edit_file`) + out-of-scope denial E2E — PASS (2026-11-11):** under the Worktree-local Hook config (`agent-write-e2e/.agents/hooks.json`), the maintainer temporarily registered task `AGENT-MULTIFILE-EDIT-E2E-20261111` for three files (`docs/agent-ledger/.e2e-multi-1.txt`, `.e2e-multi-2.txt`, `.e2e-multi-3.txt`). Coordinator `layer-sort-lead` (`3231adb3-682d-4c5a-8793-0f47188a1d88`) delegated to `implementer` (`bb1215b2-e139-4558-924d-89ee449f27d8`), which in one task: (1) created `.e2e-multi-1.txt` (`MULTIFILE_WRITE_1_PASS`) via `write_file`; (2) created `.e2e-multi-2.txt` (`MULTIFILE_WRITE_2_PASS`) via `write_file`; (3) partially edited existing `.e2e-multi-3.txt` (`TARGET_TOKEN_ALPHA` → `PARTIAL_EDIT_3_PASS`) via `edit_file`; (4) attempted `write_file` on unlisted `.e2e-unlisted-4.txt`, which the PreToolUse Hook rejected verbatim (`Write target 'docs/agent-ledger/.e2e-unlisted-4.txt' is not explicitly allowlisted for task AGENT-MULTIFILE-EDIT-E2E-20261111.`); and (5) verified all three file contents via `read_file`. The temporary grant and probe files were then removed.
- The Lead's subagent handoff was corrected: a delivered `send_message` final report is treated as completion, avoiding repeated `manage_subagents` polling. The positive E2E completed successfully through the Lead and Implementer.
- Subsequent security hardening removed the unscoped `manage_task` process-control tool from the Lead and the Hook allowlist. The tracked `.agents/hooks.json` now uses a workspace-relative Hook command, launches Bash through `env -i` before startup, and includes a deny fallback instead of a checkout-specific absolute path. Unit assertions enforce the relative path, fallback behavior, and inherited-`BASH_ENV` isolation. Live Antigravity CLI 1.5.5 read/delegation calls and CLI 1.5.6 read plus negative-write E2E now pass through the corrected Hook; the CLI 1.5.6 hostile-`BASH_ENV` read test also passed without executing the marker. Autonomous `run_command`, hook-process spawn failure, and clean GitHub CI remain `UNVERIFIED`.
- The independent Reviewer returned a partial `BLOCK` finding for the temporary absolute Hook path. That finding was addressed, but the review hit a print timeout before a full post-fix verdict. The owner approved a one-time manual security review instead; it found and closed the inherited-`BASH_ENV` startup issue. This is not an independent Reviewer sign-off or merge authorization.
- **Command execution — UNVERIFIED:** a live `run_command` test was denied by the CLI's account-level `request-review` permission layer before PreToolUse. `--mode auto` was unavailable for this account. No command executed and no bypass was attempted. Policy unit tests still cover the command allowlist; do not claim autonomous command execution is E2E-verified.
- **Device status — UNVERIFIED:** the read-only `agentctl status` command did not identify the expected approved OPPO CPH1937 among the online ADB devices. No device mutation or Godot execution was performed.
- The active `agent-write-e2e` Worktree has no task write allowlist. `WORKTREE_TASK_WRITE_ALLOWLISTS` contains only the empty `agent-system-access` entry. No specialist has general or standing write authority.

## Device QA boundary

Use only `tools/device-tests/agentctl`. It is package-scoped to `com.yoseftext.layersort.dev`, shares the existing phone lock, and does not expose arbitrary shell, install, uninstall, clear-data, permission, settings, or service operations. Mutating actions require exact owner approval and are operator-executed; agents do not control the phone. ADB input is synthetic and measures in-game hit-testing, not physical touch accuracy.

Appium 3.8.0 and UiAutomator2 8.7.0 are **Evaluated / Not Approved**. Do not start or use Appium without a new owner decision.

## Why no MCP?

The project already has Git/GitHub CLI, Godot, GitHub Actions, ADB, and repository-owned QA scripts. No extra MCP server is required. Specialist agents set `inheritMcp: false` so unrelated global integrations do not leak into this workflow.

## Why no Flutter, Gradle, Docker, or extra scanners?

Layer Sort is a Godot Standard / typed GDScript Android game. Flutter/Dart, Docker/Podman, and unrelated cloud/data tools do not solve a demonstrated current requirement. Do not install them without a concrete requirement and a compatibility review.

## Environment baseline

Environment baseline verified 2026-11-10; agent-system revalidation performed 2026-11-11:

- Debian 13 / ARM64 / Android PRoot; Antigravity CLI 1.5.5
- OPPO CPH1937, Android 11 / API 30, product OP4B80L1
- Godot 4.7.2 Standard; Java 21.0.13; Antigravity CLI runtime Node 24.22.0; Hook runtime `/usr/bin/node` 20.19.2; Device QA runtime `/usr/bin/python3.13 -I` 3.13.5
- ADB 34.0.5; Appium 3.8.0; UiAutomator2 8.7.0
- Local Android SDK platform 30; local Build Tools differ from CI pins
- No Gradle, Flutter, Dart, Docker, or Podman

**Build distinction:** `ENGINE_VERSION.lock` specifies Android compile SDK 36 and Build Tools 36.1.0. The checked-in G3-B/G5 workflow runs on `ubuntu-24.04`, uses the pinned Linux `x86_64` Godot Standard archive, JDK 17.0.21+9, and pinned Android SDK packages. GitHub Actions remains the authoritative Android APK pipeline.

## Validation

Maintainer-only validation from the active Worktree root (these commands are not agent permissions):

```bash
/root/.local/bin/agy plugin validate --strict .agents/plugins/layer-sort-agent-kit
/usr/bin/bash .agents/plugins/layer-sort-agent-kit/scripts/test-policy.sh
/usr/bin/bash tools/device-tests/test-wrapper.sh
/usr/bin/git diff --check
```

Latest static verification on 2026-11-11: strict plugin validation **PASS** (8 agents, 7 skills, 1 rule, 0 plugin hooks); policy tests **PASS** (`POLICY_TESTS_PASS`, `HOOK_WRAPPER_TESTS_PASS`); Device Wrapper tests **PASS (22/22)**, including pinned interpreter and ADB path assertions; `git diff --check` **PASS**. Current-revision Antigravity E2E: agent discovery **PASS**, Lead-to-Implementer read delegation **PASS**, no-grant write denial **PASS**, exact-task single-file write plus read-back **PASS**. `run_command` E2E remains **UNVERIFIED** because the CLI permission layer denied the request before the Hook. Live `agentctl status` returned the literal state `UNKNOWN`; classify the device check as **UNVERIFIED** because the expected approved physical device was not identified. No device action was performed. Godot was not run. The new Agent Policy workflow also passed local YAML parsing and embedded Bash syntax checks; hosted GitHub Actions execution is still pending a push or pull request.

The kit remains workspace-scoped. Do not run `agy plugin install` or create a global plugin copy unless the owner explicitly requests it. Do not commit, push, merge, or integrate a specialist patch without the applicable owner authorization and independent review.
