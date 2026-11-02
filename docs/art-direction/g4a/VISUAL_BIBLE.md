# G4-A — three directions, owner selection required

Status: DESIGN PROPOSALS, NOT APPROVED, NOT INSTALLED IN GODOT. These SVG/PNG boards are original vector mockups, not screenshots. Home/gameplay/victory are shown on every board. Source SVG and `tokens.json` are editable. Image-generation service returned usage_limit_reached; these designs were authored as vector compositions and rendered with the existing librsvg/Cairo libraries (Chromium screenshot attempts stalled; no new dependency was installed). No downloaded artwork or generated-image licensing assumption.

The current real captures are useful functional proofs, but do not establish premium art acceptance. Their dominant uniform panels, thin uniform glass strokes, weak material hierarchy and typography without a deliberate Arabic/Latin pairing explain the owner's assessment. A successful build or vector mockup does not close this gap. Review against approved UX01–UX36, especially Calm Laboratory/Living Layers, nonmirrored tube sequence, accessible color differentiation, restrained motion and honest rewards.

## A — Porcelain Daylight

[Board](A-concept.png) · [editable SVG](A-concept.svg)

An airy precision laboratory: warm ceramic work surface, sea-glass vessels, etched calibration and long diffuse contact shadows. Home uses an editorial title and a small sculptural glass still life. Gameplay is one orderly row on a bench, with a quiet HUD and separated thumb actions. Victory is an engraved single earned star and a restrained row of sorted vessels, not a shower of invented rewards.

Materials: narrow glass with double lip and a thicker rounded heel; subtle vertical reflected window, clean meniscus, saturation concentrated inside liquid. Lighting: one broad upper-left daylight source, no moving background. Ivory/teal UI with coral, jade, amber and slate-violet liquids; UI panels mostly disappear into the canvas. Rounded corners 18px reference, thin dividers and generous 24–48px spacing.

Typography: Manrope medium for Latin, Noto Sans Arabic regular/semibold for Arabic. Keep Arabic body line height about 1.5 initially and validate actual font metrics in Godot. Numbers stay stable LTR; Arabic labels follow RTL. Preview boards use host fallback, not these unshipped font binaries.

Implementation: lowest complexity, original SVG/atlas highlights plus existing CanvasItem liquid masks; one baked shadow per tube. Low tier uses a single reflection and no animated ambient effect. Main risk: transparent glass contrast on light canvas; maintain dark rear contour and distinct shape marks. Expected relative cost low, NOT a measured OPPO benchmark.

## B — Optical Nocturne

[Board](B-concept.png) · [editable SVG](B-concept.svg)

A dark optical instrument gallery: smoked glass, a large geometric halo and a recessed display plinth. Home is a luminous glass exhibit, gameplay sits within the optical ring, victory reads like a curated specimen award. This is deep ink and directional rim lighting, not a recolor of the daylight bench.

Materials: thick shoulder/lip, opposing cyan-white rim and subdued inner wall, saturated floating color bands. Background is almost black with a single static radial light. Lime accent for actions, muted pale labels, 36px reference radii. Avoid neon outlines around every control and avoid live bloom.

Typography: the same licensed pair can establish consistency, with wider Latin heading tracking and compact semibold Arabic headings; never apply Latin tracking blindly to Arabic. Victory uses larger dramatic negative space.

Implementation: medium complexity. Prebaked radial light/edge atlas, two bounded highlight layers. No screen-reading refraction, blur or realtime lights. Risk: OLED-like reference imagery can become muddy on the OPPO LCD and overdraw can erase the presumed cheapness of 2D. Evaluate contrast at low brightness; premium appearance must survive the low tier.

## C — Living Conservatory

[Board](C-concept.png) · [editable SVG](C-concept.svg)

A botanical research conservatory: frosted rounded vessels with narrow necks, sage ceramic, tactile paper labels and broad organic canopy shapes. Gameplay uses two staggered rows instead of the linear bench. Home is a gentle specimen collection; victory resembles a botanical field label. No plants or extra gameplay mechanics are implied by the decorative background.

