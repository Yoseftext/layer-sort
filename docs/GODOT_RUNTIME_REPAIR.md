# Godot and agent runtime acceptance — 2026-11-20

This follow-up supersedes the earlier local-import blocker in AGENT_RUNTIME_AUDIT.md.
PR22 was merged externally before this follow-up. Work remains on the dedicated
repair/godot-prroot-runtime branch; no protected-main merge is authorized here.

## Confirmed cause

The official Godot4.7.2 Linux ARM64 binary is unchanged, SHA256
3fcb80f4fe794e3859360eb641d8c41d8ffe2c2e54ba1981e55a76851d5ed1f4.
It matches the binary extracted from the official release archive after checking
its published SHA512. Exact source commit: ed1daf0bf001b61586d9930840f2f1394092c079.

CameraLinux::_update_devices declares an uninitialized devices pointer, calls
scandir("/dev", &devices, ...), then unconditionally frees it even after failure.
On this host directory enumeration returns EACCES. Disassembly at the crash
return address0x814400 shows the preceding free call after the failed scandir.
CameraTexture construction enables camera monitoring; editor documentation
constructs resources, so even an empty project can trigger the defect.
The last documentation-generation log did not establish a documentation-thread bug.

References:
- https://github.com/godotengine/godot/blob/ed1daf0bf/modules/camera/camera_linux.cpp
- https://github.com/godotengine/godot/blob/ed1daf0bf/scene/resources/camera_texture.cpp
- https://github.com/godotengine/godot/blob/ed1daf0bf/editor/doc/editor_help.cpp

Unprotected minimal import reproduced signal11/SIGABRT, exit134. Disabling
accessibility or reducing worker threads did not remove the failure.

## Maintained local repair

The operator prepares reviewed C sources with tools/godot-runtime/prepare.mjs.
Private .git/agent-runtime-tools holds the frozen sources, compiler/build metadata,
compatibility library, compiled runner and pointer. The runner verifies engine
and library hashes before executing the original engine.

The library preserves actual return values and errno, normalizing only the failed
exact /dev output pointer to NULL for scandir and scandir64. Other paths and
successful scans are unchanged. Host access remains denied; no camera feed is
activated. No device permission, global loader, engine binary or gameplay setting
is changed. Invocation-local LD_PRELOAD can reach external importer descendants.
Refusing an existing preload prevents composition, not a library already loaded
before the runner's main function. This is not OS isolation.

This is a compatibility workaround, not an upstream engine rebuild. The preferred
source fix is supplied as upstream-camera-free.patch; git apply --check succeeds
against the exact official source. It moves free(devices) into the success branch.
Old untracked build/test drafts and their prior README were preserved privately
under .runtime/legacy-godot-runtime with source hashes, leaving one supported path.

## Stable Antigravity execution

The following paragraphs record the earlier 1.5.13 acceptance. In the integrated
launcher, the installed CLI is selected by default and checked by the dynamic
compatibility gate before a per-session copy is created. An operator can select
an alternative executable with `AGY_BIN`. Automatic CLI updates are disabled by
the operator and by the launcher. See `tools/agent-guard/README.md` for the
current workflow.

The installed CLI changed from1.5.10 to1.5.13 between discovery and launch. The
existing gate rejected it and revoked the grant. The launcher now freezes one
executable before inspection, verifies it before/after use and applies documented
AGY_CLI_DISABLE_AUTO_UPDATE=true only to the invocation. Global update settings
are untouched.

After real task acceptance, the operator approved exact CLI1.5.13 binary SHA256
235147bb0b58673c6c8d130baab9c220921607220b7b0164dda27dd5e1c97cff.
Normal launches use that private approved copy rather than chase global updates.
The pointer is backed up on replacement. Disposable copies are released only
when their verified approved source remains available; diagnostics/tamper evidence
are retained. These hashes establish consistency, not independent vendor signing.

