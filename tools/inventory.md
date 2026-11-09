# Layer Sort Development Tool Inventory

**Last verified:** 2026-11-09
**Scope:** Debian 13 ARM64 / Android PRoot / OPPO CPH1937 / Godot 4.7.2 Standard.
**Policy:** No new external dependency was installed. Existing system services and global packages were not upgraded.

| Component | Verified state | Purpose / decision | Source, pin, risk, test and rollback |
|---|---|---|---|
| Antigravity CLI `agy` | 1.5.3 | Project agent orchestration and plugin validation. | Existing installation. Project plugin strict validation passes. No model quota/cost API was exposed by the CLI inventory. |
| Layer Sort Agent Kit | Local plugin 0.3.0; 7 agents, 7 skills, 1 rule, 1 plugin-scoped hook, 0 MCP servers; `.agents/` committed locally through `3292177` | Project-scoped roles, skills, file/path guard, and command policy. | `agy plugin validate --strict` passes; `/hooks` confirms `layer-sort-agent-guard` active; policy tests pass. All agents are read-only with `commandExecutionPolicy: off`. No global plugin install or GitHub push. |
| Agent model assignment | All seven existing agents use `model: inherit` | No independent model pin exists. | Per-agent quota, token cost, rate limit, and exact model resolution are **UNVERIFIED**; do not infer from the CLI's model catalogue. |
| Agent web access | No project MCP servers. Native web-search capability is described in the Antigravity tool reference. | Market research remains on-demand until actual per-agent access is confirmed. | Per-agent `search_web` availability is **UNVERIFIED**. No scraping or third-party MCP was added. |
| Godot Standard | 4.7.2 stable, ARM64 local binary | Supplemental headless checks only. | `ENGINE_VERSION.lock` and CI pin the authoritative x86_64 build archive and matching templates. Local Android export is not authoritative. |
| Java / Node / Python | Java 21.0.13; Node 24.22.0; Python 3.13.5 | Existing local runtimes. Python stdlib is used by the device wrapper and its tests. | No package install or global upgrade. |
| Android SDK / ADB | ADB 34.0.5; local platform 30; local Debian Build Tools differ from CI pins | Read-only device inspection and package-scoped QA wrapper. | ADB client is fixed at `/usr/bin/adb` and targets the existing local server `127.0.0.1:5037`; wrapper never starts/restarts the server. |
| OPPO test device | OPPO CPH1937; product OP4B80L1; Android 11 / API 30; one approved physical target selected after excluding an `emulator-*` serial | Approved physical-device QA target. | Two ADB entries were online; the emulator is excluded by serial class, then the physical target is validated by manufacturer/model/product/API and package installation. No phone mutation occurred. |
| Layer Sort device wrapper | `tools/device-tests/agentctl` + `device_qa.py`; Python standard library only | Sole approved project entrypoint for package-scoped device QA. | Fixed package `com.yoseftext.layersort.dev`; shared existing lock `/root/device-tests/test.lock`; fixed ADB argument vectors; no arbitrary shell, install, uninstall, clear-data, permissions, global settings, or service control. Unit tests: 16/16 PASS. A prior read-only real-device status preflight was reported PASS; it was not rerun in this session. Phone reads and control are owner-executed; ChatGPT does not access or mutate the phone. Mutation without exact owner approval is skipped. Revert the reviewed project patch to roll back. |
| Device wrapper evidence | `.runtime/device-qa/` | Generated screenshots and filtered game-marker logs. | Ignored by Git. Screenshot requires the game to be foreground. Logcat is restricted to the game PID and selected markers. |
| Appium / UiAutomator2 | Appium 3.8.0; UiAutomator2 8.7.0; Python Client 6.0.8; Selenium 4.51.0 installed; Appium service not running | **Evaluated / Not Approved.** Not used by the new wrapper. | No service start, driver install, or package change. Reconsider only if inventory demonstrates a capability missing from ADB wrapper. |
| Legacy `phone-queue` / `game-test` / `phone-connect` | Existing global scripts remain present | Deprecated for agent use; not called by the new wrapper. | Legacy `phone-queue` forwards arbitrary commands and `game-test` performs broad device actions. Direct invocation is denied by the current Remote Desktop Commander command denylist and Antigravity command guard. They are not an OS sandbox boundary. |
| Remote Desktop Commander | File-tool `allowedDirectories` restricted to `/root/projects/layer-sort`; direct dangerous command names added to denylist | Privileged ChatGPT-side maintenance channel only. | Verified file operations outside the project are denied. Shell commands can still access paths outside the project; this configuration is **not** an OS-level sandbox. Agent Kit has 0 MCP servers and all current agents set `inheritMcp: false`, so they do not inherit this connector. |
| Antigravity command guard | Plugin `hooks.json` + `scripts/policy.sh` + `scripts/policy.mjs` | Default-deny agent tool policy; `view_file` (`AbsolutePath`) and `read_file` (`Path`) are constrained to the fixed project root; secret-file reads and unsafe commands are blocked. Existing `ssh` allowlist entries are unchanged. | Policy tests pass; `agy plugin validate --strict` reports 1 hook; `/hooks` confirms it active. Missing-hook-executable behavior remains UNVERIFIED and is an owner-accepted documented risk, not a gate. The separate sandboxed `run_command` probe failed before execution with `fork/exec /root/.local/bin/agy: operation not permitted`; owner choice A/B is pending before first Worktree/write. Policy guard is not an OS sandbox. |
| GUT / gdUnit4 | Not installed | Evaluated test-framework candidates only. | GUT 9.7.1 advertises Godot 4.7.x support; gdUnit4 6.2.3 lists 4.7.1 but not 4.7.2 explicitly. Existing SceneTree tests and deterministic solvers remain the default. No install approved. |
| Git / GitHub CLI | Git 2.47.3; GH CLI 2.46.0 | Repository and CI inspection. | Existing OS-managed packages. No direct main push, merge, history rewrite, or branch deletion. |
| Shizuku | Installed; version and authorization not queried | Optional diagnostics, not used. | No bridge, privilege grant, or service change. Remains optional and unapproved. |

