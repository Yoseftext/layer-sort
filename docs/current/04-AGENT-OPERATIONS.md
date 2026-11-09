# Layer Sort — Agent Operations & Controlled Autonomy

**Document:** `docs/current/04-AGENT-OPERATIONS.md`  
**Identifier:** `LS-AGENT-OPS-1.4`  
**Status:** Active operating policy originating in G1.5; original gate authorization statements are historical scope, not current execution instructions.
**Current scope:** G4 documentation consistency review only, under ADR-0006 checkpoint acceptance and [ADR-0007](../adr/ADR-0007-protected-main-owner-authorized-agent-merge.md) governance; no individual merge is authorized by the current documentation instruction. **Historical G1.5 scope:** orchestration/tool inventory/QA and optional Shizuku; G2 was then awaiting separate authorization, subsequently recorded in ADR-0003.

## 1. Scope and source-of-truth

1. Preserve all existing design decisions: Godot 4 Standard / typed GDScript / Android portrait / offline-first / Firebase Spark only, with Firebase integration later.
2. AGENTS defines agent operating constraints; [00-START-HERE.md](00-START-HERE.md) is the active project entry point. Approved, later owner-authorized ADRs control decisions within scope; other active specifications conform. Never resolve a conflict silently: record it and request an explicit owner decision if authority is unclear. Protected-main integration follows ADR-0007; no direct push or merge without exact owner authorization is permitted.
3. **Historical G1 scope:** its PR required owner approval; this is not a current G1 execution instruction. Protect `main`, `spike/godot-csharp-android`, git history, existing CI, and Termux/ADB/Appium infrastructure.
4. Treat the prior device report and screenshots as **G1 evidence**, not proof of game mechanics, UI beauty, or G2 readiness.
5. Never open the GPLv3 reference implementation, import its assets, or copy its code. Never contact paid APIs or enable billing.

## 2. Role architecture — use native OpenCode subagents

Create **project-scoped** agent definitions under `.opencode/agents/`, after discovering the installed OpenCode version and validating its **actual** agent/config schema. Do not assume v1's `permission`/`task` fields work in v2's `permissions`/`subagent` system. Keep roles to the smallest useful set; no unrestricted recursion.

| Role | Purpose | Authority | Required output |
|---|---|---|---|
| `orchestrator` (primary or existing Build coordinator) | Decompose requests into small tasks; route to agents; track statuses and dependencies | Project-file edits/scripts/CI under review; delegate within approved roles; merge execution only under ADR-0007 exact owner authorization; no unapproved release/spend/phone-service changes | Task board, links to subagent evidence, final synthesis |
| `repo-auditor` | Discover repository, branches, toolchain, licenses, assumptions | Read-only Git and file inspection | Inventory, discrepancies, reproducible versions |
| `device-qa` | Run Android smoke/runtime/touch/recovery tests via device lock/queue | Existing test commands; safe read-only diagnostics; no global settings or service modification | Screenshots, logcat, package/build hash, report |
| `bug-hunter` | Find/minimize bugs and design regression tests | Read/test and edit test-only files in its isolated worktree/task | Repro steps, expected vs actual, severity, failing-then-passing test |
| `visual-auditor` | Inspect actual on-device screenshots, UI spacing, contrast, RTL, clipping, touch hit areas | Screenshot/image analysis; test scripts and visual reports; art code changes only when delegated in later gate | Annotated findings with coordinates, before/after and golden diff |
| `dependency-auditor` | Evaluate libraries, tools, compatibility, licenses, risk | Read-only exploration and controlled project-local installs, version pins | Source/version/license/hash/security notes and removal plan |
| `reviewer` | Independent cross-check of modifications, scope, security and evidence | Read-only | PR risks, missing tests, acceptance verdict |

**Historical G1.5 bootstrap plan, not a current instruction to create agents:** start G1.5 with **four** reusable subagents, e.g. `repo-auditor`, `device-qa`, `visual-auditor`, `reviewer`; add roles on evidence of need. Primary agent may create extra agents or commands **inside the project** when needed and document each role's purpose, permissions, version, and expected output. No worker may create hidden perpetual agents or unbounded nested jobs. Agent orchestration uses native child tasks/workflows first, not a third-party fleet manager.

