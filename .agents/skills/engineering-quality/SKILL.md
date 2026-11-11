---
name: engineering-quality
description: Use for Layer Sort implementation planning, root-cause debugging, architecture decisions, code changes, performance analysis, and independent engineering review.
---

# Layer Sort Engineering Quality Protocol

## 1. Establish truth before action
- Read root `AGENTS.md`, `docs/current/00-START-HERE.md`, this plugin's rules, and the latest applicable approved ADR.
- Inspect live Git state and the exact files/tests relevant to the task. Do not treat old chat summaries, archived docs, or stale gate paragraphs as current authorization.
- Separate verified facts from hypotheses and unknowns. Attach file paths, line references, command output, or official documentation to material claims.

## 2. Root-cause analysis
- Reproduce the defect or establish a minimal failing case before changing code when practical.
- Trace the causal path across input, domain state, application orchestration, presentation, persistence, and platform boundaries.
- Explain why the failure occurs. Reject symptom-only patches and unrelated refactors.
- If evidence is insufficient, return `UNVERIFIED` and state the smallest next diagnostic step.

## 3. Architecture and implementation
- Preserve Godot 4 Standard, strict typed GDScript, Android portrait, offline-first, Compatibility renderer, and approved game rules.
- Keep domain rules deterministic and independent of scenes, animation, audio, device APIs, and network services.
- Preserve atomic state transitions, undo/save invariants, level-content compatibility, and the existing save schema.
- Follow existing project patterns. Introduce an abstraction only when it removes a demonstrated source of coupling or duplication.
- Keep changes small, scoped, reversible, and reviewable. One concern per change set.

## 4. Security, reliability, and performance
- Validate level/content/configuration data at boundaries; reject malformed, out-of-range, unsupported, or oversized values safely.
- Protect user data and credentials. No secrets in source, logs, prompts, screenshots, or reports.
- Check authorization, path scope, command safety, dependency provenance, and network exposure before adding integrations.
- Check race conditions, duplicate input/commit, stale async results, cancellation, resource cleanup, and lifecycle handling.
- Avoid per-frame allocations and repeated scene-tree searches in hot paths. Do not claim FPS or memory improvements without measurements.
- Bound loops, waits, retries, output sizes, and test duration. Retry only transient operations that are safe to repeat.

## 5. Verification
- Inspect the existing test catalog, test source, and CI workflow before selecting commands.
- Run the narrowest relevant tests first, then required regression checks. Include negative tests for important rejection paths.
- Distinguish headless/unit tests, CI builds, local ARM64 checks, physical-device tests, and owner-reported evidence.
- `run_command` may be subject to CLI-level `request-review`. If permission review denies a command before PreToolUse, mark command execution `UNVERIFIED`; never switch to `eager` or `--dangerously-skip-permissions`.
- Use only `PASS`, `FAIL`, `SKIP`, or `UNVERIFIED`; a successful command is not proof of unrelated behavior.
- Never install tools, run phone mutations, change services, or merge/publish without the required explicit authorization.

## 6. Agent coordination
- Use specialists only when their independent evidence can change the decision. For complex tasks, prefer a small parallel group over a large agent swarm.
- Give every worker an objective, allowed paths/actions, read/write authority, acceptance criteria, and required output.
- Keep one writer per file set. Auditors and reviewers remain read-only.
- The reviewer must inspect the actual diff, test evidence, project authority, security risks, and rollback independently.

## Required result
Report: decision; root cause or reason not established; scope; changed paths; exact tests and statuses; evidence; security/performance risks; unverified items; rollback. Do not claim completion beyond the evidence.
