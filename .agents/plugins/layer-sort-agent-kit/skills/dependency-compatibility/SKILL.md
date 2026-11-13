---
name: dependency-compatibility
description: Use before proposing any new SDK, CLI, library, plugin, MCP server, scanner, build tool, or global package change for Layer Sort.
---

# Dependency and Tool Compatibility Gate

Do not install or enable anything. Produce a recommendation first.

For every candidate, verify:

1. Concrete project requirement — what current failure or task does it solve?
2. Official upstream documentation and release source.
3. License and redistribution obligations.
4. CPU architecture support: the owner environment is Debian 13 ARM64 inside Android PRoot.
5. Android/device compatibility where relevant: OPPO CPH1937, Android 11, ARM64.
6. Runtime requirements, native binaries, Node/Java/Python versions, memory, disk, and network needs.
7. Pinning and integrity: exact version, signed release/checksum, package lock, or reproducible source.
8. Attack surface: shell execution, filesystem scope, credentials, network access, telemetry, and MCP permissions.
9. Isolated project-local installation option, a minimal smoke test, and rollback.
10. Whether owner approval is required under `docs/current/04-AGENT-OPERATIONS.md` and root `AGENTS.md`.

## Known environment baseline (owner-reported 2026-11-07)

- Debian 13.7 / ARM64 / Android PRoot
- Godot 4.7.2 local binary; Java 21.0.13; Node 24.22.0; Python 3
- Android CLI 1.1.16717390; ADB 34.0.5; Appium 3.8.0; UiAutomator2 8.7.0
- Gradle, Flutter, Dart, Docker, and Podman were not found
- The local Android SDK package list showed platform 30 and Build Tools 29.0.3
- `ENGINE_VERSION.lock` requires compile SDK 36 and Build Tools 36.1.0 for the authoritative CI export
- CI uses an x86_64 Linux Godot archive; the local environment is ARM64

Re-check only the compatibility facts relevant to a proposed change. Do not repeat a full environment audit without a reason.

## Default decisions

- Prefer existing tools and GitHub Actions.
- Do not install Flutter/Dart for a Godot project.
- Do not install Gradle, Docker, Podman, emulators, or security scanners without a demonstrated requirement.
- Do not add MCP servers unless a concrete missing capability requires one.
- Never use `curl | sh`, unpinned `npx`, or unknown binary installers.
- Record accepted tools in `tools/inventory.md` with purpose, version, source, license, pin/hash, architecture, risk, test, rollback, and owner-approval status.

Return `COMPATIBLE`, `NOT_COMPATIBLE`, or `UNVERIFIED`. Unverified is not approval to install.
