# Layer Sort — Godot C# Android Build Spike Report

Status: **prepared, not yet run.** Everything below is pinned from official
sources, except Android SDK `platform-tools`, which deliberately tracks the
current stable package (required by Godot's export validation; see §10). The
GitHub Actions run has **not** been executed yet (pushing awaits approval), so
CI results are unknown and are **not** claimed here. See "Verification
evidence" for what was checked locally vs. what requires the first Actions
run.

## 1. Goal

Prove that a minimal Godot 4.7.2 .NET (C#) project can be imported, compiled,
smoke-tested, and exported to a debug Android APK entirely in GitHub Actions,
with no Android Studio on the developer's phone. This is a proof of concept,
not the game.

## 2. Pinned toolchain (exact versions and official sources; platform-tools deliberately floating)

| Component | Version | Source | How pinned |
| --- | --- | --- | --- |
| Godot .NET editor | Godot **4.7.2-stable** (mono), Linux x86_64 | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_mono_linux_x86_64.zip` | SHA512-verified at runtime against the release's official `SHA512-SUMS.txt` |
| Godot .NET export templates | `Godot_v4.7.2-stable_mono_export_templates.tpz` → `~/.local/share/godot/export_templates/4.7.2.stable.mono` | same official release | SHA512-verified at runtime |
| C# project SDK package | `Godot.NET.Sdk` **4.7.2** (MSBuildSdk, MIT) | `https://api.nuget.org/v3-flatcontainer/godot.net.sdk/4.7.2/godot.net.sdk.nuspec` | exact version in `LayerSort.csproj` |
| .NET target framework | **`net9.0`** | Godot source `platform/android/export/export_plugin.cpp` @ tag `4.7.2-stable`: non-gradle Android export calls `_validate_dotnet_tfm("net9.0")` and fails otherwise | exact TFM in `LayerSort.csproj` |
| .NET SDK | **9.0.319** (latest 9.0.x patch, 2026-10-13) | `https://builds.dotnet.microsoft.com/dotnet/release-metadata/9.0/releases.json` | `setup-dotnet` input |
| Java JDK | **Eclipse Temurin 17.0.21+9** (OpenJDK 17) | Adoptium API asset metadata: `https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=linux&vendor=eclipse` (newest JDK 17 GA); Godot docs recommend JDK 17 and `validateJavaVersion` accepts ≥17 | exact `java-version: "17.0.21+9"` in `setup-java` |
| Android command-line tools | `commandlinetools-linux-15859902_latest.zip`, SHA-256 `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583` | `https://developer.android.com/studio` | URL + checksum in workflow |
| Android SDK build-tools | **36.1.0** | Godot 4.7.2 `platform/android/java/app/config.gradle` (`ext.versions.buildTools`) | `sdkmanager` pin |
| Android SDK platform | **android-36** (`compileSdk`/`targetSdk` 36) | same `config.gradle` + `detect.py` defaults | `sdkmanager` pin |
| Android NDK | **29.0.14206865** | same `config.gradle` (`ndkVersion`) | `sdkmanager` pin |
| CMake (SDK package) | **3.10.2.4988404** | Godot docs "Exporting for Android" | `sdkmanager` pin |
| Android platform-tools | **not pinned** — current stable when written: **37.0.1** | Google SDK repository `repository2-3.xml`; Godot 4.7.2 `export_plugin.cpp` requires `platform-tools` + `adb` even for template exports | deliberately unversioned `sdkmanager` package; see §10 |
| Gradle / AGP / Kotlin (only used by fallback gradle mode) | 8.11.1 / 8.6.1 / 2.1.21 | template `gradle-wrapper.properties` + `config.gradle` at tag 4.7.2-stable | bundled by the template, not installed manually |
| Debug signing | Godot's **built-in auto-generated editor debug keystore** (created via JDK `keytool` on first Android export) | `export_plugin.cpp` `_create_editor_debug_keystore_if_needed()` | none needed; **no real keystore exists in this spike** |
| GitHub Actions | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1), `actions/setup-dotnet@a98b56852c35b8e3190ac28c8c2271da59106c68` (v6.0.0), `actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad` (v6.1.0), `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9` (v7.0.2) | GitHub API tag refs | full commit SHAs in workflow |
| Runner | `ubuntu-24.04` (Linux x86_64) | GitHub-hosted images | pinned runner label |

## 3. Godot C# Android export mode decision

Godot 4.7.2 supports two ways to produce an Android APK for .NET projects:

1. **Template export mode (chosen)** — the prebuilt `android_debug.apk` inside
   the .NET templates is patched with the project's assemblies. Requirements:
   C# project targeting **net9.0**, .NET SDK, templates installed, JDK 17
   (for `keytool`/`apksigner` signing), Android build-tools (for apksigner).
   No Gradle, no NDK compilation. This is Godot's default
   (`gradle_build/use_gradle_build=false`).
2. **Gradle build mode (fallback)** — installs `res://android/build` from
   `android_source.zip` and runs Gradle with AGP 8.6.1. Requirements above plus
   NDK 29.0.14206865, CMake, and Gradle. Enabled by
   `gradle_build/use_gradle_build=true` and exporting with
   `--install-android-build-template` combined with `--export-debug`.

The workflow always installs NDK + CMake, so switching to fallback mode needs
only the preset flag flip (mode 2 requirements are already satisfied).

## 4. Files created or modified

```
.github/workflows/android-build-spike.yml   (new) CI pipeline
.gitignore                                  (new) .godot/, build/, logs/, dumps
export_presets.cfg                          (new) Android debug preset (template mode)
icon.svg                                    (new) embeddable, no-asset-dependency icon
project.godot                               (new) engine 4.7, C#, main scene, assembly "LayerSort"
LayerSort.csproj                            (new) Godot.NET.Sdk 4.7.2, TargetFramework net9.0
Main.tscn                                   (new) Node root + Label ("Layer Sort — Build Spike OK")
SpikeBoot.cs                                (new) sets label text, prints CI marker
AGENTS.md                                   (modified) engine line only
docs/BUILD_SPIKE_REPORT.md                  (new) this report
```

Documented Android application identifier:
**`com.yoseftext.layersort`** (`export_presets.cfg` → `package/unique_name`).

## 5. Build and export commands (as run in CI)

```
godot-mono --headless --path . --import                   # import/validate project
godot-mono --headless --path . --build-solutions          # compile C#
godot-mono --headless --path . --quit-after 10            # smoke run of main scene
godot-mono --headless --path . --export-debug "Android Debug" build/layer-sort-spike-debug.apk
```

Plus SDK/JDK/editor-settings setup steps and SHA checks, see the workflow.

## 6. Smoke test design

- `SpikeBoot.cs` (attached to the main scene root) executes real C# code:
  sets the `Label` text and prints the ASCII marker `LAYER_SORT_SPIKE_OK`.
- CI asserts the marker appears in `logs/smoke.log` (proves the assembly
  loaded and executed under the Godot runtime), and fails on any
  `SCRIPT ERROR` line.
- The workflow additionally fails if the APK is missing/empty, not a valid
  zip, or lacks `AndroidManifest.xml`.

**Testing boundary:** the compile/execute assertion applies only to the Linux
headless smoke test. The Android APK is validated only as an exported artifact
(exists, non-empty, valid zip, contains `AndroidManifest.xml`); the workflow
never installs or launches it on a device or emulator, so Android runtime
execution remains unverified.

## 7. Expected CI artifacts

| Artifact | Location | Contents |
| --- | --- | --- |
| APK | workflow artifact `layer-sort-spike-debug-apk` | `build/layer-sort-spike-debug.apk` |
| Logs | workflow artifact `layer-sort-spike-build-logs` (**uploaded with `if: always()`, so failed runs still publish partial logs**; `if-no-files-found: warn`) | `logs/toolchain.txt`, `logs/android-sdk.txt`, `logs/sdk-licenses.log`, `logs/import.log`, `logs/build-solutions.log`, `logs/build-dotnet-exportdebug.log`, `logs/smoke.log`, `logs/export.log`, `logs/apk_contents.log` |

## 8. Verification evidence

**Locally verified (phone, lightweight checks only — heavy builds delegated to Actions):**

- Git state was clean before starting; work is on branch
  `spike/godot-csharp-android`; `main` untouched.
- Godot 4.7.2-stable release and both required assets exist in the official
  `godotengine/godot-builds` release, with official SHA512 sums recorded here.
- `Godot.NET.Sdk` 4.7.2 exists on NuGet.
- .NET 9.0.319 is the current 9.0 SDK per Microsoft's release metadata.
- Android command-line tools URL + SHA-256 taken from developer.android.com.
- Android build-tools/platform/NDK versions read from Godot 4.7.2-stable
  `platform/android/java/app/config.gradle`; gradle wrapper 8.11.1.
- Godot 4.7.2 mono zip layout verified from the official asset's zip central
  directory: `Godot_v4.7.2-stable_mono_linux_x86_64/GodotSharp/` (API and tool
  assemblies) sits next to the executable. The install step now keeps the
  whole directory in `/opt/godot-4.7.2-mono`, refuses to install if
  `GodotSharp` is missing, and symlinks only the executable.
- Adoptium's official API lists **17.0.21+9** as the newest JDK 17 GA, and
  `actions/setup-java` documents exact version pins (`x.y.z+build`).
- `platform-tools` requirement confirmed in Godot 4.7.2-stable
  `export_plugin.cpp` (`has_valid_export_configuration`): a missing
  `platform-tools` directory or `adb` makes the export configuration invalid.
- CLI flags used by the workflow exist in Godot 4.7.2-stable source:
  `--import`, `--build-solutions`, `--quit-after`, `--export-debug`,
  `--install-android-build-template`.
- Editor settings filename for 4.7 is `editor_settings-4.7.tres` (source:
  `editor_settings.cpp`), and the Android editor settings keys
  `export/android/android_sdk_path` / `export/android/java_sdk_path` exist.
- Workflow YAML parses cleanly (PyYAML `safe_load`), triggers/pins/permissions match design
  (14 steps; all `uses:` pinned to full commit SHAs; only `actions/*`; `permissions: contents: read`).
- XML parses cleanly: `LayerSort.csproj`, `icon.svg`.
- Cross-reference checks: `project.godot` main scene ↔ `Main.tscn` script ↔
  `SpikeBoot.cs`; `export_presets.cfg` contains `com.yoseftext.layersort` and
  `gradle_build/use_gradle_build=false`; `project.godot` uses assembly
  `LayerSort` (matches `LayerSort.csproj`).
- No secrets, tokens, or keystores are present in the diff. Actions pinned by
  commit SHA; `permissions: contents: read` only.
- Forbidden sources (Water Sort reference repository, `SPEC.md`) were not
  read, copied, or referenced.

**Not yet verified (requires the first Actions run):**

- The actual import/compile/smoke/export run, and the APK artifact itself.
- Execution of that APK on an Android device or emulator: out of scope for
  this spike; the workflow validates export only and never installs or
  launches the APK.
- Whether the mono templates `.tpz` contains `android_debug.apk` (there is a
  dedicated fail-fast gate in the workflow; see "Known limitations").
- That the editor-settings flow works on a fresh runner: the workflow now
  lets the pinned editor generate its settings file during the `--import`
  step, then a deterministic patch script upserts exactly the two Android
  path keys and asserts them after writing. A minimal hand-authored
  `EditorSettings` file is kept only as an explicitly reported fallback for
  the case where the editor generated no file; remaining risk (tres format
  details) applies only to that fallback branch.

## 9. Known limitations of Godot .NET Android support

- C# Android (and iOS) export is officially **experimental**; desktop C# is
  stable. C# cannot target the web platform at all (docs, C#/.NET section).
- For Android template exports, the templates only support **TFM net9.0**;
  other TFMs fail validation with an explicit error.
- Android editor settings (`android_sdk_path`, `java_sdk_path`) are user
  settings, not project settings — they must be supplied via the editor
  settings file in CI.
- Debug exports sign with Godot's bundled debug keystore (auto-created);
  production/release signing and AAB for Play still require a real keystore
  (explicitly out of scope for this spike).
- The `dotnet/android_use_linux_bionic` export option exists in 4.7 (advanced
  option; default off) for the Linux-bionic .NET runtime flavor; the spike
  keeps defaults.
- Gradle mode downloads Gradle 8.11.1 and Maven/Google artifacts at build
  time on the runner (network dependency) — only relevant if the fallback is
  used.

## 10. Version-compatibility uncertainties and fallbacks

- **Docs vs. source discrepancy:** the Godot documentation page still lists
  build-tools 35.0.1 / platform 35 / NDK r28b, while the 4.7.2 template
  `config.gradle` requires build-tools **36.1.0**, platform **36**, NDK
  **29.0.14206865**. The workflow follows the template (authoritative for
  building/running the exported APK), but installs both-compatible extras
  (platform-tools, CMake) so either path works.
- **Mono templates Android availability:** template export mode assumes
  `android_debug.apk` exists inside `Godot_v4.7.2-stable_mono_export_templates.tpz`.
  The workflow hard-fails with an explanatory message if it does not, and the
  documented recovery is: set `gradle_build/use_gradle_build=true` in
  `export_presets.cfg`, add `--install-android-build-template` before the
  export in the workflow, and re-run. Nothing else changes.
- **JDK patch is pinned exactly:** Temurin **17.0.21+9** (newest JDK 17 GA
  in Adoptium's official API when this report was written) via
  `setup-java`'s exact-version syntax. The major version stays 17, so Godot
  compatibility is unchanged; an exact pin means security updates require a
  deliberate bump.
- **`platform-tools` is deliberately unversioned.** Godot 4.7.2's desktop
  export validation (`export_plugin.cpp`, `has_valid_export_configuration`)
  requires both the `platform-tools` directory and `adb`, even for template
  exports. `sdkmanager` resolves the current stable package (37.0.1 when this
  report was written), so this single package is not byte-for-byte
  reproducible. It only provides `adb`; APK packaging and signing use the
  pinned `build-tools` and JDK.
- The Linux .NET editor resolves the system .NET runtime via hostfxr; with a
  pinned SDK 9.0.319 installed first, both the editor and the `net9.0`
  project resolve.

## 11. Unresolved blockers

None identified before the first run. The single conditional blocker is the
mono-templates `android_debug.apk` question above, which has a documented,
one-flag fallback path and a fail-fast CI gate.

## 12. Next required action

1. Approve committing the spike to `spike/godot-csharp-android` and pushing it
   (no commit/push was performed without approval, per task constraints).
2. Run: `gh run list --repo Yoseftext/layer-sort` and open the first
   `android-build-spike` run; download `layer-sort-spike-debug-apk`.
3. If the run fails: the logs artifact (`layer-sort-spike-build-logs`) is
   designed to contain the exact failing stage output; attach it and switch to
   the documented fallback if the failure is the template-availability gate.
