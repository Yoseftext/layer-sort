# Layer Sort — project continuity record

Last checked: 2026-11-25. This is a working record, not a substitute for live
inspection, an approved ADR, or a grant to merge, install, or modify the phone.
It is currently on a local review branch; other branches do not automatically
receive it. A separate detailed session record exists in the owner's ChatGPT
Library as `Layer_Sort_Project_Memory.md`.

## Objective and owner's preferences

Build professional project-scoped agents that run inside Antigravity and
develop/test this Godot Android game: exact-source APK build, provenance,
install, launch, bounded touch and gameplay checks, screenshots, logs and
review. The agents should inherit the model selected in Antigravity. Avoid
unnecessary use of limited non-Gemini quota, never hardcode a single model, and
do not silently upgrade Antigravity or install global packages.

## Current evidence

- The original G5 worktree is on `feat/g5-p1-layer-circuit` at
  `c48e6185cb4534d6b9986154b7408f6703aa1cd5`, ahead of its remote by eight
  commits. It has a modified `tools/inventory.md` and seven untracked files
  under `tests/g5/` and `tools/content/`. They are intentionally excluded
  from the integration snapshot. Preserve them. A checked backup exists under
  `/root/backups/layer-sort-preserve-20261124-f5i1larr`.
- PR #19 remains draft/conflicting, #23–#26 were merged, and #27–#30 remain
  open or draft at the last check. Re-fetch their status before deciding.
- A local integration candidate on `codex/g5-apk-provenance-20261124` is at
  `18c17c0ec4acb7a007604dc7586f21327833a1ed`. Its tree is
  `9ae46e7981a714c65ea0947bb87313b1f0b1a1ff`. It is a local snapshot with one
  parent, not a completed merge of main and G5 history.
- Antigravity CLI 1.5.16 full compatibility check PASS on that exact local
  commit after requesting explicit reviewer evidence. Set
  `AGY_CLI_DISABLE_AUTO_UPDATE=true` for direct CLI calls. Earlier independent
  reviewer-message visibility was inconclusive; do not generalize the probe
  into proof of every reviewer or future CLI version.
- A separate public build-only snapshot
  `codex/g5-apk-build-20261125` at
  `9d63495d671c7d4e5e297c59416c53525b9f2784` has the same tree as the local
  candidate, but a different commit and main parent. It is not a G5 merge.
  GitHub Actions run 45617659282 succeeded:
  https://github.com/Yoseftext/layer-sort/actions/runs/45617659282 .
- The verified debug APK was downloaded for that exact run and build commit.
  SHA-256 `11d4450610d56d63eaf3522923a2140d469bc4fc67f1af4ece27d42541774d5c`;
  package `com.yoseftext.layersort.dev`; version code 5; expected signing
  certificate `de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e`.
  At the last physical-device read the package was absent on the approved
  OPPO CPH1937 / Android 11. This is not a successful install or gameplay run.
- A separate local candidate `codex/agent-inspect-20261125` at
  `1bfcecb7323a25c0ac4ccce7278a0b805347f143` permits the exact read-only
  `agentctl inspect-installed` command in the Hook and aligns instructions.
  At parent `0ec05f59a07539a0f8bfed0796a2742573a93509`, live CLI
  compatibility passed; the same compatibility fingerprint is cached on
  `1bfcecb`, whose skills are not in that fingerprint. Policy and 45 wrapper
  tests passed. The actual agent read is BLOCKED: CLI headless command
  permission was auto-denied, despite a nominal SUCCESS result with an empty
  response. The runtime settings lack the exact command allow-rule. Evidence:
  `.runtime/agent-evidence/device-read-20261125.jsonl` in that worktree.
  The Hook does not permit installation or touch. Review snapshot:
  `codex/agent-inspect-review-20261125` on GitHub at
  `120bd4a3d8ff5054c30da92c9015754162f2a3d2`, with the same source tree
  as the local candidate, not the same commit or history.
- Tool comparison and measurement plan:
  [ANDROID_AGENT_TOOL_RESEARCH.md](../qa/ANDROID_AGENT_TOOL_RESEARCH.md).
  The PR #29 touch planner and #30 visual matcher have not been validated as a
  real end-to-end touch/game screenshot run on this phone. Read-only CLI
  checks confirmed Appium 3.8.0 and UiAutomator2 driver 8.7.0; current Python
  cannot import appium or selenium, and no service/session was started.

### Headless command permission follow-up

Local commit `c4e862b4cec4be6dcef4329b1f07be13478e0806` adds only
`command(tools/device-tests/agentctl inspect-installed)` to session
permissions. Runtime-config tests 7/7 and policy tests passed, including
negative checks for unrestricted device commands and install. The full live
compatibility check is in progress; repeat the actual agent read afterward.
Do not interpret the previous denied command or mocked tests as a successful
agent-operated phone check.

## Next tasks

1. Check current branch/worktree, GitHub runs/PRs, phone identity and package
   state. Do not overwrite, stage, stash, clean, or reset the owner's local work.
2. Finish checking the read-only agent change on the actual CLI and verify an
   agent can observe a result. Label inaccessible or inconclusive evidence
   UNKNOWN.
3. Prepare a concrete phone session for the exact APK/run/device. Follow the
   applicable exact authorization rules, use the existing phone lock, and
   re-verify before mutation. Installation, launch, touch, game-state checks,
   screenshots and logs are separate evidence stages; stop on uncertainty.
4. Compare existing ADB against reviewed Appium/multitouch candidates on the
   same bounded scenarios, then test real screenshot matching. Never claim
   physical-touch sensor accuracy from synthetic input or mock fixtures.
5. Review and integrate changes incrementally. The exact PR/head/target merge
   contract in `AGENTS.md` and ADR-0007 remains controlling.

## Update after every task

Append or revise the record with date, goal, exact source/branch/commit, changed
files, PASS/FAIL/SKIP/UNKNOWN evidence and links, limitations, device/build state,
next action and any explicit decision needed. Cross-check the separate detailed
session record when available. Never record secrets or private user content.
A document can guide future agents to update it, but cannot guarantee that an
unrelated future session has loaded or updated it; verify its date and contents.
