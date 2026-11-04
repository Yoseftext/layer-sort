# G3-B remediation — engineering handoff

Base: `feat/g3b-progression` at `20b0755cbcf3c869237c7b7f90fe720b68012978`. The historical G3-B CI APK from run `40311416928` is the actual comparison file: SHA-256 `f8e66b771c3ac17b52f4c9e4ab55cd7bf818586db698365efd5abe1076d78dae`, 28,400,376 bytes (27.085 MiB). The OPPO evidence in this checkout is G2.1 at `b9f7584`, not G3-B; no G3-B device verdict can be inferred from it.

## Verified defects and corrections

| Severity | Defect / cause | Correction / regression |
|---|---|---|
| High | Write failure only reached logcat while gameplay continued; failed exit erased in-memory attempt | Explicit write result, localized modal warning and retry preserving the in-memory board; `remediation_test.gd` |
| High | A newer save schema could be ignored in favor of an older slot and overwritten, especially if its checksum differs from v1 | Detect valid newer schema, read older state only for diagnosis, block writes; `progression_test.gd` |
| Medium | Recovery could not distinguish missing, corrupt, recovered and future-schema slots | Structured recovery status and bounded sequence/move values; `progression_test.gd` |
| Medium | Project/About showed G3-A while APK showed G3-B | Debug update version `0.3.2-g3b` / code 5 across metadata and both locales; CI checks |
| Medium | Selected language was disabled and visually ambiguous | Enabled toggle with selected state; `remediation_test.gd` |
| Medium | Back from Win exposed an already-completed board; dialogs used inconsistent default presentation and focus outline was empty | Shared dialog style/size and visible button focus; G3-A/G3-B navigation regression |
| Medium | Rejection reasons leaked English codes into Arabic | Localized Classic rejection messages; G2 and navigation regression |
| Medium | No repeatable APK content/size comparison | `tools/apk-report.py`, 32 MiB CI budget and ZIP-entry tests |

`SaveRepository` retains v1 compatibility. It writes a temporary file, calls Godot `flush()`, closes it, and renames it to the alternating slot. This is a crash-resistant two-slot strategy, not a power-loss or `fsync` guarantee. A future valid schema blocks writes until an explicit migration is implemented. The old slot remains intact on failed temp write or replacement. Tests use isolated `user://` subdirectories or injected failures and never touch device saves. The format checksum detects accidental corruption, not cheating.

The size budget is 32 MiB (33,554,432 bytes), approximately 18% above the actual previous G3-B APK. It is a preliminary guard, not a performance or quality claim. The prior APK's largest entry was `lib/arm64-v8a/libgodot_android.so` (25,465,279 compressed bytes); 25,920,129 compressed bytes total were native libraries. Investigate size regressions by actual entry hashes; preserve required Godot runtime and ABI. CI checks the budget and forbidden files. Compare the final artifact with the downloaded baseline using `python3 tools/apk-report.py FINAL.apk --baseline BASELINE.apk --budget-mib 32 --output REPORT.json`.

## Phone handoff (Track B)

Only after exact-head Track A: obtain the final CI APK, verify its SHA-256 and debug certificate, acquire the existing phone lock, install on OPPO, record package/version and installed hash. Exercise Splash/Home/Map/Settings/About, English and Arabic RTL, locked entry, real win/unlock, Continue after force-stop and after app update with a preserved test save, Pause/Resume/Back and fast touch. Inspect safe areas, focus, dialog size and Arabic wrapping in actual screenshots; capture logcat. For save failure use isolated QA storage or injection, not the owner's real save. Record each case PASS/FAIL/SKIP/UNVERIFIED and retain failed or interrupted attempts. G15-QA-001 stays OPEN. This cloud session has no ADB/device connection, so Track B remains UNVERIFIED.

Rollback: keep both `user://save_a.json` and `user://save_b.json`; return to the exact G3-B base APK without clearing app data. An older build has no reader for future schemas. No PR is merged and `main` remains untouched.