## Agent measurement fields still unknown

- Per-agent resolved model, quota, rate limits, and token cost: **UNVERIFIED**.
- Per-agent native web access: **UNVERIFIED**.
- Godot monitor availability in the release build and exact battery/thermal sensor coverage: to be confirmed by the QA harness.
- GUT/gdUnit4 compatibility is not a reason to install either framework.

## Current execution gates

1. **Remote Desktop Commander — PASS with limitation:** file tools are restricted to the project root; direct `adb` is blocked; the generic shell runner remains privileged and is not an OS sandbox. Agents do not inherit RDC.
2. **Device Wrapper — PASS:** package-scoped `agentctl` is applied; 16/16 unit tests pass; real-device status preflight passes; no mutation was executed.
3. **Thermal recheck — UNRESOLVED:** the previous SoC/HAL readings are not reliable enough to classify throttling. Owner will perform one bounded post-rest comparison using two independent sources and provide the report; no phone access was performed by ChatGPT in this session.
4. **Task Ledger — PASS:** append-only JSONL ledger implemented with Python stdlib. Two real read-only tasks recorded with raw `invoke_subagent`, `read_file`, and `send_message` tool results; validator reports 2 records and 2 verified tool results. No APK was involved; no Reviewer patch findings were applicable.
5. **puzzle-validator — PENDING:** build on production Circuit rules and deterministic test evidence. Do not score agents before a sufficient sample; Test Escape Rate requires seeded defects.

**Installation acceptance:** before adding any new dependency, record official upstream, license, exact version/checksum or lockfile, supported architecture, attack surface, minimal test, and rollback. Global Termux/Debian changes, new MCPs, paid services, and privileged bridges require separate owner approval.
