# G3-D player flow — local implementation report

Date: 2026-11-02. Branch: `feat/g3d-player-flow`, created directly from verified PR #11 head `1f6289a00d0998597d90cc467d0d023953e92db3` (`feat/g3c-player-ux`). This slice changes Home and Win navigation only. G2 rules, level fixtures, save schema, renderer, package identity, signing settings and `main` are unchanged. G15-QA-001 stays OPEN.

## Behavior

- Home's primary button names the actual level. It resumes a validated, unsolved committed snapshot exactly; otherwise it opens the first unlocked incomplete level. Once all available Classic levels are complete, it offers the replay map. Arabic and English labels use the same target calculation as the action.
- Win has a primary **Next · Level N** action when the catalog's next level is unlocked, secondary **Replay** and **Level Map** actions, and a primary **Level Map** action on the last available level. Replay starts a new attempt without changing the existing completion record. Win and stale Home/Map events reject duplicate transitions.
- Win's secondary controls have visible outlines and large touch regions. This reuses the existing dialog and shared widget styles; no new art identity or game mechanic was added.

| File | Responsibility in this slice |
| --- | --- |
| `scripts/ui/navigation_coordinator.gd` | Resolve Home and next-level targets, route Win actions, guard stale input. |
| `scripts/ui/home_screen.gd` | Render a supplied primary-action label. |
| `scripts/ui/win_dialog.gd` | Present Next/Replay/Map actions and last-level layout. |
| `scripts/ui/ui_text.gd` | Bilingual player-flow strings. |
| `tests/g3d/player_flow_test.gd` | Exact resume, bilingual Home, Win routing, replay integrity, last level and duplicate input. |
| `tests/visual/cloud_smoke_test.gd` | Real X11 pointer checks and 720×1600 screenshots of updated flow. |
| `.github/workflows/android-build-g3b.yml` | Run the G3-D regression in the existing CI suite. |

## Local Track A evidence

Pinned Godot 4.7.2 Standard binary: `/tmp/layersort-cloud/Godot_v4.7.2-stable_linux.x86_64`. Commands used `--path . --script res://tests/<suite>.gd`, `--headless --audio-driver Dummy` for code suites. Logs are in `docs/evidence/g3d/logs/`.

| Suite | Result |
| --- | --- |
| G2 Classic | PASS, 1,149 checks |
| G3-A navigation | PASS, 53 checks |
| G3-B navigation | PASS, 21 checks |
| G3-B progression/save | PASS, 28 checks with isolated `XDG_DATA_HOME` |
| G3-B remediation | PASS, 14 checks |
| Gameplay visual logic | PASS, 15 checks |
| G4 presentation/audio | PASS, 17 checks |
| Feedback | PASS, 23 checks |
| Campaign | PASS, 197 checks |
| G3-D player flow | PASS, 24 checks |
| Python APK/audio tests | PASS, 5 tests |
| Feedback graphical | PASS, 8 checks |
| Campaign graphical | PASS, 12 renders |
| Cloud graphical smoke | PASS, 185 checks, 28 screenshots, Xorg dummy 720×1600, Compatibility renderer |

Total headless Godot checks: **1,541**. `python3 tools/content/verify_campaign.py` completed and wrote the per-level solver report. `git diff --check` passed. Existing Godot suites emitted ObjectDB/resource-at-exit warnings despite passing assertions; those warnings remain an investigation item and are not a clean-runtime claim.

The first unisolated G3-B progression run failed three checks because its existing fixed `user://g3b_test` directory contained a future-schema fixture from a previous run. The failed log is retained. A fresh `XDG_DATA_HOME=/tmp/g3d-g3b-isolated-data-1` run passed 28/28 without altering the test or save code. The first graphical attempt failed two checks because the level-14 pointer test fired before layout settled; its screenshots and log are retained. A later attempt failed to initialize X11 after the display server stopped; that log is also retained. The final graphical attempt passed 185/185 after waiting for layout and asserting target bounds. See `docs/evidence/g3d/attempts/` and `docs/evidence/g3d/logs/`.

I inspected actual desktop captures for English and Arabic Home, the English Next/Replay/Map result, and the Arabic last-level Map/Replay result. These prove only the local 720×1600 software-rendered GUI. They do not prove OPPO safe areas, Android dialogs, frame pacing, or audio focus.

## Delivery gate and remaining work

Track A is **LOCAL PASS / CI AND FINAL APK BLOCKED**. GitHub REST/GraphQL returned HTTP 401, and `git ls-remote origin` could not authenticate. No new CI run, signed final APK, APK SHA-256 or draft PR can be truthfully reported for this source head. The existing APK from PR #11 predates G3-D and is not a G3-D artifact. The prepared draft PR body is saved at `docs/evidence/g3d/draft-pr-body.md`; publish the stacked PR against `feat/g3c-player-ux` when repository credentials are restored, then use its exact CI artifact for Android verification. Do not use the older APK as proof.

Track B is **UNVERIFIED**. On the OPPO, install the exact future G3-D CI APK under the phone lock, verify commit/hash/certificate, and check fresh Home EN/AR, exact Continue after background/restart, Win Next, Replay, Map, final-level fallback, fast double taps, Back, safe areas, screenshots and logcat. Preserve the installed save; use isolated failure fixtures for destructive cases.

Known limits: catalog currently ends at Classic level 14; G3-D does not create Circuit level 15 or additional content. Settings remain session-only. Native Android hit targets and dialogs require Track B. No PR was merged and no protected branch was changed. Roll back this slice by reverting its single G3-D commit on a new branch or closing the stacked PR; do not reset saves or earlier branches.

## Final evidence review

Implementation commit: `4102d971a849ac466a843023c97c10757d068099`. The primary agent independently reviewed the code diff and the final English Win / Arabic final-level renders. A report-only follow-up corrects the G3-D count to the recorded **24** and total to **1,541**; raw logs and historical attempts remain unchanged. No source changed after the recorded tests. CI at the final head remains blocked; local results must not be represented as a CI run.
