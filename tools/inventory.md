# G1.5 development-tool inventory (2026-10-25)

No new dependency was installed in G1.5. The QA core uses Python's standard
library, system `aapt2`/`apksigner`, and the already-provisioned device-test
Pillow venv. No npm plugin/MCP, paid service, Termux package, global upgrade,
or persistent phone service was added.

| Name / installed version | Purpose / state | Official source / license | Pin/hash or lock reference | Platform, risk, alternative, removal and test |
|---|---|---|---|---|
| OpenCode `2.1.4` | Existing orchestrator; not installed here | [opencode.ai/v2/docs](https://opencode.ai/v2/docs/); `@opencode/cli@2.1.4` npm MIT | Global npm `package-lock.json` outside repo; project config `.opencode/opencode.jsonc` | Linux ARM64/Node 24; model requests can time out/consume quota. Alternative: direct local scripts. Rollback: remove `.opencode/`; no global change. `opencode --version` and one minimal `repo-auditor` child succeeded. |
| Python `3.13.5` (system) | QA stdlib oracles | [python.org](https://www.python.org/); PSF License | OS-managed, no new pin | Debian ARM64; subprocess timeouts in scripts. Alternative: Bash only. Rollback: remove `tools/qa/`. `test_qa.py` ran. |
| Pillow `13.0.0` | Pixel statistics/golden diff (preexisting device-test venv) | [python-pillow.org](https://python-pillow.org/); HPND-style Pillow license in venv `.dist-info/licenses/LICENSE` | Existing `/root/device-tests/.venv`; G1.5 did not install/upgrade it | Debian ARM64; deterministic-only (not an aesthetic oracle). Alternative: image read by owner/model. Rollback: omit visual workflow, leave venv unchanged. Actual G1 PNG test PASS (self-diff), controlled mismatch FAIL. |
| Android SDK ADB `1.0.41`, Debian `aapt2 2.19`, `apksigner 0.9` | Existing device access and manifest/signature inspection | [Android platform tools](https://developer.android.com/tools/adb) / Android SDK (Apache-2.0); Debian packages | APK SHA-256 and debug cert pinned in `docs/G1_DEVICE_REPORT.md`; no OS upgrade | Debian ARM64, phone Android 11; `aapt2 badging` variant differences handled by manifest XML. Alternative: G1 `tools/verify-apk.sh`. Rollback: remove QA wrappers, retain existing tools. Provenance run validated APK and cert. |
| Appium `3.8.0`, Appium Python Client `6.0.8`, Selenium `4.51.0` | Existing locked touch/smoke infrastructure | [appium.io](https://appium.io/) Apache-2.0; [Selenium](https://www.selenium.dev/) Apache-2.0 | Preexisting service + `/root/device-tests/.venv`, no new download | Android device + Debian ARM64; logcat marker loss under heavy logging is being investigated. Alternative: ADB + existing `agentctl`. Rollback: no G1.5 service edits made. `agentctl status` healthy; smoke PASS, touch FAIL in G1.5 run. |
| GitHub CLI `2.46.0`, Git `2.47.3` | CI metadata and protected ref checks | [cli.github.com](https://cli.github.com/) / [git-scm.com](https://git-scm.com/); MIT / GPL-2.0-only respectively | OS-managed, no new install | Debian ARM64; `gh run download` needs existing GitHub auth; no credentials printed. Alternative: manual artifact verification. Rollback: scripts only. CI run/artifact SHA match checked. |
| `agentctl`, `phone-queue` | Existing project phone lock/test entrypoints | Repository `tools/device-tests/` (project-owned scripts; no third-party license) | G1 commit `7747679` plus later test hardening; no edits in G1.5 | Termux/Debian + OPPO; single lock `/root/device-tests/test.lock`. Alternative: none for phone mutations. Rollback: remove QA wrappers; G1 tools unchanged. Smoke/runtime ran under lock. |
| Shizuku (installed; version not queried) | Optional read-only diagnostics, **not used** | [RikkaApps/Shizuku](https://github.com/RikkaApps/Shizuku) (license to verify before any bridge) | Official exported `rish`/DEX metadata present in Termux downloads; no copy, install, or bridge | Android 11; shell identity/authorization unverified. Alternative: existing ADB. Rollback: no G1.5 phone state change. Owner must authorize Termux and provide `rish -c 'id'` proof before any bridge review. |

**Acceptance rule for any future installation:** record exact official upstream,
license, signed release/checksum or project lockfile, supported architecture,
attack surface, isolation, a small repeatable test, and rollback **before**
installing. Global Termux/Debian upgrades, OpenCode plugins/MCPs and any
privileged Shizuku bridge require separate owner approval.
