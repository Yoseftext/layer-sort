# ADR-0009 — Godot PRoot runtime compatibility launcher

Date: 2026-11-14. Owner: Layer Sort repository owner, explicit approval in the 2026-11-14 engineering handoff and follow-up. Status: OWNER APPROVED FOR IMPLEMENTATION AND REVIEW; no PR merge, device installation, or release authorization is granted.

## Context

Godot `4.7.2.stable.official.ed1daf0bf` aborts in the current Android PRoot environment when Linux camera discovery calls `scandir("/dev", ...)`, receives `EACCES`, and leaves an output pointer that is later freed. The failure reproduces with an empty Godot project and is an environment/runtime compatibility defect, not a Layer Sort gameplay defect.

A narrowly scoped C compatibility shim was tested to normalize the output pointer to `NULL` only when `scandir("/dev", ...)` or `scandir64("/dev", ...)` fails, while preserving the original error. The temporary tests allowed empty-project and Layer Sort imports to complete.

## Decision

Complete the project-local launcher in the dedicated Worktree `/root/projects/layer-sort/.worktrees/godot-runtime-repair`, branch `repair/godot-prroot-runtime`, based on PR #22 head `b89bbe6d4b3f2d0a63aa56f7ba27e023f2092c1d`. The launcher must:
- pin the exact tested Godot version and SHA-256;
- build its runner and compatibility library only into the ignored project-local `.runtime/godot-runtime/` directory;
- verify the Godot executable and guard-library hashes before launch;
- reject an unexpected inherited `LD_PRELOAD` and set the expected preload only for the child Godot process;
- alter behavior only for failed scans of the exact `/dev` path, preserving `errno` and all other paths;
- leave `/usr/local/bin/godot`, Android permissions, `/etc/ld.so.preload`, global loader configuration, and system libraries unchanged;
- document usage, host requirements, known limitations, and rollback.

The shared `.runtime` parent must never be chmod'ed. Only the dedicated runtime directory and files may receive restrictive permissions. Build and test scripts must use fixed absolute tool paths where required, validate compiler flags and definitions, and fail closed on missing prerequisites.

## Security boundary

The shim is a PRoot compatibility workaround, **not an OS sandbox** and not a general security boundary. It does not grant access to `/dev`, bypass Android permissions, or make untrusted code safe. The launcher is local to the repository and must not modify system-wide loader configuration. The original Godot binary remains the rollback path.

## Acceptance evidence

The task is not closed until an independent Reviewer accepts the exact patch and verifies:
- C harness tests for both `scandir` and `scandir64`, error preservation, and unchanged behavior for unrelated paths;
- clean build and runtime test scripts;
- exact Godot and shim hash verification, including rejection of unexpected `LD_PRELOAD`;
- empty-project import and Layer Sort import through the wrapper;
- relevant G2 and G5 regression suites with exact counts and exit codes;
- no changes to the original Godot binary or global loader state;
- patch contains only the intended `tools/godot-runtime/` files, excluding generated Godot `.uid`/`.import` artifacts;
- clear rollback instructions.

The previously recorded local evidence (G2 1149/1149 and G5 28/28, both with zero failures; import exit 0) is implementation evidence, not a substitute for the independent review. Android export, APK installation, touch, screenshots, logcat, thermal/performance QA, and physical-device acceptance are separate future gates and remain unrun/not authorized by this ADR.

## Scope and integration

This ADR authorizes only completion, testing, documentation, and independent review of the local Godot runtime launcher. It does not authorize Device QA Identity (P1), APK installation, phone mutation, gameplay changes, global system changes, commit, push, PR merge, or release. Protected-main integration remains governed by ADR-0007 and requires exact owner authorization for a specific PR/head/target.