The same private bin route exposes only godot. Existing Hook command grammar and
file grants remain active. Observed safe inspection forms git log -n3/-n 3,
bounded --max-count, which for the known toolchain and godot --version/--help are
supported; Git mutation and shell chaining remain outside ordinary task authority.

## Actual native engineering acceptance

Task GODOT-RUNTIME-REGRESSION, base287424e7b7d6a1fbb4b8531b562969b8b70aff84:
- Lead d754309a-f76e-4a8c-a6aa-014a33b68166 inspected and delegated.
- Implementer64951886-9449-4e0a-8b09-f50ef0ce11d4 created the typed test through
  native write_file and refined it with edit_file in the assigned worktree.
- Reviewer4e1d57c9-c9c4-4d1d-a7b5-71f7d287e82a inspected the patch and evidence:
  ACCEPT. A separate read-only source/evidence reviewer also accepted the patch.
- godot --headless --path . --script res://tests/runtime/godot_runtime_test.gd:
  exit0, GODOT_RUNTIME_TESTS PASS checks=9 failures=0 compatibility_active=true.
- godot --headless --path . --script res://tests/g2/classic_rules_test.gd:
  exit0, G2_RULE_TESTS status=PASS checks=1149 failures=0.
- git diff --check exited0. Final native status SUCCESS; wrapper exit0,
  GUARD_OK, one scoped changed path; task grant revoked.

Exact negative controls were denied:
~~~text
Write target '.runtime/out-of-scope.txt' is not explicitly allowlisted for task GODOT-RUNTIME-REGRESSION.
Git operation 'clean' is not on the read-only allowlist.
~~~

The new test exercises CameraTexture construction and a bounded1.2second survival
window without activating a feed. Its environment flag is useful tracing, not an
independent loaded-library attestation. The timer does not prove thread completion.
Only its comment and final newline were clarified after native review; final
integration runs cover current source. Native claims of no unknowns/risks are not
adopted; rollback of committed changes is a reviewed revert.

## Local verification

- Fresh-cache full project import with the maintained runner: exit0, no SCRIPT ERROR.
- Maintained runner: G2 rules1149, G3-A navigation58, G3-B progression28: PASS, exit0.
- node --test tools/agent-guard/test-state.mjs tools/agent-guard/test-launcher.mjs:
  22/22 PASS, including frozen CLI update races, approved-copy cleanup and PATH binding.
- node --test tools/godot-runtime/test-compat.mjs:3/3 PASS; both scan ABIs,
  denied /dev output, unchanged other-path failures, zero/multiple entries,
  conflicting preload and engine/library hash rejection.
- bash tools/agent-guard/test-guard.sh:9/9 PASS.
- Source policy suite: POLICY_TESTS_PASS, exit0. git diff --check: exit0.

CI also runs the portable C compatibility tests and the Godot camera regression.
Current-head CI status and run links are reported in the review PR, separately
from native execution. Private transcripts/runtime binaries are not committed.

## Operation and remaining gates

Use tools/agent-guard/README.md and tools/godot-runtime/README.md. Preparation is
operator-owned; agents receive exact task grants in registered worktrees. For a
fresh Godot worktree, initialize import/class/UID metadata with the prepared runner
before opening the task lease. This avoids treating expected generated files as
unexpected task edits. Do not overwrite the owner's primary dirty checkout.

The owner explicitly approved permanent Node availability in Desktop Commander
on2026-11-20. Only node was removed from its blocklist (85 other entries remain);
existing directory limits were preserved. Native agent command permissions remain
separately governed by the project Hook.

Headless engine/development acceptance is distinct from graphical and device QA.
Cold import reported fallback to Android build-tools29.0.3 locally, whereas the
project lock pins36.1.0. Local APK export is NOT RUN and is not certified by import
success. CI uses its pinned toolchain. Physical installation, touch, screenshots,
logcat, thermal/performance and graphical editor verification are NOT RUN in this
follow-up. Authenticated Sentry access was not established here.

The core agent/Godot development workflow is ready with these explicit limits;
production/device release and protected-main integration remain separate gates.
