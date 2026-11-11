---
name: godot-gdscript
description: Use when inspecting, editing, debugging, or testing Layer Sort Godot scenes, resources, runtime behavior, or typed GDScript.
---

# Godot and GDScript Workflow

- Read `ENGINE_VERSION.lock`, `project.godot`, and the relevant current engineering specification before changing code.
- Product engine is Godot 4 Standard with typed GDScript. Do not add C#, Mono, or .NET dependencies.
- Preserve Android portrait orientation, offline-first behavior, Compatibility renderer, current app identity, approved game rules, and save compatibility.
- Do not change engine version, export templates, Android identity, signing, target SDK, or build contract without an approved decision and a reviewed change.
- Follow existing project architecture and code patterns. Do not introduce a new framework or abstraction without a concrete need.
- Keep game-state transitions deterministic and separate from animation/audio presentation. Preserve undo/save invariants.
- During current agent-system completion, do not invoke Godot, import projects, run game tests, or operate the Android editor. Godot integration begins only after the owner explicitly accepts the core agent system.
- Inspect existing tests and workflow commands before choosing a test command. Never invent test names or assume an unverified script exists.
- Use local ARM64 checks only as supplemental evidence unless the exact local engine binary and export templates match the pinned toolchain.
- The authoritative Android build and pinned toolchain are in GitHub Actions. Do not attempt to run the CI x86_64 Godot archive directly in the ARM64 PRoot environment.

## Before reporting success

Report exact files changed, Godot version/binary provenance, test command and output, CI run/commit, and any unverified device behavior.
