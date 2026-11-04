---
description: Deterministic + qualitative review of actual device screenshots
agent: visual-auditor
subagent: true
---

Review actual device screenshots for G1.5.

Inputs: $ARGUMENTS (one or more PNG paths; default to the latest smoke run screenshot if empty).

1. Run `python3 tools/qa/qa-visual.py --help`, then run the deterministic checks on each PNG (size, orientation, brightness, colour count, safe area, black-screen detection, optional golden diff).
2. Use the `read` tool on each PNG to perform a qualitative review **only if the image is actually visible to you**. If it is not, mark the qualitative section `UNVERIFIED` and say exactly why.
3. G1 smoke images are placeholders, not final art: label aesthetic opinions `OWNER_REVIEW_REQUIRED`.
4. Report findings with coordinates in the 720×1600 frame, severity, and a concrete suggested adjustment.
