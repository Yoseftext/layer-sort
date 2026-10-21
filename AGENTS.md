# AGENTS.md — Layer Sort

## Project
Layer Sort: an Android game written in C#.
Game engine: NOT decided yet. Do not pick one or add engine files without asking.

## Environment
- Code is edited locally on a phone (Termux, Debian proot).
- Heavy builds and tests run on GitHub Actions, never on the phone.
- Repo: Yoseftext/layer-sort (private). Branch: main.

## Rules
1. Inspect the folder before changing anything.
2. Make small, focused changes. No unrelated refactoring.
3. Never invent files, APIs, or test results.
4. Never print, log, or commit tokens, keys, or secrets.
5. Never run destructive commands (rm -rf, force push, deleting repos) without asking first.
6. Do not claim "fixed" or "working" unless you verified it. Say what was and was not verified.
7. Commit with clear messages, then push.
8. To check a build: gh run list --repo Yoseftext/layer-sort

## Done means
Requested behavior exists, nothing else broke, and remaining uncertainty is reported.
