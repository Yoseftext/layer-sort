# Layer Sort

Android puzzle game (colored layers in glass tubes), built with **Godot 4
Standard + typed GDScript**. Portrait only, offline-first. The product does not
use C#.

## Current gate

**G0/G1 — Native Android smoke.** The active branch is
`feat/gdscript-foundation`. `main` is not modified. G1 proves a pinned Godot
Standard portrait scene builds in GitHub Actions, installs on the OPPO phone,
starts, renders, responds to a real touch, and leaves clean logcat evidence.

- Debug applicationId: `com.yoseftext.layersort.dev`
- Historical C# spike (retained, not the product): branch
  `spike/godot-csharp-android`, app id `com.yoseftext.layersort`
- Engine pin: `ENGINE_VERSION.lock` (Godot `4.7.2-stable`, Standard)
- Build: `.github/workflows/android-build-g1.yml`
- Device tests: `tools/device-tests/` via `agentctl smoke|touch|runtime`

## Source of truth

Active specifications are only in `docs/current/`. `docs/archive/` is
historical and must not be used as an instruction. The GPLv3 reference game is
never opened or copied.

## Local checks

```bash
bash -n tools/device-tests/game-test.sh
python3 -m py_compile tools/device-tests/*.py
```

Heavy builds run on GitHub Actions, never on the phone. Device checks use the
shared phone reservation (`agentctl` / `phone-queue`) and must preserve
screenshots and logcat in the run directory.
