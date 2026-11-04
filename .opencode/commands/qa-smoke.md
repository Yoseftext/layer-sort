---
description: Locked Android provenance + smoke + touch check on the G1 APK
agent: device-qa
subagent: true
---

Run the locked G1.5 device smoke workflow.

Inputs: $ARGUMENTS (optional APK path; optional duration in seconds).

1. Run `bash tools/qa/qa-smoke.sh --apk PATH --run-id ID` with the provided inputs. The wrapper first compares the APK against the downloaded CI artifact and its certificate, then installs via `agentctl`, verifies the installed APK SHA-256, and runs locked smoke/touch checks. It does not change global Android settings.
2. Capture screenshot + logcat in the `agentctl` run directories. If the smoke and touch phases diverge (for example another app steals foreground), report the failure rather than masking it.
3. A verdict is `PASS` only with: correct foreground package, portrait orientation, READY and TAP markers, non-black screenshot, and no fatal/script errors. Runtime stability requires a separate bounded `qa-runtime.sh` run and its own verdict.
4. On failure, produce an actionable bug report (expected vs actual, repro, severity P0–P3, evidence paths, hypothesis, regression test).
5. Do not change global settings or services; do not uninstall; do not force-stop non-project apps.
