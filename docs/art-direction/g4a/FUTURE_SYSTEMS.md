# Future systems — recommendations only, no implementation authorization

## G5 Automatic Layer Circuit

Keep Classic's pure move rules and GameSession boundary intact. Introduce a mode-specific deterministic resolver behind an explicit interface only when the Circuit contract is approved. A user action and all automatic consequences form one atomic committed transition and one undo entry; expose a read-only event sequence for animation. Resolve win after the full chain. Bound chain length and detect repeated states; fail without partial mutation. Obtain owner decisions for topology, trigger order, cycles, color priority, interruptions and whether automatic effects count as moves before coding. Fixture tests should prove deterministic replay and cancellation does not change committed outcomes. Do not infer rules from the unapproved draft contract.

## G6 procedural generation and varied difficulty

Prefer an offline content build pipeline first: versioned seed/config → candidate → structural validator → bounded solver → difficulty features → human review → individually frozen level files. Keep tutorials hand-authored and existing identities immutable. Solver timeout is UNKNOWN, not unsolvable. Record shortest path where proven, explored states, branching, dead-end density, reversibility and color/tube count; shortest move count alone is not human difficulty. Difficulty curves should include recovery/easy beats and short peaks, with per-band variety, rather than monotonically increasing move count. Keep a reviewed manual fallback when budgets fail. No generator, paid service or new runtime dependency in this slice.

## Individual editing and content-version migration

A later editor should validate one level file, preview it in the real renderer, solve it and show diffs before publishing. Identity and content version are separate: change a layout only in a new content version. Preserve old fixture data while old active snapshots exist. Load through `(level_id, content_version)` resolution; route old snapshots to their original fixture or an explicitly approved migration. Never reinterpret old layer indices against a changed palette or erase records because newer content cannot be read. Define whether best results are version-specific before migration. Save schema evolution and content version evolution need separate policies; future unsupported data remains read-only/recoverable, consistent with current save protection.

## Contextual hints after 180 active seconds without interaction

This is separate from the existing 3-second onboarding cue. Recommended clock runs only while foreground gameplay is interactive, excluding Pause, Settings, modal dialogs, animations and app background. Reset on deliberate input, Undo/Restart or level change; owner should confirm whether repeated invalid taps count as engagement. After 180 eligible seconds, offer a quiet optional Hint affordance, never auto-play or disclose a full solution.

A future solver receives an immutable committed snapshot with a request token/state hash and a strict search/time budget. Cache by content version and board identity; cancel on interaction/navigation. Before showing a hint, require matching token/hash and revalidate the proposed move through authoritative rules. Return UNKNOWN when budget expires; do not invent a move or label the state unsolvable. Escalate explanation only on user request; use the same accessible source/target highlights and respect Reduced Motion. Decide hint availability/cost policy explicitly before implementing any reward economy. No hint system is implemented here.
