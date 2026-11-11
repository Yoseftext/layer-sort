# ADR-0008 — Antigravity CLI as Primary Agent Runtime and Multi-File Worktree Governance

- **Date:** 2026-11-11
- **Status:** Approved by owner 2026-11-11 (in test Worktree; no `main` merge authorized)
- **Scope:** Agent runtime, workspace discovery, Hook/Policy security boundary, and multi-file/partial-edit Worktree workflow. Does not alter gameplay scope, G5-Final P2 boundaries, or ADR-0007 merge rules.
- **Supersedes (in scope):** OpenCode V2 runtime selection in `ADR-0001` section 3.
- **Related:** `AGENTS.md`, `docs/current/00-START-HERE.md`, `docs/current/04-AGENT-OPERATIONS.md`, `.agents/plugins/layer-sort-agent-kit/README.md`.

## Context

`ADR-0001` originally selected OpenCode V2 (`.opencode/agents/`) for G1.5 agent orchestration. Subsequent November 2026 engineering work migrated agent execution to **Antigravity CLI (`1.5.5`)** under `.agents/` and `.agents/plugins/layer-sort-agent-kit/`, leaving conflicting runtime references in `AGENTS.md`, `00-START-HERE.md`, and `04-AGENT-OPERATIONS.md`. In addition, single-file write restrictions and missing partial-edit/search tools created operational friction for multi-file engineering tasks.

## Decision

1. **Primary Agent Runtime:** **Antigravity CLI (`1.5.5` pinned baseline)** is the sole active agent runtime for Layer Sort. `.opencode/` is retained strictly as historical G1.5 evidence and is not used for active agent execution.
2. **Single Workspace Discovery Source & Unified Agent Layout:**
   - All 8 agents (`layer-sort-lead`, `repo-auditor`, `dependency-auditor`, `device-qa`, `visual-auditor`, `engineering-auditor`, `reviewer`, `implementer`) use the uniform directory layout `agents/<name>/agent.md` inside `.agents/agents/` and mirrored in `.agents/plugins/layer-sort-agent-kit/agents/`.
   - Workspace `.agents/hooks.json` is the single active `PreToolUse` Hook entrypoint. Both `.agents/plugins/layer-sort-agent-kit/hooks.json` (`{}`) and any global plugin copy (`~/.gemini/config/plugins/layer-sort-agent-kit`, `enabled: false`) remain inactive to prevent duplicate Hook execution.
   - Inside a verification Worktree, `.agents/hooks.json` points to that Worktree's own `scripts/policy.sh` so pre-integration tests and Reviewer checks evaluate the candidate policy rather than unpatched `main`. Upon owner-authorized integration into the canonical root, `.agents/hooks.json` points to `/root/projects/layer-sort/.agents/plugins/layer-sort-agent-kit/scripts/policy.sh`.
3. **Multi-File Explicit Task Grants & Partial-Edit Tools:**
   - Adopt `One Task = One Worktree + One Explicit Multi-File Grant + One Patch + One Independent Review`.
   - `WORKTREE_TASK_WRITE_ALLOWLISTS` maps a registered Worktree directory name to a `taskId` and an explicit list of normalized POSIX relative file paths (`files: [...]`). Directory prefixes/wildcards (`allowed_prefixes`) remain deferred. Completed task grants (including `g5-p2-accessibility`) are not re-enabled.
   - Whole-file writing (`write_file(Path)`) and verified partial-edit tools (`edit_file(Path)` for OneHarness subagents; `replace_file_content(TargetFile)` and `multi_replace_file_content(TargetFile)` for Cortex) are permitted only inside the active registered Worktree for allowlisted files. Partial-edit tools additionally require the target regular file to exist prior to editing and validate replacement payload structure. `apply_patch` and `write_to_file` remain blocked.
4. **Workspace-Scoped Discovery & Deferred Command Gates:**
   - Restore workspace-scoped read/search tools (`list_dir(DirectoryPath)`, `find_by_name(SearchDirectory)`, `grep_search(SearchPath)`) alongside `view_file(AbsolutePath)` and `read_file(Path)`.
   - Retain hardened `evaluateGodot` (pinned `/usr/local/bin/godot`, mandatory `--headless --quit`, symlink-free `res://tests/` target) and `evaluateAgy` (pinned `/root/.local/bin/agy`, read-only inspection only) in `policy.mjs`, gated off by default (`enableGodot: false`, `enableAgy: false`) until the owner confirms core agent-system acceptance.

## Consequences

- Eliminates documentation drift between OpenCode and Antigravity CLI across governing specifications.
- Enables `implementer` to create and partially edit multiple explicitly allowlisted files in one task and one Worktree without per-file interactive prompts or broad directory exposure.
- Preserves Option B boundaries (PreToolUse policy barrier + Git Worktree + independent Reviewer; no OS sandbox claim) and ADR-0007 merge governance.
