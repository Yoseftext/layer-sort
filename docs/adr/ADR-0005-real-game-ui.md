# ADR-0005 — Real Game UI refinement

Date: 2026-11-03. Owner: Layer Sort owner, explicit Real Game UI instruction. Status: approved bounded implementation, visual acceptance pending.

Base PR #14 `feat/g4b-optical-clarity`, commit24809327f45f0d7ee4633e67456a03def74471a4. The owner authorized a real Home hero with one dynamic Play action and compact Map/Settings, About inside Settings with origin-aware Back (including Pause), icon gameplay controls, and Win with no X, primary Next and secondary Replay/Map. These are presentation/navigation refinements, not a new game mechanic.

This supersedes UX02's old separate Home About entry and expands ADR-0004's one-screen-only implementation gate specifically to these named surfaces. AGENTS' old G2-only scope described an earlier gate and is corrected to reference the later owner scope. Existing historical test reports and decisions are not rewritten.

Original vector glyphs retain localized accessible names, tooltips, focus and minimum96reference-pixel touch regions. Home/Win use the already licensed Optical font pair. Android Back retains explicit route semantics. About from paused Settings is an overlay returning to the same Settings object without replacing gameplay. Normal About returns Settings, then Home. Win uses a borderless embedded window with its primary/secondary actions; a visual dimmer clarifies modality.

No engine, renderer, package/signing, saves, campaign content, domain rules or audio framework changes. G5/G6, production release, physical-phone mutation and merging remain unauthorized in this slice. Owner reviews real renders and Android-only checks before acceptance.
