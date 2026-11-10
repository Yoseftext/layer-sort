# Layer Sort Agent Kit

Workspace-scoped Antigravity customizations for the Layer Sort repository.

## Current components

- **1 primary agent:** `layer-sort-lead` (read-only coordinator)
- **6 read-only specialist subagents:** repository audit, dependency audit, engineering audit, device QA planning, visual QA, independent review
- **1 implementation specialist:** `implementer` (Worktree-scoped `write_file` plus Hook-filtered `run_command`)
- **7 on-demand skills:** project context, typed GDScript, Android/Godot QA, dependency compatibility, security review, visual QA, engineering quality
- **1 plugin-scoped PreToolUse guard:** `.agents/plugins/layer-sort-agent-kit/hooks.json`
- **0 MCP servers**
- **0 external package dependencies**

## Execution model and write authority — 2026-11-10

### Agent roles

- `layer-sort-lead` remains read-only: `commandExecutionPolicy: off`; no file-write or shell tool is exposed. It delegates and integrates only under the approved governance process.
- The six audit/review/device/visual specialists remain read-only. The independent Reviewer must not review its own implementation.
- `implementer` is the only persistent implementation specialist. It has `write_file` and `run_command`, `commandExecutionPolicy: auto`, and `inheritMcp: false`. Its tools do not include Remote Desktop Commander, raw ADB, Appium, or other device-control connectors.
- `run_command` is still subject to the project's executable/argument allowlist in the Hook. A normal-permission Antigravity E2E verified the allowed `git status --short --branch` positive control; path-qualified executable denial is separately verified.

### Worktree write boundary

- The Hook conditionally allows only Antigravity's confirmed `write_file(Path)` tool. For a write, `workspacePaths` must contain **exactly one** canonical path, and that path must be the root of one registered Git Worktree directly nested under `/root/projects/layer-sort/.worktrees/`. The main checkout may be used for read-only inspection but can never authorize a Worktree write.
- A write target must be an absolute, normalized path below that exact active Worktree. Its POSIX-relative path must exactly match one entry in the maintainer-owned `WORKTREE_TASK_WRITE_ALLOWLISTS` registry inside protected `scripts/policy.mjs`. The registry is keyed by the Worktree directory name and carries a task ID plus exact file paths. No directory grants, recursive grants, or wildcards are supported.
- Missing, invalid, duplicate, or empty task policies deny every write. The active `agent-system-access` Worktree intentionally has an empty allowlist; the `implementer` profile exposes `write_file`, but its writes are currently denied. A maintainer must register a new task's exact files before an implementation agent is launched. Required parent directories must already exist.
- Main-checkout writes, other-Worktree writes, external paths, `..`, redundant path segments, symlink traversal, hard-link aliases, `.git`, `.agents`, secrets, environment files, signing material, directories, and unregistered directories are denied.
- `write_to_file`, `edit_file`, `replace_file_content`, `multi_replace_file_content`, `apply_patch`, directory creation, move, copy, rename, append, and delete tools remain denied until their exact schemas and policies are separately reviewed.
- Use one writer and one dedicated Worktree per bounded task; do not share a Worktree between implementation tasks. The Hook remains a policy barrier, not fine-grained OS isolation, and cannot eliminate time-of-check/time-of-use races.
- The current implementation Worktree is `/root/projects/layer-sort/.worktrees/agent-system-access`, branch `feat/agent-system-access`. `.worktrees/` is Git-ignored. The Worktree is a separate Git working directory, not an OS security boundary. The plugin-scoped `hooks.json` invokes `./scripts/policy.sh` relative to the plugin root. The workspace-level `.agents/hooks.json` invokes the policy wrapper through the absolute path in the dedicated `agent-system-access` infrastructure Worktree. A real Antigravity CLI 1.5.4 smoke test passed: the Lead invoked `implementer`, the allowed `git status --short --branch` completed with exit code 0, and the message was received (conversation `a31fb99d-c685-4a38-8b76-d837f1cf863a`). This avoids dependence on Antigravity's hook process working directory. Keep that infrastructure Worktree available until the policy wrapper is moved to a stable main-checkout path after the approved integration.

### Hook and OS-isolation boundary

- Owner decision **Option B** is active: there is **no OS isolation**. The PreToolUse Hook is a policy barrier, not a Sandbox, container, or kernel security boundary. It does not contain a compromised process or replace operating-system permissions.
- Antigravity sessions for this project use the session-only setting `--settings '{"enableTerminalSandbox":false}'`. This does not change the persistent global CLI setting.
- Remote Desktop Commander file operations are project-scoped, but its generic shell command runner remains privileged and is **not** an OS sandbox. Agents use `inheritMcp: false` and must not inherit the ChatGPT Remote Desktop Commander connector.
- Hook spawn-failure behavior remains **UNVERIFIED** on installed Antigravity CLI 1.5.4. Empty Hook output is a no-decision, not a deny. Do not describe the Hook as fail-closed or as a substitute for OS isolation.
- `run_command` accepts case-exact bare names from its command allowlist. Path-qualified executables are denied except the exact workspace-relative `tools/device-tests/agentctl` or its exact absolute path. The wrapper must be a regular executable file with no symlink or hard-link alias. This prevents an in-workspace file named `git` from inheriting the `git` allowlist. Bare-name resolution still relies on the trusted Antigravity process `PATH`; this Hook is not an OS-level executable sandbox.
- Never use `--dangerously-skip-permissions`; repository-root `AGENTS.md` explicitly prohibits it.

### Current write-probe evidence and qualification

