# Layer Sort Agent Kit

Workspace-scoped Antigravity customizations for the Layer Sort repository.

## Current components

- **1 primary agent:** `layer-sort-lead`
- **6 read-only specialist subagents:** repository audit, dependency audit, engineering audit, device QA planning, visual QA, independent review
- **7 on-demand skills:** project context, typed GDScript, Android/Godot QA, dependency compatibility, security review, visual QA, engineering quality
- **1 plugin-scoped PreToolUse guard:** `.agents/plugins/layer-sort-agent-kit/hooks.json`
- **0 MCP servers**
- **0 external package dependencies**

## Write authority — currently disabled

No agent currently receives file-write or file-edit tools. All specialist agents and the Lead are read-only. The PreToolUse guard uses an explicit tool allowlist: every unregistered tool is denied. It restricts `view_file` (`AbsolutePath`) and `read_file` (`Path`) plus `list_dir`/`find_by_name`/`grep_search` to the fixed workspace root, blocks secret-file reads, and denies unregistered tools and Remote Desktop Commander MCP tools. The engineering-auditor is recommendations-only; the independent Reviewer must assess its findings.

The Lead currently has no shell command tool. The PreToolUse guard retains a narrow executable-and-flag allowlist for a future, separately approved re-enable. Unknown executables and options are denied. `rg --pre*`, `sed` write/execute/in-place commands, `find` file-output/execute/delete predicates, Git `--output`, direct ADB/Appium, arbitrary interpreters, shell composition, path escape, secret-file reads, destructive commands, agent file writes, and RDC MCP calls are denied. The hook is policy enforcement, not an OS sandbox. Antigravity's handling of a PreToolUse executable that cannot be spawned remains UNVERIFIED on installed CLI 1.5.3; empty hook output is a no-decision, not a deny. Therefore all agents remain read-only, `commandExecutionPolicy` stays `off`, and no worktree or write authority is permitted until spawn-failure behavior is proven and terminal sandbox isolation is independently verified.

The owner approved Worktree + Patch for future specialist implementation. Write authority remains disabled until all prerequisites are verified: Remote Desktop Commander restrictions, the wrapper, a loaded command guard, a committed `.agents/`, confirmed terminal sandbox isolation, and a dedicated worktree. Each specialist will receive one disjoint path allowlist and return a patch. The Lead owns integration. Each patch must pass deterministic path/diff/test preflight, then independent Reviewer inspection. Integrate one patch at a time and run regression tests between patches.

## Device QA boundary

Use only `tools/device-tests/agentctl`. It is package-scoped to `com.yoseftext.layersort.dev`, shares the existing phone lock, and does not expose arbitrary shell, install, uninstall, clear-data, permission, settings, or service operations. Mutating actions require exact owner approval and are operator-executed; agents do not control the phone. ADB input is synthetic and measures in-game hit-testing, not physical touch accuracy.

Appium 3.8.0 and UiAutomator2 8.7.0 are installed but **Evaluated / Not Approved**. The Appium service was not running during the latest inventory. Do not start or use it.

## Remote Desktop Commander boundary

Remote Desktop Commander file operations are restricted to `/root/projects/layer-sort`. Its shell command runner remains privileged and is **not** an OS sandbox. All current agents use `inheritMcp: false`; they do not inherit the ChatGPT Remote Desktop Commander connector. The PreToolUse guard also denies Remote Desktop Commander tool calls if they are surfaced to an agent. The Antigravity sandboxed command probe failed before command execution with `fork/exec /root/.local/bin/agy: operation not permitted`; therefore every agent keeps `commandExecutionPolicy: off` and no shell/write tools. Treat these controls as layered policy, not OS isolation.

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

From the repository root:

```bash
agy plugin validate --strict .agents/plugins/layer-sort-agent-kit
bash .agents/plugins/layer-sort-agent-kit/scripts/test-policy.sh
bash tools/device-tests/test-wrapper.sh
```

The kit remains workspace-scoped. Do not run `agy plugin install` or create a global plugin copy unless the owner explicitly requests it.

No worktree has been created. `.agents/` must be committed before the first worktree.
