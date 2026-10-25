---
description: Verify APK provenance (CI run, commit, hash, package, cert, installed artifact)
agent: device-qa
subagent: true
---

Verify APK provenance with strict PASS/FAIL. Inputs: $ARGUMENTS

Expected inputs: an APK path and optionally a GitHub Actions run ID and expected SHA-256. A run ID triggers a fresh CI artifact download and byte-for-byte comparison.

1. Run `bash tools/qa/qa-apk-provenance.sh --help` first if the arguments are unclear, then execute it with `--apk PATH`, optionally `--run-id ID --sha256 HASH --installed`.
2. Chain the evidence: CI run → head commit → artifact SHA-256 → local APK SHA-256 → installed package version/cert/installed APK hash when the device is used.
3. Any mismatch is `FAIL`, not a warning. Report the exact expected vs actual values.
4. Use report fields from `docs/current/05-QA-TEST-CATALOG.md` (test_id, commit, workflow_run, APK_sha256, installed_package, installed_cert, device).