- The policy unit suite now verifies exact per-task file grants, exact active-Worktree binding, empty/invalid policies, non-listed paths, prefix lookalikes, cross-Worktree denial, missing parents, protected paths, symlink/hard-link rejection, and directory rejection. `test-policy.sh` returns `POLICY_TESTS_PASS`.
- A real Antigravity delegation created `.runtime/implementer-write-probe.txt` inside the registered Worktree; the file was read back and its exact marker content matched.
- **Qualification:** that first positive E2E probe was launched with `--dangerously-skip-permissions`, contrary to root `AGENTS.md`. It proves the old broad Hook Worktree allow-path and file read-back only; it is **not** compliant acceptance evidence.
- **Normal-permission write E2E — PASS (2026-11-10):** `layer-sort-lead` delegated one probe to `implementer` in the dedicated `agent-write-e2e` Worktree. The CLI used explicit `permissions.allow` entries for `command(git status)` and the two exact marker paths; it did not use `--dangerously-skip-permissions`. `git status --short --branch` succeeded. With a temporary `AGENT-WRITE-E2E` policy granting only `.runtime/agent-write-e2e/allowed.txt`, the first `write_file` succeeded and read-back matched `AGENT_WRITE_E2E_ALLOWED_OK`; the second write to `denied.txt` was rejected by the Hook because that exact path was not allowlisted. Directory inspection confirmed `allowed.txt` exists and `denied.txt` does not. The temporary grant was reverted; the active `agent-system-access` allowlist remains empty. This closes the normal-permission positive/negative write E2E and the `git status` positive control for that test Worktree.
- **Executable-identity negative E2E — PASS (2026-11-10):** under normal permissions, `layer-sort-lead` delegated exactly one `run_command` attempt (`./git status --short`) to `implementer`. Antigravity's PreToolUse Hook denied it before shell execution with: `Path-qualified executables are blocked; only the exact project agentctl wrapper may be invoked by path.` No state changed. The positive control (`git status --short --branch`) succeeded in the normal-permission write E2E in the dedicated `agent-write-e2e` Worktree. This proves the tested bare Git command and exact write boundary only; it does not prove arbitrary commands or OS isolation.
- The earlier Hook E2E denials for main-checkout writes, `rg --pre`, and Git `--output` remain evidence for those exact tested calls. The old global denial of all `write_file` calls was superseded by the exact per-task Worktree policy; the current infrastructure Worktree's empty allowlist still denies every write.

## Device QA boundary

Use only `tools/device-tests/agentctl`. It is package-scoped to `com.yoseftext.layersort.dev`, shares the existing phone lock, and does not expose arbitrary shell, install, uninstall, clear-data, permission, settings, or service operations. Mutating actions require exact owner approval and are operator-executed; agents do not control the phone. ADB input is synthetic and measures in-game hit-testing, not physical touch accuracy.

Appium 3.8.0 and UiAutomator2 8.7.0 are **Evaluated / Not Approved**. Do not start or use Appium without a new owner decision.

## Why no MCP?

The project already has Git/GitHub CLI, Godot, GitHub Actions, ADB, and repository-owned QA scripts. No extra MCP server is required. Specialist agents set `inheritMcp: false` so unrelated global integrations do not leak into this workflow.

## Why no Flutter, Gradle, Docker, or extra scanners?

Layer Sort is a Godot Standard / typed GDScript Android game. Flutter/Dart, Docker/Podman, and unrelated cloud/data tools do not solve a demonstrated current requirement. Do not install them without a concrete requirement and a compatibility review.

## Environment baseline

Verified 2026-11-09:

- Debian 13 / ARM64 / Android PRoot
- OPPO CPH1937, Android 11 / API 30, product OP4B80L1
- Godot 4.7.2 Standard; Java 21.0.13; Node 24.22.0; Python 3.13.5
- ADB 34.0.5; Appium 3.8.0; UiAutomator2 8.7.0
- Local Android SDK platform 30; local Build Tools differ from CI pins
- No Gradle, Flutter, Dart, Docker, or Podman

**Build distinction:** `ENGINE_VERSION.lock` specifies Android compile SDK 36 and Build Tools 36.1.0. The checked-in G3-B/G5 workflow runs on `ubuntu-24.04`, uses the pinned Linux `x86_64` Godot Standard archive, JDK 17.0.21+9, and pinned Android SDK packages. GitHub Actions remains the authoritative Android APK pipeline.

## Validation

From the active Worktree root:

```bash
agy plugin validate --strict .agents/plugins/layer-sort-agent-kit
bash .agents/plugins/layer-sort-agent-kit/scripts/test-policy.sh
bash tools/device-tests/test-wrapper.sh
git diff --check
```

Latest active-Worktree verification on 2026-11-10: strict plugin validation **PASS** (8 agents, 7 skills, 1 Hook); policy tests **PASS** (`POLICY_TESTS_PASS`), including path-qualified executable alias denials and exact `agentctl` path checks; Device Wrapper tests **PASS (20/20)**; `git diff --check` **PASS**. A separate normal-permission Antigravity E2E verified one allowed `git status`, one exact allowlisted write, and one non-allowlisted write denied by the Hook. Independent Reviewer verdict for this infrastructure patch: **ACCEPT**, no blocking findings; one LOW review-prompt ADR path typo only. This is not merge authorization. These results do not validate product gameplay, bare-command `PATH` integrity, or Hook spawn-failure behavior.

The kit remains workspace-scoped. Do not run `agy plugin install` or create a global plugin copy unless the owner explicitly requests it. Do not commit, push, merge, or integrate a specialist patch without the applicable owner authorization and independent review.
