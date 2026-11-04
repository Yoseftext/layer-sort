# G4 unified integration candidate — proposal, not merge authorization

The owner requested a reviewable unified candidate based on PR17 `a9bb517041f8f3d377f31714e18c864bfec13c24`, with normal non-squash merge of PR16 `28eebd0005147c97b673fde66b485d8ef2750f48`. The original stack and all original commits remain ancestors. PR13 remains a separate parallel art-direction documentation branch; no existing PR is claimed individually merged. This unified approach differs from the earlier per-layer proposal and awaits explicit owner approval. It does not replace ADR-0007 or authorize any merge.

The pre-change integration merge has tree `8fc972b46731e08919e625f4475a7a0e00b8b2b9`, exactly matching the prior local synthetic dry run. Accepted PR15 `c961972365258baa34cae279dfc10ab46edce2f7` gameplay, save data, levels, Android project/export and engine settings are unchanged.

## Main CI transition

`android-build-g3b.yml` adds `main` to push and pull-request target filters while keeping all existing filters, jobs, tests, permissions, concurrency and artifact names. Its current startup smoke launches the actual navigation root and requires `LAYER_SORT_G3_HOME_READY`; it imports the project and fails on script errors. Its debug export checks the APK archive and excluded development files, verifies package/version/portrait/certificate, runs `apksigner verify`, records SHA-256 and enforces the size budget. Existing G2, G3 navigation/progression/recovery, campaign, G3-D, G4 optical and Real Game UI tests remain.

The historical G1 workflow starts the obsolete main scene and expects `LAYER_SORT_G1_READY` and export preset `Android G1 Debug`, neither current for G4. It is removed only from automatic PR targeting main; its historical push on `feat/gdscript-foundation` and manual `workflow_dispatch` remain. G3-B above replaces its startup and Android export/signature validation for the current application, not the original G1-specific touch oracle. Historical G1 device evidence is retained; no claim that a G4 build performs the old device touch test.

Other QA/workflows remain intact. Additional main-target triggers need separate review of stage relevance, unique check names, target availability and cost; do not automatically duplicate Android builds. A required G3-B status check should be configured only after the main-target event is actually observed and the owner separately authorizes protection settings.

## Security and acceptance boundaries

The stable debug key remains in existing CI under the documented single-owner trust model. Enabling G3-B on main PRs expands its triggering surface: repository writers able to submit or modify workflow/project code can expose the debug key. The existing G1 main-target job already carried that trust class. Untrusted fork secret behavior and repository settings must be verified independently; no claim of protection or secret isolation. Reassess before granting untrusted write access. No key, app ID, signing configuration, environment or permission changes are part of this candidate.

The owner's accepted PR15 OPPO report remains owner-reported; this candidate has no new device run. G15-QA-001 remains OPEN; rules contract remains Draft. Existing PRs stay open, no branch was rewritten or deleted, and no G5/G6 or release is authorized. Before any merge, ADR-0007 requires protection/ruleset verification for the target, required CI, review, and explicit owner approval of the exact PR/head/target/intended changes. Main protection and ruleset status remain UNVERIFIED. Roll back by closing the candidate or reverting its commits on a new review branch; do not reset saves.
