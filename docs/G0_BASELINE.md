# G0 — Git Safe Baseline

Date: 2026-10-24
Scope: G0/G1 only. `main` is not modified.

## Baseline recorded before the GDScript branch

- Historical C# spike branch: `spike/godot-csharp-android`
- Baseline commit: `c50ca09` (`test(android): prove C# runtime execution on device`)
- Baseline CI run: `39987827578` (success)
- Baseline APK: `layer-sort-spike-debug.apk`
  - Size: `103937371` bytes
  - SHA-256: `c6d6c987b36f7d7e9b83408a039011260df84f8efd328fdf3cd57dd737a8854d`
  - Contains the C# payload (`LayerSort.dll`, `.dotnet-publish-manifest`,
    `lib/arm64-v8a/libmonosgen-2.0.so`)
- Historical C# applicationId: `com.yoseftext.layersort`
- The spike branch, its commits, and its artifacts are retained unchanged.

The C# spike proves build/device infrastructure only. It is not evidence for
G1 and its test results must not be reused as G1 proof.

## New G1 development identity

- Branch: `feat/gdscript-foundation` (created from `c50ca09`)
- Provisional debug applicationId: `com.yoseftext.layersort.dev`
  - Separate from the historical C# app.
  - The final production applicationId remains an owner decision.
- Display label for G1: `Layer Sort G1`
- Version: `0.1.0-g1` / versionCode `1`

## Engine and Android pin

`ENGINE_VERSION.lock` is the source of truth for CI. G1 pins:

- Godot `4.7.2-stable`, Standard (non-.NET) edition
- Matching Standard export templates `4.7.2-stable`
- Renderer: `gl_compatibility`
- Orientation: Portrait only, reference viewport `720x1600`
- ABI: `arm64-v8a`
- minSdk `24`; targetSdk `36`

## Debug signing

A single stable debug keystore is used for all G1 CI builds so a newer debug
APK can install over an older one.

- Keystore lives outside Git at `/root/.config/layersort/android-debug.keystore`
  (mode `600`); passwords live in `/root/.config/layersort/android-debug.env`
  (mode `600`).
- GitHub Actions secrets (values never committed or printed):
  - `ANDROID_DEBUG_KEYSTORE_B64`
  - `ANDROID_DEBUG_KEYSTORE_PASSWORD`
  - `ANDROID_DEBUG_KEY_ALIAS`
  - `ANDROID_DEBUG_KEY_PASSWORD`
- Public certificate SHA-256:
  `de1faa3e10dbcc058f3f1b13c34fb1eb929140bbbe0a7499b348f75d8a1c095e`
- CI verifies the exported APK against
  `tools/device-tests/expected-debug-cert.sha256`.
- Production/release signing is explicitly out of scope.

## Files retired from the new branch only

These are C#-spike files. They remain recoverable from
`spike/godot-csharp-android`; they are not deleted from Git history:

- `SpikeBoot.cs`
- `LayerSort.csproj`
- `LayerSort.sln`
- `global.json`
- `Main.tscn` (spike scene; replaced by `scenes/boot/boot.tscn`)
- `.github/workflows/android-build-spike.yml` (replaced by the Standard
  GDScript workflow)
- the `[dotnet]` project section and C# feature flag

Deletion is confined to `feat/gdscript-foundation` and is reviewed in the G1
diff. The C# branch is kept intact.

## Rollback

- Inspect or rebuild the C# spike:
  `git switch spike/godot-csharp-android`
- Abandon G1 work without touching `main`:
  `git switch spike/godot-csharp-android` (the G1 branch remains for review)
- CI artifacts are retained for 14 days; the baseline APK remains downloadable
  from run `39987827578`.