Materials: diffuse frosted side walls, soft shoulder transitions, calm broad highlights; liquid colors slightly earthier but still distinguishable by shape marks. Background uses one original organic silhouette, not photographic foliage. Large soft radii and pill controls with dark green type. Warm paper/olive/jade/terracotta/ochre palette.

Typography: Noto Sans Arabic with Manrope, soft medium weights and relaxed hierarchy. No decorative Arabic script for small controls. A later editorial display font requires a separate exact license/font proof.

Implementation: medium-high complexity: new silhouettes/masks, two-row trajectories and hit-target spacing need real prototypes. Baked frosted highlights only; no dynamic noise, translucent foliage stacks or 3D vegetation. Main risk: curvy vessels obscure capacity and make tilt/stream geometry harder; retain explicit four-layer readability and test both rows before production.

## Comparison scorecard

Art-director estimates, 1 weak to 5 strong; not measured performance or user preference. Equal weighting is intentional rather than invented statistical precision.

| Criterion | A | B | C |
|---|---:|---:|---:|
| Calm Laboratory identity | 5 | 4 | 4 |
| Immediate puzzle readability | 5 | 4 | 4 |
| Distinctive material potential | 4 | 5 | 5 |
| Low-end implementation confidence | 5 | 4 | 3 |
| Arabic/English hierarchy flexibility | 5 | 4 | 4 |
| Production simplicity | 5 | 4 | 3 |
| Total /30 | 29 | 25 | 23 |

Recommendation: **A, Porcelain Daylight**. Its clear material hierarchy offers the best route away from prototype panels with the lowest rendering risk. B is the stronger dramatic alternative; C is the most organic but needs more geometry/animation work. This recommendation is NOT owner approval. Stop here for A/B/C selection or a precisely scoped combination before G4-B.

## Editable tokens and component contract

`tokens.json` carries each palette, radius and shared spacing/motion values. These are proposed reference pixels at 720 wide, not Android dp. Enforce ≥48dp-equivalent hit targets with the device's actual density. Preserve safe-area margins; do not scale a screenshot to build a UI.

| Component | Proposed specification |
|---|---|
| Primary action | one dominant action, full readable level label; normal/pressed/focus/disabled states; 120ms response |
| Secondary action | text/icon with clear contrast; never same emphasis as Next/Play |
| Tube | separate glass outline, liquid mask, meniscus and optional reflection; shape marks independent of hue; hit box outside visible glass without overlap |
| Selected tube | 6–10 reference px lift and outline; reduced motion uses outline/short fade |
| Pour | authoritative state stays outside renderer; bounded lip trajectory/stream; no screen texture refraction |
| Victory | actual earned stars only; Next primary, Map/Replay secondary; final-content explicit replay/map behavior |
| Dialog | opaque-enough panel, readable body, same focus styles, background input blocked |
| Typography | title 32–40 reference px, controls 24–28, body 22–26; prove AR metrics and 1.5 line spacing before final sizing |
| Color assist | consistent dot/shape identity plus hue; never rely on colored text alone |
| Quality | low: baked light + one reflection; high optional second reflection; no new full-screen shader pass |

Proposed art budgets to validate: one 1024² UI/glass atlas first (roughly 4MiB uncompressed RGBA before mip overhead), one modest baked background, no particles on low tier, no real-time 3D. These are planning ceilings, not measured allocations or a license to change export/ABI. Track actual APK delta and Android memory after implementation. Keep existing Compatibility renderer.

G4-B acceptance after selection: sliceable original assets, exact font binaries/licenses, one representative Godot gameplay scene in AR/EN at 720×1600 and narrower portrait, real selection/pour/win captures, OPPO low-tier sustained playback/audio/latency/contrast test. Mockups alone do not satisfy any of those gates.

Resume validation: solid-color text pairs in `contrast-check.json` now meet at least 4.5:1 after darkening A's secondary text and C's secondary text/action fill. This does not certify text on gradients, full accessibility, or device rendering. The original boards were retained in session evidence where available; only proposed tokens/previews changed, no game UI changed.