**Concurrency:** CPU/Git/static tasks may run in parallel when independent. The *single OPPO phone* must always use `agentctl`/`phone-queue` locking; only one phone-mutating test session at a time. Use bounded runtime and cleanup; avoid endless loops or continuous screen tapping.

## 3. Allowed autonomy vs required approval

### Allowed in a narrowly scoped development branch / worktree
- Inspect toolchain (`opencode --version`, documentation/schema, Git, Godot, SDK, Python, Node, test runners, Appium, `agentctl`, `adb`, disk/memory).
- Create/edit **repository-local** Python/Bash/GDScript scripts, tests, CI workflows, agent profiles and templates with unit tests and version-controlled changes.
- Use installed tools and run bounded builds/tests via GitHub Actions and the existing phone queue. Capture, store, analyze, compare and annotate screenshots, video where available, logcat and crash traces.
- Use a source-and-license review to propose/try **project-local isolated** tools (e.g., Python venv or pinned npm project dependencies) with an explicit lockfile/manifest and rollback. Validate hashes where published; reject unknown licenses and installers that request secrets or broad access.
- Automatically report deviations: app identity/hash mismatch, startup crash, state mismatch, missed taps, golden-image difference, import failure, lint failure, excessive frame time.

### Ask the owner before doing any of the following
- Permanent global Termux/Debian packages, major upgrades, modifying `agentctl`/Supervisor/ADB/Appium/runit, or replacing a known working test tool.
- Enabling Shizuku privileges for the first time, changing Android system settings or developer options, force-stopping **non-project** applications, altering permissions, or adding a persistent privileged bridge.
- Installing unreviewed OpenCode plugins/MCPs/skills, connecting third-party accounts, cloud services, paid models, or downloading executable scripts with `curl|sh`.
- PR merge requires the exact ADR-0007 authorization contract below. History rewriting/force pushes remain forbidden. Branch deletion, substantial file deletion, application ID/engine pin changes, protected-branch policy changes, production credentials, cloud spending, Firebase billing and Play/IAP/ads/signing require their own explicit authorization.

### Never do
- Treat a request as permission to root the phone or bypass Android security, disable locks, scrape personal information, touch another app's private data, or silently grant accessibility/notification permissions.
- Open the GPLv3 reference implementation; silently change approved game rules; falsify test reports or synthetic screenshots presented as device captures.
- Run unbounded scans of random ADB ports, network scans, resource-exhausting processes, recursive agents without limits, or uncontrolled package upgrades.

**Important:** Natural-language restrictions in `AGENTS.md` are policy, but enforce high-risk restrictions in OpenCode's actual permission config and narrow wrappers where technically possible. First inspect installed version/schema; do not paste v1 permission JSON into v2.

## 4. Tool-install acceptance contract

Every new dependency/tool needs a `tools/inventory.md` line: name, purpose, installed state and versions, **official upstream/source**, license, checksum or package-lock reference, supported architecture (Android ARM64 / Termux / Debian / GitHub runner), risk, alternatives, rollback, test result, owner approval required (yes/no). Prefer existing tools; build heavyweight tasks in CI, not on the phone. No mass `pkg upgrade` or `apt upgrade` without owner consent. Installation does not certify a tool; demonstrate a small repeatable test.

## 5. Workflow definitions

Implement short, rerunnable commands or scripts with typed exit codes and machine-readable JSON alongside human-readable Markdown reports. Provide `--help` and `--dry-run` wherever changes would occur. Suggested commands/names are **to be implemented**, not assumed to exist now:

