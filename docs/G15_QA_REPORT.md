# G1.5 QA evidence — 2026-10-25

**Branch:** `feat/agent-qa-orchestration`, based on G1 commit `f85172c`.
**Scope:** agent/QA tooling only; no game mechanics or new phone services.
**PR #1:** open/unmerged at `f85172c` when inspected.
**Tested APK:** G1 CI [40102066642](https://github.com/Yoseftext/layer-sort/actions/runs/40102066642), source `5905e76`, SHA-256
`0b118493c17f4e86dad582bda1dbb967ae7d0f526ed4ead44c092da26421a41e`.
Android: OPPO CPH1937, API 30, 720×1600. G1.5 scripts are tested
independently of the G1 app; this is **not** G2 gameplay evidence.

| Test ID | Status | Observed evidence |
|---|---|---|
| ENV-01/02/04, SEC-04 | PASS | OpenCode 2.1.4, Python 3.13.5, ADB connected, >1 GiB free, protected refs equal origin; `/tmp/opencode/g15-env-2/report.json` |
| ENV-03 | PASS | Existing `agentctl status`: Appium and services running; endpoint redacted |
| ENV-05 (Shizuku rish) | UNVERIFIED | Shizuku app installed; `shizuku_server` process visible; exported `rish` and DEX present in Termux downloads; no Termux-native copy or successful `rish id`; owner authorization required |
| DEV-06 | PASS | `qa-apk-provenance`: downloaded CI artifact SHA-256 exactly matches supplied APK, CI run successful at `5905e76`, cert `de1faa3e…095e`, portrait, arm64, no C# payload |
| DEV-01 (before reinstall) | FAIL | `pm path com.yoseftext.layersort.dev` returned no package despite existing G1 evidence: `/tmp/opencode/g15-provenance/report.json`. Failure was correctly reported, not reused as PASS. |
| DEV-01 (after reinstall) | PASS | `agentctl install` succeeded and installed APK pulled back under the shared lock matches CI SHA-256 exactly; `/tmp/opencode/g15-smoke/provenance/report.json`. |
| DEV-02 smoke | PASS | `/root/device-tests/agent-runs/20261025-041319-17057-g15-smoke/status.json`, READY, PORTRAIT, game foreground, nonblack screenshot, no fatal/script lines. |
| DEV-03 touch first attempt | FAIL | `/root/device-tests/agent-runs/20261025-041347-17631-g15-touch/status.json`: before screenshot showed Chrome/OpenCode (not game); after screenshot displayed `Taps: 1`, but captured logcat had READY only, no TAP marker. The strict test timed out rather than false PASS. The before screenshot is **not** committed because it shows unrelated user UI. |
| DEV-03 touch bounded recheck | PASS | `/root/device-tests/agent-runs/20261025-042421-21103-g15-recheck-touch/status.json`: (360,800), TAP 1 in logcat, before/after crop changed and visible `Touch verified / Taps: 1`. Do **not** erase the first FAIL. |
| DEV-04 runtime | PASS | `/root/device-tests/runs/20261025-041625-19110/status.json`: 35 s, 5 ticks, PID stable, portrait; existing locked `agentctl runtime 30`. |
| NEG-01/02/03 | PASS as negative-suite result | `/tmp/opencode/g15-negative/NEG-0{1,2,3}/report.json`: each wrong package, wrong orientation, wrong hash produced a real `FAIL` and nonzero exit. No phone mutation. |
| VIS-01/02/09 | PASS deterministic only | Real device screenshot 720×1600, mean 44.74, 259 sampled colours, identical baseline diff 0 pixels; wrong golden produced `FAIL`, 85,306 changed pixels. `/tmp/opencode/g15-fresh-visual/report.json` and `/tmp/opencode/g15-visual/report.json`. |
| Local oracle tests | PASS | `python3 tools/qa/test_qa.py -v`: 4 tests ran, 0 failures. |

## Visual review — actual OPPO screenshot

I opened and visually inspected the **actual** 720×1600 screenshots from the
G1.5 smoke and touch runs with an image-capable `read` tool (not just file
metadata). See [smoke](evidence/g15/smoke.png) and
[touch-after](evidence/g15/touch-after-failed-marker.png). The screenshot is
the G1 placeholder, **not** the approved G3/G4 production art.

- **Hierarchy:** strong title at about (247,154)–(475,194); subtitle centered
  near y=235; main cyan button spans approximately x=59–661, y=751–891 and
  is conspicuous and comfortably larger than a 48dp touch target.
- **Spacing:** the card spans about x=30–690, y=641–1100. Large empty area
  from subtitle to card supports smoke simplicity but would waste space in
  gameplay. P3/owner review for later screens, not a G1.5 code change.
- **Legibility:** cyan button/near-black text is high contrast; small footer
  around y=1541 and hint around y=1008 are noticeably less legible than the
  primary action. P2 **future accessibility test**: verify text sizes and
  contrast on the actual G3 screens, with font/locale data. No measured WCAG
  ratio is claimed from this image alone.
- **Safe area:** title and button do not appear clipped on this 720×1600 OPPO
  capture; the bottom footer appears close to the lower edge but visible.
  Notch variants and RTL Arabic are **UNVERIFIED**; do not infer from this
  English-only screenshot. Owner aesthetic approval is required.
- **Touch finding:** the first failure's *before* frame showed Chrome, proving
  a focus race; the after frame was the G1 app with updated counter. This is a
  test/infrastructure finding, not evidence of a pour-rules bug.

**Cannot judge from still images:** animation/frame pacing, screen-reader
semantics, Arabic layout, sound, actual glass/liquid art, or colour perception
under other device profiles.

## Actionable QA bug — G15-QA-001 (P2)

- **Expected:** touch test verifies game foreground immediately before
  `mobile: clickGesture`, then sees TAP marker and changed status region.
- **Actual:** first run captured Chrome before tap and game after; marker was
  absent in captured logcat, so the test failed after 20 s. A bounded recheck
  passed. One possible cause is another app taking focus during Appium
  activation; logcat buffer/focus timing remains a hypothesis, not confirmed.
- **Reproduce:** install the verified G1 APK through `agentctl`, open the
  OpenCode browser on the phone, run `agentctl touch g15` under the shared
  lock; inspect `before.png`, `after.png`, `status.json`, and `logcat.txt`.
  The race may be intermittent.
- **Evidence:** run directories above; do not share first `before.png` because
  it contains unrelated personal/browser content.
- **Ownership / follow-up:** owner approval is needed before modifying the
  existing `agentctl`/Appium script. Proposed regression: assert foreground
  package and screenshot game identity *before* tap, fail with explicit
  `foreground mismatch` instead of waiting for a marker. Then rerun a bounded
  focus-steal fixture and normal tap check. **Not fixed in this PR.**

## Subagent runtime / provider timeout

- OpenCode CLI and service API reported `2.1.4`. V2 project agents use
  `.opencode/agents/*.md` with `mode: subagent`, ordered `permissions`, and
  `experimental.subagent_depth=1`. No model override or custom timeout exists
  in project or global JSONC; agents inherit the parent `openai/gpt-6-sol`.
- First `repo-auditor` call (`ses_e8f829f11ffeaVct7O4896U0Hl`) failed at
  **2026-10-25 01:07:08Z** with `AI.Error.Transport: Timed out waiting for
  response headers` in `~/.local/share/opencode/log/opencode.log` (log
  preserved outside Git). The diagnostic line has no permission/config
  denial. Provider DNS later resolved; this does **not** prove authenticated
  provider stability.
- One minimal controlled retry (`ses_e8f4e5342ffeMqiGTwiF0TY1if`) **succeeded**:
  `repo-auditor` returned branch `feat/agent-qa-orchestration`, HEAD `315d15f`,
  and untracked `.opencode/`. This validates discovery/invocation and reduces
  the likelihood of a persistent agent-schema or permission failure.
- `device-qa`, `visual-auditor`, and `reviewer` agent *runtime calls* were not
  tested in this session: **UNVERIFIED**, not claimed working. Their files and
  permissions are statically checked by CI. No model/provider switch, paid
  subscription, or global credential/config change was made.

## Shizuku status: NEEDS_OWNER_AUTH

`moe.shizuku.privileged.api` is installed; `shizuku_server` is running.
Termux downloads contain `rish` (882 bytes) and `rish_shizuku.dex` (59,672
bytes); target `$HOME/.local/share/layersort-rish/rish` is missing. Termux
permission is **not verified** and `rish -c 'id'` was **not run**. No bridge
exists; Android Wireless Debugging usually yields `uid=2000(shell)`, not root,
but we do not infer actual identity without the command output.

Manual owner steps (native Termux `~ $`, not Debian proot):

1. Open Shizuku; if stopped, pair/start using its Android 11 **Wireless
   debugging** instructions. In **Authorized applications**, authorize only
   Termux if prompted. Do not authorize unknown apps.
2. In Shizuku choose **Use Shizuku in terminal apps → Export files** and export
   the official `rish` and `rish_shizuku.dex` to `Download/Shizuku`. The two
   source files already appear present; verify they came from the app.
3. In Termux native, run:

   ```sh
   ls -l "$HOME/storage/downloads/Shizuku/rish" "$HOME/storage/downloads/Shizuku/rish_shizuku.dex"
   mkdir -p "$HOME/.local/share/layersort-rish"
   cp "$HOME/storage/downloads/Shizuku/rish" "$HOME/.local/share/layersort-rish/rish"
   cp "$HOME/storage/downloads/Shizuku/rish_shizuku.dex" "$HOME/.local/share/layersort-rish/rish_shizuku.dex"
   chmod 700 "$HOME/.local/share/layersort-rish/rish"
   chmod 400 "$HOME/.local/share/layersort-rish/rish_shizuku.dex"
   RISH_APPLICATION_ID=com.termux "$HOME/.local/share/layersort-rish/rish" -c 'id'
   ```

4. Share only the `id` result or the exact error (redact private identifiers).
   If `$HOME/storage/downloads` is missing, decide whether to run
   `termux-setup-storage` yourself; it requests Android storage permission.
   No persistent privileged bridge will be made without separate approval.

## Rollback / gate

Close or revert the stacked G1.5 PR to remove project-scoped `.opencode/`
agents/config and `tools/qa/`. Existing G1 CI, `agentctl`, `phone-queue`,
Appium, ADB, `main`, and C# spike branch are unchanged. APK was installed
under the existing queue; no system settings or services were changed.

**Owner review required:** approve ADR-0001 and G1.5 PR for merge; decide
whether to authorize a separate Appium focus-race fix and optional Shizuku
bridge. G2 remains unauthorized.
