---
name: layer-sort-context
description: Load Layer Sort's controlling documents, current owner-authorized scope, Git safety rules, and project architecture before any repository task.
---

# Layer Sort Context

Before any task:

1. Read repository-root `AGENTS.md`.
2. Read `docs/current/00-START-HERE.md`.
3. Read only the relevant sections of `docs/current/01-UX-ART.md`, `02-ENGINEERING.md`, `03-PRODUCTION.md`, `04-AGENT-OPERATIONS.md`, and `05-QA-TEST-CATALOG.md`.
4. Read the latest applicable approved ADR when a decision is involved.
5. Check the live branch, HEAD, worktree, and active PR. Historical notes do not establish live state.

## Authority

- Root `AGENTS.md` defines operating constraints.
- `docs/current/00-START-HERE.md` is the active project entry point.
- The latest owner-approved ADR controls decisions within its scope.
- Other active specifications conform to those sources.
- Archive documents and dated reports are historical evidence.

Do not silently reconcile conflicts. Report them and stop if authority is ambiguous.

## Known drift

At kit creation, root `README.md` still describes the older PR15 checkpoint, while root `AGENTS.md` and `docs/current/00-START-HERE.md` describe G5-Final P2 and Draft PR19. The ADR-0006 reconciliation paragraphs in `docs/current/04-AGENT-OPERATIONS.md` and `05-QA-TEST-CATALOG.md` are also stale relative to the current entry point. Do not use those stale paragraphs as current authorization and do not rewrite them without a separate task.

## Scope discipline

The current owner request explicitly defers Godot. Do not execute Godot, run puzzle-validator, or begin G5 gameplay work until the owner accepts the core agent system.

The current game-code authorization recorded in root `AGENTS.md` is the bounded G5-Final P2 HUD/board/Circuit presentation/original-audio slice. It does not authorize a merge, main modification, G6, production release, menu/map redesign, external assets, new dependencies, signing changes, or device-service changes.

A request to configure this workspace agent kit does not authorize unrelated game-code or CI changes.