| Proposed workflow | Inputs | Evidence and strict fail conditions |
|---|---|---|
| `qa-env` | none | Git/CI/tool versions, `agentctl status`, device/ADB/Shizuku capability, free resources; warns without changing the machine |
| `qa-apk-provenance` | run ID, APK path | SHA-256, package ID, version code, cert hash, installed artifact evidence; fail on mismatch |
| `qa-smoke` | APK/build ID | Install/update, portrait/foreground/touch/logcat, screenshot; fail on absence of **actual** latest APK identity |
| `qa-runtime` | duration bounded | App focus, crashes, memory snapshots, frame metrics when supported; fail on app exit or fatal errors |
| `qa-ui` | screen route, locale, device profile | Golden screenshot, safe-area/contrast/occlusion analysis, component hit boxes; flag review-required visual diffs |
| `qa-bug-repro` | issue ID, seed, steps | Exact reproduction, expected vs actual state/screenshots, log lines, regression test link |
| `qa-report` | run directory | One index showing PASS/FAIL/SKIP/UNVERIFIED and evidence links, plus unfinished blockers |

The automated tests **must be able to fail deliberately** in controlled negative-test fixtures: nonexistent package; wrong expected orientation; mismatching APK hash or screenshot. Do not cause destructive OS or data faults. The historical G1.5 plan required a rule-oracle once G2 received separate authorization; later G2 authorization is ADR-0003. The requirement was to compare GDScript GameState to expected state after actual pours/undo/restart; screen taps alone never establish game correctness.

## 6. Screenshot and visual QA pipeline

1. Capture from the installed **specific APK build** on the phone, with metadata `{commit,build,app_id,locale,screen_size,screen,device,time,quality_tier}`.
2. Confirm the image is an actual device screenshot (not only a generated mockup) and log the path, file hash, and screen state.
3. Run deterministic checks: crop/position safety, text overflow where supported, touch bounds, pixel/golden diff with masks for animations, contrast tests, portrait orientation, animations/time consistency. Do not mistake a normal animated pixel difference for a defect.
4. If an image-capable model/tool exists in the agent environment, route screenshots to `visual-auditor` for **qualitative** design feedback on button aesthetics, tube shapes, depth, hierarchy, legibility and spacing. If no vision-capable tool is available, say so; generate an evidence package for the owner/ChatGPT to review. Do **not** claim visual inspection merely because an image file exists.
5. Create findings with exact screenshot/coordinates, impact, suggested adjustment, implementation task and before/after comparison. Polished visuals must stay within `docs/current/01-UX-ART.md`; aesthetic approvals remain with owner.
6. Preserve test results, do not auto-replace approved Goldens without an explicit review.

## 7. Shizuku policy

Shizuku is an **optional, privileged Android shell diagnostic channel** (via Shizuku-exported `rish`), not a substitute for existing ADB/Appium tests. In the Android Wireless Debugging launch mode its typical identity is ADB `shell` (`uid=2000`), **not root**. The user must start Shizuku and authorize Termux. After a reboot Shizuku commonly requires restarting.

**Read-only allowlist first:** `id`, `getprop` (selected keys), `dumpsys activity`/`window` selected summaries, `dumpsys meminfo <LayerSort-package>`, `pm path <LayerSort-package>`/`pidof <LayerSort-package>` as available. On-device actions such as `input tap`, screenshot, package install/force-stop or `settings put` require explicit task scope, device queue and owner-approved policy; never give a general `rish -c "$UNTRUSTED_COMMAND"` wrapper to the LLM. Redact device/user identifiers from shared logs. Prefer existing ADB for actions it already supports.

Termux native environment is the supported location for the exported `rish`/DEX. Debian proot **cannot be presumed** to invoke it directly; ask the agent to test and document a **narrow Termux-side allowlisted bridge**, without changing Supervisor/Termux services. If unavailable, keep Shizuku marked `OPTIONAL_BLOCKED`; G1/G2 tests continue on ADB/Appium normally. Keep any bridge on-demand rather than a persistent privileged service.

## 8. Historical owner review / acceptance criteria for G1.5

