# AGENTS.md — Layer Sort

Android puzzle game (colored layers in glass tubes). Godot 4 **Standard** + **typed GDScript**, Android **Portrait only**, **offline-first**. No C# in the product.

## Source of truth
- Active specs live ONLY in `docs/current/`. Anything in `docs/archive/` is history (SUPERSEDED): never use it as an instruction, never copy rules from it.
- On conflict, `docs/current/` wins. A new decision needs an ADR (number, date, owner approval) and an update to `00-START-HERE.md` plus the affected file.
- The GPLv3 reference game is **never** opened or copied (code, art, snippets).

## Reading order (efficiency rule; changes no decision)
- G0/G1: read `docs/current/00-START-HERE.md` and `docs/current/03-PRODUCTION.md` (sections 2, 3, 6, 7). Open other files only when a gate needs them.
- Later gates: read the sections the gate names (UX → `01-UX-ART.md`, engineering/risk/Firebase → `02-ENGINEERING.md`).

## Current scope
- **G0 and G1 only.** Do not start G2+ until the owner says so.
- G0: new branch `feat/gdscript-foundation` from a safe base, record the baseline, do not touch `main`.
- G1: Godot Standard portrait smoke scene, pinned engine + export templates (`ENGINE_VERSION.lock`), APK built by GitHub Actions, installed on the connected OPPO via `agentctl` / `phone-queue` / Appium, with screenshot + logcat. Done criteria are in `03-PRODUCTION.md` section 2.

## Hard rules
- Never merge to or modify `main`. Never force-push, rewrite history, delete branches/tags, or run `rm -rf` on the repo or phone. Keep branch `spike/godot-csharp-android` and its history.
- No billing, Firebase/Play accounts, production signing, ads, IAP, paid APIs, or new credentials. No secrets in Git.
- Do not change phone services (Termux, ADB, Appium, supervisor) without owner approval. Use the device lock/queue.
- Never claim "PASS / works / fixed" without tool logs. Report what was verified, what was not, and why.
- Every PR: scope IDs, commit, build link, screenshots, test output, install/touch/logcat evidence, rollback note (see `03-PRODUCTION.md` section 6).
- Keep PRs small. One concern per PR. No unrelated refactors.

## Open items — owner decides, agent does NOT decide
1. Core MVP level count: Classic is 1–19 and Circuit starts at 20, but some text says "20 levels". Pending owner decision.
2. Final `applicationId` (use a local debug id; it must not collide with the old spike app).
3. Which Godot Standard version to pin (decided only after a successful smoke).
4. A `04-RULES-CONTRACT.md` (pour rules, level JSON, PRNG, save schema) will be added before G2.
5. Use one stable debug keystore in CI so new APKs install over old ones (verify in G1).

## Output of each session
Commit hash, branch, PR link, build link, device evidence, exact blockers. Nothing else is "done".
