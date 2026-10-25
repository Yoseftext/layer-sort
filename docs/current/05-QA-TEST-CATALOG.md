# Layer Sort — Quality Assurance Catalog (Living Document)

**Planned repository location:** `docs/current/05-QA-TEST-CATALOG.md`. A test ID is not a PASS until a run includes an artifact, environment details, expected and actual result, and a log or screenshot.

## Structured report fields
`test_id`, `gate`, `commit`, `workflow_run`, `APK_sha256`, `installed_package`, `installed_cert`, `device`, `Android_API`, `tool_versions`, `locale`, `orientation`, `expected`, `actual`, `status` (`PASS|FAIL|SKIP|UNVERIFIED`), `logs`, `screenshots`, `duration`, `issue_id`, `repro_steps`, `owner_review`.

## Minimum test matrix by gate

| IDs | Gate | Test conditions / oracle |
|---|---|---|
| ENV-01..05 | G1.5 | Installed versions, service state, permissions, storage, APK/install provenance |
| SEC-01..04 | G1.5 | No secrets logged, no out-of-scope package ops, allowed agent permissions, protected branches untouched |
| NEG-01..03 | G1.5 | Intentional failure on incorrect package, wrong expected orientation, mismatched hash; no false PASS |
| DEV-01..06 | G1.5 onward | APK install/update, cold/warm boot, focus, multitouch smoke, crash/logcat, reproducible build/hash |
| VIS-01..10 | G3/G4 | AR/EN layout, portrait notches/safe area, text overflow, 48dp targets, color assist, reduce motion, art consistency, low/high tier, approved Goldens, dynamic mask |
| RULE-01..15 | G2 | Tube capacity, compatible color, top-block amount, partial pour, invalid move, empty/full, win, restart, undo, double tap, no race, deterministic state |
| SAVE-01..08 | G3 | Force-stop during animation/save, full storage, corrupt snapshot, schema upgrade, offline, pause/resume, settings persistence |
| PERF-01..06 | G4 | Frame time p95, cold start, memory delta, 20min thermal/load, sound focus interruption, low quality tier |
| CIR-01..08 | G5 | Sensor top color, latched unlock, signal visibility, undo rollback, replay, unreachable conditions, solver validity, tutorial clarity |
| GEN-01..10 | G6 | Seed consistency, versioned PRNG, bounded generation, solver proof, duplicate detection, difficulty, breather levels, catalog fallback |
| MECH-01..10 | G7 | Freeze, Shift, Connected, combinations, priority of events, save/undo consistency, deterministic solver |
| FIRE-01..08 | G8 | Spark-only verification, telemetry default off, consent/decline, offline, Firebase failure, sanitized error report, no billing, no gameplay dependency |
| LIC-01..05 | all | Asset/source/license author proof, font/music license, dependency notice, attribution and offline credits |

## Severity and triage
- **P0:** game cannot boot, corrupted/unrecoverable progress, out-of-scope security/credential compromise. Stop release.
- **P1:** wrong pour or unsolvable shipped level, wrong win/timeout, persistent loss of input, deterministic state corruption. Stop gate.
- **P2:** layout clipped, audio interruption, intermittent animation/readability, small regressions. Fix before relevant gate signoff.
- **P3:** polish, mild timing, optional enhancements. Track and prioritize.

Every bug ticket includes: expected/actual, steps, screen/seed, installed APK hash, captured logs, screenshots, source of evidence, probable ownership, fix commit, regression test, re-test outcome. A screenshot diff alone is a finding, not proof of a logic error. At G1.5 only design the G2+ matrix; **do not fake execution**.

## G1.5 open QA backlog — one bounded follow-up

**G15-QA-001 · OPEN · P2 test reliability / external interruption, not an established gameplay defect.** On the first failed touch run a browser stole focus; on the later fresh run the game logged `LAYER_SORT_G1_TAP 1` and changed its counter, but an incoming-call overlay obscured the before screenshot. Appium reported the game package as foreground while the project-local image guard correctly returned **FAIL**. Keep both raw failed runs and their private screenshots/logcat; do not publish personal overlay content. See `docs/G15_QA_REPORT.md` and `docs/evidence/g15/reports/acceptance-touch.json`. G1.5 was **ACCEPTED WITH KNOWN LIMITATIONS** by the owner on 2026-10-25, not an all-tests PASS.

**Scheduled follow-up (single bounded task; separate review):**
1. Check the active window/overlay state **before screenshot capture**, then inspect the captured frame **before tapping** to establish that `com.yoseftext.layersort.dev` is visibly unobstructed. Package foreground alone is insufficient. Record the app/window/overlay classification without storing unrelated personal contents in Git.
2. Classify `EXTERNAL_OVERLAY_OR_FOCUS_INTERRUPTION` separately from `APP_FAILURE` in the report while keeping the strict test result `FAIL` when a valid unobstructed test was not obtained. Do not suppress crashes, missing TAP markers, or wrong app behavior as environmental interruptions.
3. Once the environment is demonstrably stable, allow **at most one controlled retry** using the existing phone lock and provenanced APK. Give each attempt its own report, screenshots and logcat; a later PASS does not overwrite any earlier FAIL. Stop after the retry or on persistent interruption; no phone-service restart or settings change.
4. Negative fixture: deliberately obscured or off-app before frame must be classified as external interruption and rejected; unobstructed frame with genuine TAP logcat/visible response may PASS. Preserve existing Chrome and incoming-call failure artifacts. Owner reviews outcomes before closing the issue.

No new agent, privileged bridge, or infrastructure installation is scheduled.