A report is acceptable only when it has: inspected OpenCode version/schema; persisted project-scoped agent files; an auditable permissions matrix; tool inventory; at least two demonstrated workflows; deliberate negative-test evidence; a screenshot review report for the G1 scene (not a claim about the final UI); bounded device-lock behavior; Shizuku capability state/permissions and actual `rish id` proof **if enabled**; PR and rollback instructions. Do **not** claim a bridge, vision model or tool existed if it was not directly tested. At that historical gate G2 awaited separate owner authorization; ADR-0003 subsequently authorized it. This is not a present G2 blocker or permission to reopen accepted gameplay.

## Owner-approved execution model — 2026-11-09

This section supersedes historical G1.5 references to direct `phone-queue`, `game-test`, Appium, and the single-writer-only workflow.

### Remote command and device boundary

- Remote Desktop Commander file tools are scoped to `/root/projects/layer-sort`. Its shell command runner remains privileged and is **not** an OS sandbox.
- Agent Kit agents use `inheritMcp: false`; the project plugin defines no MCP servers. Agents must not inherit or receive the ChatGPT Remote Desktop Commander connector.
- RDC file operations are limited to the project root. Its generic shell runner remains privileged and is not constrained by `allowedDirectories`; `blockedCommands` is a denylist, not a sandbox.
- The plugin-scoped `.agents/plugins/layer-sort-agent-kit/hooks.json` installs a default-deny PreToolUse guard. Only explicitly named tools are allowed; unknown tools are denied. `run_command` uses per-executable and per-option allowlists. `view_file` (`AbsolutePath`) and `read_file` (`Path`) are restricted to the fixed project root and secret-file reads are denied. It blocks `rg --pre*`, `sed` write/execute/in-place commands, `find` file-output/execute/delete predicates, Git `--output`, file-write tools, and RDC MCP calls. Existing `ssh` allowlist entries are unchanged; any future need must be wrapped to a specific server. The hook command and script paths are absolute. Its wrapper emits an explicit deny for malformed input, missing Node, non-zero policy-engine exit, or unexpected output; it must never intentionally return empty stdout. Antigravity documents empty PreToolUse output as no-decision, not deny. A controlled missing-hook-executable probe on installed CLI 1.5.3 timed out before producing a decision, so spawn-failure behavior remains UNVERIFIED. The owner accepted that as a documented risk, not a standalone gate. Hook policy is not OS isolation.
- The sandboxed `run_command` probe failed before execution with `fork/exec /root/.local/bin/agy: operation not permitted`; root cause is not yet distinguished between PRoot, sandbox execution, and executable permissions. Owner decision is pending: Option A repairs and verifies the sandbox; Option B disables sandbox and relies on the default-deny Hook plus dedicated Worktree/Patch/Reviewer controls, explicitly without OS isolation. Do not grant agent write authority or create the first Worktree until the owner selects A or B. `unshare -Ur` availability alone is not proof that the CLI sandbox is active.
- The only approved device entrypoint is `tools/device-tests/agentctl`. It targets only `com.yoseftext.layersort.dev`, uses the existing shared phone lock and existing ADB server, and exposes no arbitrary shell, install, uninstall, clear-data, permissions, global settings, or service management.
- Appium/UiAutomator2 are **Evaluated / Not Approved**. Do not start the service or use Appium without a new owner decision.
- ADB `input tap/swipe` is synthetic input and measures in-game hit-testing, not physical touch accuracy. ADB timeouts or missing telemetry produce `UNKNOWN`.

### Worktree + Patch governance

- No agent currently has file-write or file-edit tools. The Lead's write tools are withheld; specialists remain read-only.
- A named specialist may receive write authority only after `.agents/` is committed, the plugin guard is loaded, the Device Wrapper is verified, the owner has explicitly selected sandbox Option A or B, and that specialist's dedicated Worktree exists under `.worktrees/`. Option B is an accepted operational risk, not OS isolation.
- Each implementation specialist receives one disjoint path allowlist and one task. It writes only in its own worktree and returns a patch; it never writes to `main`, pushes, merges, or rewrites history. The Lead receives integration write tools only after the same prerequisites and only for the integration step.
- Before Reviewer inspection, deterministic preflight must verify the patch path allowlist, reject protected paths, run `git diff --check`, and run the relevant existing tests.
- Reviewer independently inspects the exact diff, test evidence, scope, security, and rollback. Engineering-auditor recommendations must be reviewed by Reviewer; the auditor cannot approve its own recommendations.
- Integrate one patch at a time. Run regression tests after each integration before considering the next patch. The Lead owns integration; protected-main merge still requires exact owner authorization under ADR-0007.
- No Worktree has been created yet. `.agents/` is committed locally. All future Worktrees must be nested under `.worktrees/`, which is Git-ignored; test the fixed `PROJECT_ROOT` path policy against a real nested Worktree before granting writes.

