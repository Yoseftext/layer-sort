# Real Antigravity acceptance evidence

Task: BUFFER-SIZE-VALIDATION. Runtime: Antigravity1.5.8, Node24.22.0,
Linux ARM64 Debian/PRoot on Android. Base1dc84dd9fef76989e65f503da994b479635d5a6c.
Dedicated worktree: agent-native-e2e, branch repair/agent-native-e2e.
Native implementation commit6d8d2c6ce0a83b6cee74f8245615c7709f38c176;
integrated on repair/agent-runtime-audit as e6eb40cd67ea0248842758a57f25e4e6c65a556a.

## Actual engineering result — PASS

A zero-length buffer previously made hashFile return the empty SHA-256 digest
without reading the file. The native Implementer used edit_file partial edits
to reject invalid sizes before opening the file and added regression tests.
Only guard-state.mjs and test-state.mjs changed. No gameplay rules changed.

Lead0ab06160-8bb5-47ea-a00b-c9bdf1afbb05 inspected repository instructions,
HEAD and source, delegated to Implementer7bed3acf-3980-4b10-b15d-639cc705d835,
received implementation/test results, checked the actual diff and diff --check,
then sent the patch/evidence to independent Reviewer
a5c52061-f3ac-44fc-838d-2189c0d3b166. Native verdict ACCEPT.
A separate Codex reviewer inspected source hashes, actual patch, final output
and revocation marker and also returned scoped ACCEPT.

Actual command: node --test tools/agent-guard/test-state.mjs.
Exit0, tests8, passed8, failed0, duration8863.520465ms.
This covers quoted filenames, modes/index, symlinks, invalid repositories,
Hook structure, bounded hashing, invalid buffer sizes before file access,
and correct streaming with chunks1/7/64. git diff --check exited0.

Reviewed file SHA256:
- guard-state.mjs:0a4eb3c115272551e3b7cb9d5c4b81d0292ba37d3a19d6e241c66b6ca186ffbd
- test-state.mjs:4b420602f9f98bef3ef1c6bfc0aea17c49712d3ccbc48aca0601a0d500ab48f0

## Native security controls — PASS

The Implementer intentionally tried write_file to .runtime/negative-write.txt:
~~~text
Write target '.runtime/negative-write.txt' is not explicitly allowlisted for task BUFFER-SIZE-VALIDATION.
~~~
The file does not exist. The authorized edits to both task files succeeded.
The harmless negative command git clean -n was rejected:
~~~text
Git operation 'clean' is not on the read-only allowlist.
~~~
Neither rejection was bypassed. The final native result was SUCCESS,
agent exit0. The wrapper reported:
~~~text
GUARD_OK (agent exit 0, changed paths: 2)
~~~
The accepted grant was revoked at2026-11-13T21:38:46.852Z, independently checked.
Private transcripts remain outside version control; the ledger preserves a
scoped result summary and the private-stream hash for local reconciliation.

## Limits and recovery

An earlier session loaded an unsupported manage_inbox component; another timed
out after repeated status polling and redundant tests. Their failures and patch
are retained privately. The supported Lead now omits those polling tools, uses
native completion/message handling, reuses unchanged worker test evidence and
uses a focused test command. The final task completed in341.781636536seconds.
This is one authentic successful task, not a long-term reliability measurement.

GUARD_OK is a scoped detector result, not OS sandboxing. Same-user tampering,
TOCTOU, ignored/transient writes and outside-worktree activity remain limits.
No infinite loop or optimal-performance result was established. After commits,
rollback is a reviewed revert; do not use an unreviewed destructive reset.

Local Godot import currently aborts even on an empty project. The device wrapper
returns UNKNOWN because no connected device matches the approved OPPO identity.
Godot CI, APK provenance/signing, and physical installation/QA are separate gates.
