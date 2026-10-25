# ADR-0002 — Level progression and 20-level Core MVP allocation

- **Date:** 2026-10-25
- **Owner:** Layer Sort project owner (decision provided in this session)
- **Status:** Approved progression and MVP allocation; PR merge and G2 implementation **not** authorized
- **Supersedes:** the level-number ranges in `docs/current/00-START-HERE.md` B09, the Classic-only interpretation of Q05, the G3/G5 level numbers in `docs/current/03-PRODUCTION.md`, and the pending level-count question in `AGENTS.md`/draft rules contract. No other mechanics rules are changed.

## Context

The prior B09 placed Circuit at 20, Frozen at 35, Shift at 50 and Connected at 65, while Q05 specified a 20-level Classic-focused Core MVP and G5 independently taught Circuit at 20. The owner corrected the progression: **levels 1–19 are not nineteen tutorials**. Q05's existing 20-total-level MVP is retained; the owner's new level-15 Circuit introduction means that the MVP must include introductory Circuit levels unless the owner later changes the total count. G3 can no longer claim to finish all 20 levels before G5.

## Decision

| Levels | Approved role |
|---|---|
| 1–5 | Five short interactive **Classic** tutorials. |
| 6–10 | Easy **Classic** puzzles with no mandatory guidance. |
| 11–14 | Progressively harder **Classic** puzzles. |
| 15 | First introduction to automatic **Layer Circuit**, alone and simply. |
| 16–29 | Gradually develop Circuit, alternating with ordinary Classic puzzles; no second new mechanic introduced in this range. Exact per-level sequence/content is a later content decision. |
| 30 | First **Frozen** mechanic, simple introduction. |
| 45 | First **Layer Shift** mechanic, simple introduction. |
| 60 | First **Connected Tubes** mechanic, simple introduction. |
| Later | Progressively combine *previously introduced* mechanics while continuing ordinary Classic puzzles. Introduce only one new mechanic at a time; give each mechanic simple introductory levels before complex combinations. |

**Core MVP = 20 total levels (1–20), not 20 tutorials or 20 Classic-only levels:** 1–14 Classic (tutorials only 1–5); level 15 begins Circuit; 16–20 develop Circuit with ordinary Classic puzzles interspersed. **Gate order:** G2 builds Classic rules/test scene only. G3 prepares UX/persistence and curated Classic 1–14 including five tutorials, not a claim of completed 20-level MVP. G5 proves automatic Circuit with introductory level 15 and enough curated/solvable Circuit-and-Classic content to complete levels 15–20; only after G5 acceptance can the *20-level* Core MVP be called complete. G6/G7 extend later content; Frozen/Shift/Connected start no earlier than their approved introduction levels. This does not accelerate G5 code into G2.

## Consequences and limits

- Update `00-START-HERE.md` B09/Q05 and `03-PRODUCTION.md` G3/G5/G7 and checklist; remove active claims that Circuit first appears at 20. The draft `04-RULES-CONTRACT.md` incorporates this approved progression but its pour, save, serialization, PRNG and test-oracle details remain **unapproved proposals**.
- Level IDs and solver/content versions must not infer rules solely from a numeric index; levels 16–29 include ordinary Classic puzzles. A level declares mechanic set explicitly. No generated/unsolved content or new mechanic combinations ship without the relevant solver, validator, tutorial and owner review.
- `G15-QA-001` remains OPEN as an external-overlay QA issue and does not block planning. PR #1 and PR #2 remain unmerged pending separate review/approval. No gameplay work is authorized by this ADR.

## Rollback

If the owner revises the 20-level release boundary or level schedule, adopt another dated owner-approved ADR and update `00-START-HERE.md` plus all affected active specs. Do not silently revert to the old level-20 Circuit interpretation or change already shipped level IDs without a content/save migration plan.
