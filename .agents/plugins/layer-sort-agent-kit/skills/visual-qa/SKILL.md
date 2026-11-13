---
name: visual-qa
description: Use when reviewing Layer Sort screenshots, visual regression captures, layout, contrast, safe areas, localization, or touch-target evidence.
---

# Visual QA

- Confirm each artifact's source: physical device, CI desktop render, or mockup. Never mislabel it.
- Record path, hash, dimensions, locale, screen/state, app build, commit, and capture source when available.
- Use `tools/qa/qa-visual.py` for deterministic measurements after inspecting its help and source.
- Qualitative review is allowed only when the image is actually visible to the reviewer. Otherwise mark it `UNVERIFIED`.
- Check hierarchy, spacing, contrast, safe areas, clipping, text overflow, Arabic/English layout, color assist, reduce motion, and touch-target clarity.
- Use the 720x1600 reference frame for coordinates where applicable.
- A pixel diff alone does not prove a gameplay defect. Separate objective defects from owner aesthetic choices.
- Never replace approved golden images or modify art as part of an audit.
- Owner approval is required for aesthetic signoff.
