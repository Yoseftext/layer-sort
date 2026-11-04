# Optical Clarity — gameplay production slice

Owner-approved direction and provenance: ADR-0004. Base G3-D PR #12 / dafc73398af9dd990fed729a23b60903101ab90b. Separate reference G4-A PR #13 / b2b58dfe7fd120fa01c7776a7e40d12a021c8853. No design-branch merge.

## Material and composition specification

Navy #111B2C background, white #F4F7FC text, secondary #AABBD0, cyan #75D7EA accent. Editable runtime tokens live in `OpticalTheme`; materials in `TubePainter`. Original vector drawing, no background screenshots, textures, plugins or shaders. The static stage uses a bounded light pool, thin optical arcs and a quiet bench line. The previous large outlined board panel becomes transparent.

Glass has an outer contour, inner wall, double elliptical lip, heel thickness, broad reflected softbox and opposing edge. Liquid has bounded lateral shading, curved layer boundaries, a lighter meniscus and dark count markers independent of hue. Rendering consumes snapshots; the existing single-commit tilt/stream/receiver normalized transfer remains authoritative-state independent.

Typography is gameplay-scoped Manrope weight550 plus Noto Sans Arabic weight500 fallback. Arabic shaping is verified in actual Godot captures; levels use Latin digits. The global theme is not changed. Home/Pause/Undo/Restart are restrained outlined controls, with distinct focus/pressed/disabled states. Existing safe-area composition, accessible labels and generous hit regions remain.

Low tier retains readable silhouettes, color markers and surfaces while omitting optional reflection detail. Reduced Motion uses the existing short presentation path without the tilted ghost. No ambient animation or per-frame background redraw is used. Static background redraws only on resize; active tubes redraw for existing selection/transfer/feedback animations.

## Responsibilities and assets

| File | Responsibility |
|---|---|
| scripts/presentation/optical_theme.gd | Gameplay-only colors, fonts and control styles |
| scripts/presentation/optical_backdrop.gd | Static optical stage drawing |
| scripts/presentation/tube_painter.gd | Shared glass/liquid material for board and pour ghost |
| scripts/ui/classic_game.gd | Existing gameplay UI construction; applies scoped theme and adaptive sizing |
| content/fonts/* | Unmodified OFL font binaries, exact licenses and source/hash register |
| content/about/credits.json | Required font attribution entry |
| tests/visual/optical_clarity_test.gd | Genuine 3–6 tube EN/AR, narrow, selection, transfer and reduced-motion captures |

Fonts: exact downloaded binaries and licenses recorded in `content/fonts/provenance.json`; original copyrighted author notices retained in OFL text and bundled JSON. Manrope and Noto Sans Arabic are SIL OFL 1.1; commercial embedding allowed, font-only sale prohibited, reserved-name restrictions apply to modified derivatives. No derivatives/subsetting or third-party art/audio packs. The renderer/stage geometry is original project code. Proposed G4-A fonts are now actual resources, not host fallback previews.

## Verification and visual review

[Actual side-by-side Godot evidence](evidence/g4b-optical/README.md). Before: exact PR12 head, same harness run against baseline without source edits. After: this source tree. 3/4/5/6 tube fixtures are actual existing levels003/005/006/011; 600×1600 narrow uses actual logical viewport dimensions. No synthetic content is shipped. 14 images per side. Pour frames explicitly sample normalized0.30/0.50/0.70 with tween paused/scene clock slowed for software readback; they prove rendered transfer states, not realtime frame pacing.

Local headless suites passed: G2 1149, G3-A53, G3-B navigation21/progression28/remediation14, visual15, G4 production17, feedback23, campaign197, G3-D26. Python APK/audio5 passed. Optical GUI105 passed; existing cloud smoke185 passed; campaign GUI12 renders passed. Source solver completed. Commands follow existing workflow; `godot --headless --audio-driver Dummy --path . --script res://tests/<suite>.gd`; GUI uses `DISPLAY=:100 VISUAL_CAPTURE_DIR=<isolated-dir> godot --audio-driver Dummy --path . --script res://tests/visual/optical_clarity_test.gd`. Save tests use isolated XDG_DATA_HOME.

Independent review actually achieved: parent agent reviewed code and actual EN/AR/narrow/transfer images independently of implementation. Found rotating ground-shadow on the pour ghost; fixed with an explicit grounded flag. Requested stronger type and restrained optical stage; corrected variable-font wght axis, reduced stage radius and added curved liquid boundaries. Final review: conditional visual acceptance for improved readability/depth, owner premium-quality approval pending.

Known visual limits: tilted liquid remains a rigid layered representation, not gravity-level fluid simulation; source air gap and surface orientation can look stylized. Background arcs may be faint on low-brightness OPPO LCD. No full accessibility certification. Existing Godot exit-time ObjectDB/resource warnings persist in some harnesses. G15-QA-001 remains OPEN. Initial GUI attempt had stale X99 and failed display initialization; own Xorg100 restored cloud testing. First Python discovery used a nonexistent test directory, then correct existing test modules passed. `/usr/bin/time` unavailable; Python resource measurement used instead. Failed logs retained.

Cloud measurement, one sample of full smoke including timers/screenshots: wall35.294s, userCPU65.389s, systemCPU1.514s, peakRSS273088KiB; Mesa llvmpipe software renderer. This is test-process cost, not gameplay FPS, Android GPU, thermal, battery or cold-start benchmark. Low tier halves lateral-shading strips (2 per edge versus4), omits optional reflection; backdrop has12 static discs and2 arcs, no processing loop. No added textures or shaders.

Android-only acceptance: exact CI artifact install/update without clearing saves, typography/safe areas at system font settings, 3–6 tube touch targets, rapid input and cancel during pour, low-brightness color markers, low/high quality, Reduced Motion, focus/audio lifecycle, warm resume and sustained frame pacing. Track B UNVERIFIED.

Rollback: revert this feature's commits on a review branch; do not reset saves or earlier stack branches. No protected branch or existing PR merged. Scope ends at one gameplay screen pending owner visual approval.
