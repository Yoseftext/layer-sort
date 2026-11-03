# Layer Sort — Shizuku → Termux → Agent Integration

**Scope:** Manual first-time authorization plus agent-audited diagnostics. Android 11 OPPO, Termux native + Debian proot, existing ADB/Appium. Shizuku is optional. It is not root and it is not required for G2.

## What Shizuku can and cannot do
- Shizuku can provide a privileged Android **shell** via exported `rish`; it is not a free root shell when started by Android Wireless Debugging. Check actual identity with `id` (commonly uid=2000 shell).
- `rish` runs from the **Termux Android app sandbox**, not automatically inside Debian proot. Existing ADB/Appium remains the primary test interface.
- Shizuku may stop on reboot and must be started again. Do not blindly persist or secretly auto-start privileged commands.
- Granting Termux access also means processes running in Termux can invoke it. Authorize only if you trust the agents/code running there. Never expose arbitrary `rish` command execution to child agents or network endpoints.

## Manual bootstrap (on phone, before running shell commands)
1. Launch **Shizuku** and verify its service is **running**. On Android 11, pair/start it following the app's Wireless Debugging instructions if needed.
2. In Shizuku choose **Use Shizuku in terminal apps** → **Export files**. Export the official files `rish` and `rish_shizuku.dex` into a known folder such as `Download/Shizuku`.
3. If Shizuku prompts you to authorize a terminal app, approve **Termux** only. Exact screen wording may vary.
4. Verify files exist in the chosen folder before trying the example commands below.

## One-time setup in Termux **native** (`~ $`), NOT inside Debian

The following commands assume Shizuku exported **both files** into `Download/Shizuku`, and Termux shared-storage access exists. If path differs, change only these two source paths.

```bash
ls -l "$HOME/storage/downloads/Shizuku/rish" "$HOME/storage/downloads/Shizuku/rish_shizuku.dex"
mkdir -p "$HOME/.local/share/layersort-rish"
cp "$HOME/storage/downloads/Shizuku/rish" "$HOME/.local/share/layersort-rish/rish"
cp "$HOME/storage/downloads/Shizuku/rish_shizuku.dex" "$HOME/.local/share/layersort-rish/rish_shizuku.dex"
chmod 700 "$HOME/.local/share/layersort-rish/rish"
chmod 400 "$HOME/.local/share/layersort-rish/rish_shizuku.dex"
RISH_APPLICATION_ID=com.termux "$HOME/.local/share/layersort-rish/rish" -c 'id'
```

If `~/storage/downloads` does not exist, use the legitimate Termux shared-storage setup (`termux-setup-storage`) **with your consent**, and check the actual exported path. Do not run unknown third-party installer scripts or use a generic "root enable" guide. If `Permission denied`, `Shizuku not running`, `Not authorized`, or `dex missing` appears, capture that output and solve that exact issue; do not broadly reinstall anything. The official exported `rish` script uses `RISH_APPLICATION_ID` to identify `com.termux`, and expects the DEX adjacent to it. See official Shizuku `rish`/Shizuku-API resources below.

## Optional read-only smoke

```bash
RISH_APPLICATION_ID=com.termux "$HOME/.local/share/layersort-rish/rish" -c 'getprop ro.build.version.release'
```

Expected first command: shell identity if Shizuku was started via Wireless debugging; successful result **must be seen**, not assumed. Don't post raw device dumps that contain private identifiers.

## Bridging Debian / OpenCode
The primary agent must inspect the existing Debian ↔ Termux integration and propose a **small fixed-command native wrapper** (e.g., `status`, `app-meminfo`, `foreground`, `package-path`) with allowlisted package name `com.yoseftext.layersort.dev`. It must prove that the wrapper works under the current process model, respects `phone-queue` exclusivity, and logs the invocation. No `eval`, arbitrary command interpolation, persistent privileged daemon, or root-like claim. Approval is required before creating a permanent privileged bridge. If unavailable, continue with ADB/Appium as usual.

## Upstream references
- Shizuku rish implementation: https://github.com/RikkaApps/Shizuku/blob/master/manager/src/main/assets/rish
- Shizuku-API rish help: https://github.com/RikkaApps/Shizuku-API/blob/master/rish/README.md
- Shizuku project: https://github.com/RikkaApps/Shizuku

## Current gate reconciliation — ADR-0006

See [00-START-HERE.md](00-START-HERE.md#current-accepted-checkpoint--2026-11-03) for the accepted PR15 checkpoint and owner-reported 10/10 device QA. Earlier gate-specific instructions are historical scope, not permission to restart those gates. Current task is CI/documentation/merge readiness only; no gameplay, phone operations, merge or G5 implementation. Shizuku is optional; the bootstrap commands above are reference material, not authorization to alter services or enable a bridge.
