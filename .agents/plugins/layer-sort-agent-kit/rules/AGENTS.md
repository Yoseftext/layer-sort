# Layer Sort — Always-on Agent Rules

## Source of truth

Before acting, read the repository-root `AGENTS.md` and `docs/current/00-START-HERE.md`.

- Root `AGENTS.md` defines operating constraints.
- `docs/current/00-START-HERE.md` is the active project entry point.
- The latest owner-approved ADR controls decisions within its stated scope.
- Other active specifications must conform to those sources.
- `docs/archive/` and dated reports are historical evidence, not current authorization.

Do not resolve conflicts silently. Report the conflicting files, controlling source, and impact. Ask the owner when authority is ambiguous.

Known documentation drift at kit creation:
- Root `README.md` still describes the older PR15 checkpoint.
- `docs/current/04-AGENT-OPERATIONS.md` and `docs/current/05-QA-TEST-CATALOG.md` contain an older ADR-0006 gate-reconciliation paragraph that conflicts with the current G5-Final state in root `AGENTS.md` and `docs/current/00-START-HERE.md`.
- Do not silently rewrite these documents as part of an unrelated task.

## Project constraints

- Product: Android portrait-only, offline-first puzzle game.
- Engine: Godot 4 Standard and typed GDScript. No C# / Mono in the product.
- Preserve the pinned engine/export contract in `ENGINE_VERSION.lock`.
- Do not change game rules, levels, saves, package identity, signing, export settings, or approved UX outside the explicit task scope.
- Never open, copy, or derive implementation/assets from the GPLv3 reference project.
- Do not add billing, paid APIs, Firebase billing, ads, IAP, production signing, or new credentials.

## Git and change control

- Never push directly to `main`.
- Never force-push, rewrite history, delete branches/tags, bypass protections, or merge a PR without exact owner authorization under ADR-0007.
- A general “go ahead” is not merge authorization. Exact merge authorization must identify the PR number, full head SHA, target branch, and intended reviewed changes.
- Work on a dedicated branch or isolated worktree when implementation is authorized.
- Keep changes small and scoped. Do not stage unrelated or unknown files.
- Preserve all pre-existing untracked files. In particular, the owner reported an unverified untracked file named `t --left-right --count \`; do not delete, rename, overwrite, or stage it.
- Before and after any task, inspect `git status --short --branch` and report the branch, HEAD, and changed paths.

## Tools and environment

- Prefer tools already installed and the existing GitHub Actions pipeline.
- The local environment is Debian 13 ARM64 under Android PRoot. Do not assume x86_64 Linux binaries, Docker, Podman, Gradle, Flutter, or Dart will work or are needed.
- The project’s authoritative Android build runs in GitHub Actions on `ubuntu-24.04` with the versions pinned by `ENGINE_VERSION.lock` and the workflow.
- Do not install global packages, update Termux/Debian, modify Android services, or add MCP servers without a concrete requirement, upstream/license/architecture verification, a rollback plan, and owner approval.
- Never use `--dangerously-skip-permissions`.
- Do not expose tokens, keystore contents, passwords, private keys, or unrelated personal data in logs.

## Device QA

- Device QA is a separate, explicitly authorized activity.
- Use repository-owned QA wrappers and the existing `agentctl` / `phone-queue` lock. One phone-mutating session at a time.
- Never use raw ADB/Appium commands to change global settings, permissions, services, or other apps.
- Never uninstall the game or install an APK unless the owner explicitly authorizes that exact test and its APK provenance is verified.
- If the lock, runner, artifact provenance, or device state cannot be verified, report `SKIP` or `UNVERIFIED`; do not improvise.

## Evidence and reporting

Use only `PASS`, `FAIL`, `SKIP`, or `UNVERIFIED` for test states.

Never claim a build, test, fix, device result, screenshot review, or performance result without its actual log/artifact. Distinguish:
- CI build/test evidence
- local ARM64 supplemental checks
- physical-device QA
- owner-reported QA
- qualitative owner design approval

For each completed task, report the branch, commit, changed paths, tests and exact status, CI run/PR links where applicable, APK hash/provenance where applicable, blockers, and rollback.

## Engineering quality and evidence protocol

- Start with root-cause analysis. Reproduce or isolate the failure before changing code when practical; do not patch symptoms.
- Separate verified facts, hypotheses, assumptions, and recommendations. Never invent tool names, API behavior, versions, test results, or evidence.
- Preserve the existing Godot Standard / typed GDScript architecture and approved game invariants. Do not introduce dependencies or frameworks without a demonstrated need and owner approval.
- Keep domain state deterministic and separate from scenes, animation, audio, and platform integrations. Protect undo/save and level-content compatibility.
- Review security, lifecycle, concurrency, stale async results, duplicate commits, memory/resource cleanup, and performance-sensitive paths.
- Bound commands, tests, waits, retries, agent count, and output. Retry only transient operations that are safe to repeat.
- Before editing, define the task scope, intended paths, writer, acceptance tests, risks, and rollback. Keep one writer per file set.
- Delegate only independent work. Specialists must receive explicit read/write authority and must not self-authorize device mutations or scope expansion.
- The independent reviewer inspects the actual diff and raw evidence, not the implementation summary. Resolve blocking findings before acceptance.
- Never call a result PASS without the exact successful command/log/artifact. Distinguish CI, local ARM64, physical-device, and owner-reported evidence.
- Final reports must include changed paths, branch/HEAD, exact test statuses, verified and unverified claims, risks, blockers, and rollback.