### Measurement and evaluation

The Task Ledger begins before agent expansion, with a fixed schema:

`task_id, agent, commit, APK hash, result, Reviewer findings`

`result` must preserve the actual execution-tool payload, tool name, summary, and evidence; an exit code alone is invalid. The native `manage_task` tool is process control (`list`, `kill`, `status`, `send_input`), not task creation/update. The local append-only ledger assigns stable task IDs and records actual `invoke_subagent` responses plus completion messages. Initial acceptance: two real read-only tasks, both captured and validated (repo-auditor and device-qa); no APK was involved and no patch was submitted for Reviewer findings. Record actual execution evidence, not inferred scores. Before a sufficient sample exists, use deterministic measurements only and do not score agents. Test Escape Rate requires deliberately seeded defects and a measured Reviewer benchmark.

Device performance evidence should combine Godot runtime monitors with supported Android battery/thermal telemetry. Do not infer FPS or CPU/GPU temperature from unavailable `dumpsys` fields. The QA-only harness must use a dedicated feature tag and CI must verify that the release APK does not contain it.

### Approved implementation order — owner decision 2026-11-09

1. Commit `.agents/` — DONE.
2. Create and validate the append-only Task Ledger on two real read-only tasks — DONE.
3. Build and verify `puzzle-validator` using the Circuit solver, levels 15/17/19, a deliberately unsolvable fixture, and `UNKNOWN` on timeout.
4. Create the first nested Worktree and complete one full Patch cycle: deterministic path/diff/test preflight, independent Reviewer verdict, one-patch integration, regression test.
5. Run an acceptance test for each of the seven existing agents; do not add agents before the first Patch cycle passes.
6. Only after these gates, expand toward 12 agents and Waves 2–4, based on measured bottlenecks.

The owner performs phone reading/control and the thermal recheck; ChatGPT reviews the resulting report and does not execute phone actions. If an agent does not improve a measured outcome, stop expanding the fleet.

## Current gate reconciliation — ADR-0006

See [00-START-HERE.md](00-START-HERE.md#current-accepted-checkpoint--2026-11-03) for the accepted PR15 checkpoint and owner-reported 10/10 device QA. Earlier gate-specific instructions are historical scope, not permission to restart those gates. The owner-approved infrastructure sequence dated 2026-11-09 supersedes the prior "no phone operations" sentence only for the package-scoped wrapper and bounded read-only checks. The owner performs phone reading/control and the thermal recheck; ChatGPT reviews the resulting reports and does not access or mutate the phone. No gameplay/G5 implementation, APK install, uninstall, data wipe, global setting/permission change, service modification, or merge is authorized by that sequence.

## Owner-authorized merge execution — ADR-0007

ChatGPT provides architecture guidance, independent change/risk review, evidence assessment and a recommendation. The owner makes final decisions and authorizes each exact merge. Codex implements/tests/opens PRs and executes only an authorized merge.

Before merging, require the owner's PR number, exact full head SHA, target branch and confirmation that the reviewed changes are intended. Re-fetch and compare immediately before execution; any changed approval value requires renewed authorization. Required CI must pass and no unresolved blocking review comments may remain. All integration is through reviewed PRs: no direct main pushes, force pushes, unauthorized branch deletion or protection changes/bypass. General authorization is insufficient; multiple PRs require explicit coverage of each exact merge.

Afterward verify the resulting merge commit, intended target and CI on the integrated result, report outcome/regressions or blockers, then stop before the next PR pending its applicable authorization. No actual merge is authorized in this documentation task.
