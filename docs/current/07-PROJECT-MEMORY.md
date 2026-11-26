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
- The local candidate `codex/agent-inspect-20261125` initially added the
  read-only `agentctl inspect-installed` Hook rule and aligned instructions.
  Its first live run at `1bfcecb7323a25c0ac4ccce7278a0b805347f143`
  was BLOCKED by a missing headless command permission despite a nominal
  SUCCESS result with an empty response. Evidence:
  `.runtime/agent-evidence/device-read-20261125.jsonl` in that worktree.
  The later fix and successful retry are recorded below. The Hook does not
  permit installation or touch. A review snapshot is on GitHub at
  `codex/agent-inspect-review-20261125`; check its head live. Public review
  snapshots have matching file trees but do not reproduce local commit history.
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
CLI compatibility check passed with fingerprint
`7500523f4c78a7ec30a9b318af7ec48123eda8d8ee80a37325d37bf49c41dd0b`.

A real Gemini Flash Lead session then executed the exact read against the OPPO,
reported PASS and `installed: false`, and the guard reported no changed paths
and revoked the grant. Evidence is
`.runtime/agent-evidence/device-read-retry-20261125.jsonl` in that worktree.
The earlier attempt was auto-denied and remains preserved separately. This
proves only one read-only agent command, not install, touch, screenshot,
gameplay or other commands. Other Hook-approved reads may also require explicit
headless CLI permission and have not been tested.

### Phone test and visible artifacts — 2026-11-25

The owner approved the exact run/APK and a bounded phone session. Operator
`agentctl install-build` passed; the installed APK SHA-256 matched the
approved build. The operator launched it, completed level 001 in 10 moves by
synthetic ADB taps, observed the win screen, and verified navigation to level
002. This was not agent-driven gameplay, a fast-touch benchmark, or a
multi-touch test. The owner-visible folder is `Download/LayerSort`, containing
`APKs`, `Screenshots`, `Reports`, a verified APK copy, seven phone
screenshots and a summary. Filtered logs had zero matching lines and cannot
prove the absence of all faults. Shizuku Next is reported active by the owner;
it was not used or independently verified in this session.

Local branch `codex/visible-evidence-20261125` adds automatic visible
copies for successful screenshot, filtered log and verified APK fetch operations,
with separate export status and verified SHA-256. At
`a505a4ca51b369a975f922a6d3ea96c0fc0136c1`, 49 device tests and 38
compatibility/runtime tests passed; full live Antigravity compatibility passed.
Real Lead agent sessions captured and exported a screenshot and filtered log
to the visible folder, both PASS; the filtered log had zero lines. Session
grants were revoked. A real verified APK was also exported by the operator;
the full agent fetch has not yet been proven.

Subsequent local commit `63ac2f895ca28ec9b21abe2f99f2b5d38d941bfe`
adds an agent-session permission for the Hook-validated fetch-build command.
Unit/policy checks and live compatibility passed. A real Lead agent session
downloaded and verified GitHub run 45617659282, then exported its APK to
`Download/LayerSort/APKs/apk-11d4450610d5-d99147d4a6ff.apk`. Actual tool
output and independent hashes confirm PASS and the expected SHA-256
`11d4450610d56d63eaf3522923a2140d469bc4fc67f1af4ece27d42541774d5c`.
The no-write task grant was revoked. Evidence is
`.runtime/agent-evidence/agent-apk-fetch-20261125.jsonl` in the candidate
worktree. The agent did not install or play the game. The review branch
`codex/visible-evidence-20261125` is not integrated into main.

### Device session planning — 2026-11-26

The owner requested continuing the agent work. A fresh read-only device
inspection found the approved OPPO CPH1937 with debug APK SHA-256
`11d4450610d56d63eaf3522923a2140d469bc4fc67f1af4ece27d42541774d5c`.
The original G5 worktree remains ahead eight commits with its modified and
untracked files preserved. PRs #19 and #28–#30 remain drafts and #27 is open.

Local branch `codex/device-session-plan-20261126`, commit
`1384db0ffcf44b8dd92a55028dffa99579aabccf`, adds an offline, review-only
session-plan validator and negative tests. It can hash a proposed exact
build/device/action plan and compare it with supplied observed facts; six unit
tests pass, including mismatches and strict JSON types. The caller must obtain
and authenticate the facts; passing a fabricated observation is not proof. It does not create a grant,
prove approval, prevent replay, connect the plan to the Hook, operate the phone,
or authorize the agent to install or play. A temporary two-step launch/screenshot
plan was validated solely for review; its expiry and current facts must be
rechecked before any later use. Next, implement and test trusted session grant
issuance and enforcement, then separately exercise an authorized real session.

### Session plan preconditions checked — 2026-11-26

A first operator-run, read-only precondition check failed at the GitHub artifact
API verification step (verification tool did not succeed); it did not reach
the device comparison. After GitHub and ADB responded again, a second
read-only check passed using the verified cached build, a pulled installed APK,
the approved device identity and 720x1600 screen. The reviewed plan hash was
`409e5c81fcd8bc7478f4555c96ca45858b334e3f520f9639cc3037d1ef10c008`;
installed APK hash matched the known build. This check did not mutate the phone,
issue any grant or prove an agent can run the actions. The review plan expires;
revalidate before any later use. Preserve both failed and successful results.

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
