# Layer Sort — Agent Operations & Controlled Autonomy

**Document:** `docs/current/04-AGENT-OPERATIONS.md`  
**Identifier:** `LS-AGENT-OPS-1.4`  
**Status:** Owner-requested operational policy for a new **G1.5** gate; implement in an isolated PR and request owner review before merge.  
**Scope now:** Agent orchestration, scripts, tool inventory, UI inspection, QA workflows, optional Shizuku diagnostics. **No G2 gameplay implementation until a separate owner authorization.**

## 1. Scope and source-of-truth

1. Preserve all existing design decisions: Godot 4 Standard / typed GDScript / Android portrait / offline-first / Firebase Spark only, with Firebase integration later.
2. `AGENTS.md` and `docs/current/{00-START-HERE,01-UX-ART,02-ENGINEERING,03-PRODUCTION}.md` remain authoritative for their subjects. This document adds only agent/QA-operations policy. On conflict, do not silently override: file a small ADR for owner review.
3. The current G1 PR remains unmerged pending owner approval. Protect `main`, `spike/godot-csharp-android`, git history, existing CI, and Termux/ADB/Appium infrastructure.
4. Treat the prior device report and screenshots as **G1 evidence**, not proof of game mechanics, UI beauty, or G2 readiness.
5. Never open the GPLv3 reference implementation, import its assets, or copy its code. Never contact paid APIs or enable billing.

## 2. Role architecture — use native OpenCode subagents

Create **project-scoped** agent definitions under `.opencode/agents/`, after discovering the installed OpenCode version and validating its **actual** agent/config schema. Do not assume v1's `permission`/`task` fields work in v2's `permissions`/`subagent` system. Keep roles to the smallest useful set; no unrestricted recursion.

| Role | Purpose | Authority | Required output |
|---|---|---|---|
| `orchestrator` (primary or existing Build coordinator) | Decompose requests into small tasks; route to agents; track statuses and dependencies | Project-file edits/scripts/CI under review; delegate within approved roles; cannot merge/publish/spend/alter phone services | Task board, links to subagent evidence, final synthesis |
| `repo-auditor` | Discover repository, branches, toolchain, licenses, assumptions | Read-only Git and file inspection | Inventory, discrepancies, reproducible versions |
| `device-qa` | Run Android smoke/runtime/touch/recovery tests via device lock/queue | Existing test commands; safe read-only diagnostics; no global settings or service modification | Screenshots, logcat, package/build hash, report |
| `bug-hunter` | Find/minimize bugs and design regression tests | Read/test and edit test-only files in its isolated worktree/task | Repro steps, expected vs actual, severity, failing-then-passing test |
| `visual-auditor` | Inspect actual on-device screenshots, UI spacing, contrast, RTL, clipping, touch hit areas | Screenshot/image analysis; test scripts and visual reports; art code changes only when delegated in later gate | Annotated findings with coordinates, before/after and golden diff |
| `dependency-auditor` | Evaluate libraries, tools, compatibility, licenses, risk | Read-only exploration and controlled project-local installs, version pins | Source/version/license/hash/security notes and removal plan |
| `reviewer` | Independent cross-check of modifications, scope, security and evidence | Read-only | PR risks, missing tests, acceptance verdict |

Start G1.5 with **four** reusable subagents, e.g. `repo-auditor`, `device-qa`, `visual-auditor`, `reviewer`; add roles on evidence of need. Primary agent may create extra agents or commands **inside the project** when needed and document each role's purpose, permissions, version, and expected output. No worker may create hidden perpetual agents or unbounded nested jobs. Agent orchestration uses native child tasks/workflows first, not a third-party fleet manager.

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
- Branch merge, rewriting history, deleting substantial files, changing application ID / engine pin, editing protected branches, production credentials, cloud spending, Firebase billing, Play/IAP/ads/signing.

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

The automated tests **must be able to fail deliberately** in controlled negative-test fixtures: nonexistent package; wrong expected orientation; mismatching APK hash or screenshot. Do not cause destructive OS or data faults. Once G2 is authorized, add a rule-oracle comparing GDScript GameState to expected state after actual pours/undo/restart; screen taps alone never establish game correctness.

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

## 8. Owner review / acceptance for G1.5

A report is acceptable only when it has: inspected OpenCode version/schema; persisted project-scoped agent files; an auditable permissions matrix; tool inventory; at least two demonstrated workflows; deliberate negative-test evidence; a screenshot review report for the G1 scene (not a claim about the final UI); bounded device-lock behavior; Shizuku capability state/permissions and actual `rish id` proof **if enabled**; PR and rollback instructions. Do **not** claim a bridge, vision model or tool existed if it was not directly tested. G2 remains blocked until owner authorizes it separately.
