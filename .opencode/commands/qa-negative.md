---
description: Run the deliberate negative-test suite and prove the QA checks can fail
agent: device-qa
subagent: true
---

Run the controlled negative tests for G1.5.

Inputs: $ARGUMENTS (optional flags passed through).

1. Execute `bash tools/qa/qa-negative.sh` (pass `$ARGUMENTS` through).
2. The suite must demonstrate at least: a wrong expected package, a wrong expected orientation, and a mismatched APK SHA-256 all produce `FAIL` without touching `main`, phone services, or other apps' data.
3. Report each case as NEG-01..03 from `docs/current/05-QA-TEST-CATALOG.md` with the exact expected/actual output and the evidence path.
4. A negative test that incorrectly passes is itself a P1 bug in the QA tooling; report it as such.
