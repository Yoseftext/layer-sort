# G5-Final — Visual & Audio Polish Proposal

**PROPOSAL ONLY — OWNER REVIEW REQUIRED.** Baseline: existing Draft [PR #19](https://github.com/Yoseftext/layer-sort/pull/19), `8f3a49c1f84a982da060a06f9d47df02f249d0f3`. No visual/audio implementation, assets imported into the project, dependency, gameplay or export change is authorized by this audit. G6 remains unauthorized.

## 1. Acceptance and evidence boundaries

The owner reports accepted Android QA: **P1 12/12 PASS, P2 13/13 PASS, P3 12/12 PASS**. The P3 report supplies the aggregate result, not twelve named groups; none are invented here. These are OWNER-REPORTED PHYSICAL DEVICE QA results, not agent-operated testing, logcat inspection or instrumented performance benchmarks. Keep the detailed [P2 acceptance record](G5_P2.md#owner-reported-physical-device-qa-acceptance--2026-11-04) and [P3 implementation evidence](G5_P3.md).

Reviewed current source: `tube_painter.gd`, `tube_view.gd`, `pour_trail.gd`, `circuit_overlay.gd`, `optical_theme.gd`, Home/Map/Classic/Win scripts, `game_audio.gd`, procedural audio source, credits and exact font licenses/provenance. Relevant scenes and constraints are described in [Optical Clarity](G4B_OPTICAL_CLARITY.md) and [approved UX/art](current/01-UX-ART.md). This proposal refines the approved unified Optical Clarity direction; it does not authorize a new identity.

Evidence actually inspected:

- [Historical real Godot narrow Arabic render](evidence/g4b-optical/after/narrow-6-ar.png) and [sampled pour frame](evidence/g4b-optical/after/pour-1.png). These show the earlier G4 implementation. Their text Home/Pause buttons are historical: current source uses icons, so they are **not** evidence of a current text-button defect.
- Current [CI41820563737](https://github.com/Yoseftext/layer-sort/actions/runs/41820563737) and its [real renders/verbose logs](https://github.com/Yoseftext/layer-sort/actions/runs/41820563737/artifacts/13317781022), including `g5-p3-screenshots/fresh19-600-ar-initial.png` and unlocked/Undo variants. The last corrective slice passed322 graphical checks and removed the P3 test's win-audio teardown leak. Artifact-storage access from this cloud session previously returned HTTP403; these current PNGs were **not independently viewed in this audit**. Do not reopen the repaired indicator defect as if it remains broken.
- Official competitor store screenshots were opened and visually inspected as marketing references, not installed/running competitors. No competitor animation timing, audio, GPU, memory, accessibility, monetization flow or retention was tested.
- Existing WAV format/duration/byte sizes were measured from repository files. No speaker/headphone audition or Android loudness assessment occurred; naturalness and subjective mix quality remain UNVERIFIED.

Evidence codes below: **C** current source/geometry; **H** inspected historical Godot image; **R** inspected official reference screenshot; **V** needs current rendered/owner validation. A proposal is not a verified defect or a measured improvement.

## 2. Current visual and UX audit

| Area | Observed evidence / weakness | Proposed correction and guardrail | Priority |
|---|---|---|---|
| Glass silhouette | C/H: original vector contours, double rim, heel and vertical reflections already provide depth. Several near-parallel strokes compete at small widths. | Compare fewer, hierarchically weighted strokes; keep one dominant outer contour and restrained inner wall/reflection. Preserve tube geometry and touch bounds. | Next |
| Liquid | C/H: flat base colours plus lateral attenuation and per-layer elliptical surfaces. Every boundary gets a highlight, making interfaces resemble stacked discs rather than continuous liquid. | A/B compare stronger top meniscus with quieter internal boundaries; retain crisp colour separation and readable markers. No real-time refraction. | Next |
| Colour assistance | C: fixed dot positions `12 + dot * 7`, radius2.3. At600 width/six tubes, existing layout gives about75.33px per tube, liquid region33.33px wide; colour-index4's last dot reaches42.3px from its left edge. This exceeds the liquid region mathematically. Current screenshot impact needs V. | First reproduce on actual current5-colour narrow content. Fit dots in a bounded grid or use six stable distinct symbols, with a single consistent sensor/liquid legend. Never remove non-colour differentiation to make the image cleaner. | **Now** |
| Pour material | C/H: source and liquid rotate as one rigid layered ghost; depletion/fill share normalized transfer progress. The tilted surfaces do not remain gravity-level. | Prototype a lightweight clipped 2D surface adjustment on the existing ghost; no fluid physics or new authoritative state. Keep one commit and current Undo/input rules. Reject if layer meaning becomes ambiguous. | Next |
| Selection/rejection | C: selected lift is9 reference pixels; bounded invalid/completion feedback exists. | Review readability at low brightness and6 tubes; strengthen a local edge/contrast change before increasing motion or glow. No lock-duration/input-buffer changes in a polish batch. | Now review; Next change |
| Circuit | C: repaired transform/layout invalidation; ring uses target colour plus numeric symbol, gate open/closed indicator and thin line. | Preserve accepted attachment and state. A/B test lock/check silhouette and line contrast on dark LCDs; unify target symbol with liquid assistance. Do not add constant pulses or status visible only by colour. | Now review; Next change |
| Board composition | H: calm navy and ample negative space, but the board can feel visually small relative to its margins. Current icon/HUD composition differs from H. | Review current3–6 tube captures before changing spacing. Adjust presentation spacing/tokens only if a current imbalance is confirmed; preserve pour travel room and safe-area clearance. | Next, conditional |
| HUD/buttons | C: original line icons, localized accessibility names and96-reference-pixel control targets; typography uses licensed Manrope/Arabic fallback. | Standardize stroke, optical size and disabled/focus/pressed contrast across screens. Retain labels for assistive access. Validate physical dp separately from reference pixels; do not assert every tube is48dp merely because a screenshot is600px. | Now audit; Next polish |
| Home | C: one current-level Play action, compact Map/Settings and original glass hero already exist. | Refine brand spacing, hero light and action contrast; preserve one dominant CTA and real resume semantics. Do not restore a redundant Continue button. | Next |
| Map | C: responsive three-column maximum, chronological LTR sequence, explicit states, touch-scroll protection,60-item page cap. Buttons use tall text cards with status and star. | Propose a restrained tile component with a clear number/star/current indicator and familiar Classic/Circuit badge; retain tap-vs-drag, lock readability and page cap. No chapter/currency promise or new screen flow. | Next |
| Victory/progression | C: primary Next, compact Replay/Map, final-level Map fallback; bounded badge animation. | Improve spacing/light/focus hierarchy and transition consistency. Preserve final20 behavior, no21 and duplicate-win guard. Avoid extra reward counters, popup layers or forced celebration delay. | Next |
| Transitions | C: existing Tweens and Reduced Motion path; no permanent ambient loops required. | Centralize easing/duration tokens for presentation only after measuring current timings. Keep pause/focus cancellation and navigation input isolation. | Next |
| Background | C/H: quiet optical arcs/bench line on navy, deliberately subtle. | First verify visibility on the owner's LCD. If needed, rebalance static contrast rather than adding bloom, motion, blur or textured noise everywhere. | Next, conditional |

Acceptance by the owner remains valid. The material and composition items above are polish opportunities, not reopened gameplay failures.

## 3. Competitive comparison — references, not assets

Reviewed2026-11-04. Store images may differ from current runtime and may be marketing composites. Their artwork is not licensed for Layer Sort reuse; no copies are shipped or included in this repository.

| Reference and source | What was actually visible | Transferable lesson | What Layer Sort should avoid / uncertainty |
|---|---|---|---|
| [Water Sort Puzzle — IEC Global](https://play.google.com/store/apps/details?id=com.gma.water.sort.puzzle) | The first inspected store screenshot shows neon-rim glass on navy, a diagonal pouring tube, dense bottle arrangements and a promotional footer/mascot. | Immediate readable silhouettes, a visible liquid bridge and focus on the active pour. | Do not copy silhouettes, mascot, composition or neon. Promotional density is not evidence of good gameplay ergonomics; runtime/audio/performance untested. |
| [SortPuz — Dark Halo](https://play.google.com/store/apps/details?id=sortpuz.water.sort.puzzle.game) | The inspected screenshot shows many brightly coloured tubes over a blue night/city treatment. | Simple colour separation and legibility across many tubes; a background can establish mood without changing mechanics. | Layer Sort has3–6 tubes and a laboratory identity; do not imitate dense layouts, city art or unrelated themes. Store descriptions of sound are claims, not audition evidence. |
| Current Layer Sort | C/H: controlled navy, softer palette, non-colour dots, bilingual hierarchy and explicit Circuit. | Retain calm precision and use Circuit's thin signal system as its distinctive visual language. | The goal is a more cohesive material/feedback system, not matching a competitor's saturated marketing image or adding its mechanics. |

Comparison by dimension: material depth can improve through contour hierarchy; UX should preserve the existing single Play and direct Next; Arabic and symbol readability are product strengths to protect; audio requires an actual audition; performance cannot be ranked against competitors without comparable device measurements. No numerical competitor quality/FPS scores are invented.

## 4. Three implementation alternatives

Scores are **design judgments**, not benchmarks. Effort estimates are provisional engineer-days after scope approval, excluding owner review/CI wait.

| Approach | Expected quality / performance | Cost and maintenance | Recommendation |
|---|---|---|---|
| A — Original procedural Godot | Responsive glass contours, liquid shading, symbols and UI states can share existing tokens; no extra texture memory, but polygons/draw calls must be bounded. | About2–4 days for a representative tube/pour/UI comparison; editable source, straightforward scaling. | **Primary direction.** Refine accepted Optical Clarity rather than replacing it. |
| B — Small licensed accents | A verified icon or UI click can improve consistency; blanket kits would mismatch glass/Arabic typography. SVGs rasterize at import, short WAVs fit existing voices. | About1–2 days to evaluate a tiny selection, plus provenance/credit upkeep. No runtime icon/audio package dependency needed. | Optional fallback only when it demonstrably beats A. Do not import entire packs. |
| C — Original custom artwork | Authored vector rim/highlight or a small baked glass overlay can add art-directed depth at known sizes; no heavy refraction required. | About3–6 days for source SVG/layered artwork, adaptive variants and integration. More atlas/scale/version maintenance. | Reserve for a specific material gap A cannot solve. Keep editable masters and bounded transparent area. |

Recommendation: **A plus selective original custom accents**, retaining the existing fonts/audio framework; B is a comparison candidate, not a purchase/import decision. Proposed editable tokens: navy/ink/muted/accent remain those in OpticalTheme; introduce approved contour-width, reflection-opacity, meniscus-height, marker-safe-inset and feedback-duration tokens only after a rendered A/B. Keep palette IDs/hues stable unless the owner separately approves a purely visual colour adjustment and accessibility regression.

## 5. Asset and license inventory

Research only; no external graphics/audio were imported. Public text/SVG/WAV bytes were read in memory for metadata/license inspection; competitor thumbnails and existing historical images were viewed outside the product. Mutable source URLs must be pinned to an immutable revision and rehashed before any future import. License permissions alone do not establish aesthetic or technical suitability.

### Existing approved resources — reuse first

| Resource | Source/license and obligations | Size/format and compatibility |
|---|---|---|
| Original renderer/icons/background | Project source; no external art rights claimed. Source-code licensing follows repository governance, not the audio CC0 dedication. | Existing CanvasItem/StyleBox/Tween implementation; no added texture cost. |
| Manrope | [Exact source and license register](../content/fonts/provenance.json), SIL OFL1.1; retain copyright/license, no font-only sale, modified reserved names require care. Commercial embedding and redistribution with the license allowed. |164,700 bytes TTF; existing Godot FontVariation. |
| Noto Sans Arabic | Same register, exact bundled OFL text; same OFL conditions. Keep shaping/fallback rather than replacing with an unverified display font. |844,676 bytes TTF; existing Arabic shaping/fallback. |
| Six original SFX | [Existing dedication](../content/audio/LICENSE.txt), CC0-1.0 applies to these six WAVs only; no mandatory attribution. |Mono PCM16/22,050Hz. select4,454B/0.10s; ui3,130B/0.07s; invalid5,336B/0.12s; pour11,950B/0.27s; complete15,038B/0.34s; win34,442B/0.78s. Reproducible source: `tools/assets/generate_ui_audio.py`. |

### Specific external candidates — verified license and measured source bytes

| Candidate | Source and exact license | Attribution / commercial use / redistribution | Measured size, hash and technical review | Decision |
|---|---|---|---|---|
| Kenney Interface Sounds `click_001.wav` | [Official pack](https://kenney.nl/assets/interface-sounds); [specific file mirror](https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/addons/kenney_interface_sounds/click_001.wav); [included license](https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/master/LICENSE.txt), CC0-1.0. Official indexed pack/support pages identify CC0; direct official-page open was blocked, so the included license was read separately. |Commercial use/adaptation/redistribution allowed; no mandatory credit; optional “Kenney”. No ownership of Kenney trademarks/logos implied. |10,190 bytes, mono PCM16/44,100Hz,0.115s; SHA256 `ea67c9d78750e5a356bf53ef8c2063b52cc3ccdae6ae8afeec87f97f79ae692d`. License574B, SHA256 `f7966c773bbed0eca6a9c75081c44a178b38eae112724dbb5fdfbd4192d118a9`. Existing AudioStreamWAV compatible; loudness/timbre audition NOT performed. |Eligible for later A/B only; prefer existing original click if quality equal. No pack imported. |
| Tabler outline `lock.svg` | [Exact SVG](https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/lock.svg), [MIT license](https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE). License names Paweł Kuna. |Commercial use, modification and redistribution allowed; retain full copyright and MIT permission notice with copies/substantial portions. No dependency or npm package required. |527 bytes; SHA256 `407856048124fdd63239f75a3640ca8f20a9acbc1f49cac9de0bcdb1cb42ec5f`. License1,073B, SHA256 `b740a1d46122672da62833e97f7e7c8a13fa85cbc7445b584b297cc00dde93db`.24-unit SVG; rasterize at bounded target size or hand-author an original icon instead. Exact Godot import/render still pending. |Eligible reference/optional icon; existing original lock remains preferred for cohesive animated states. |
| Lorc “Padlock” | [Author/license page](https://game-icons.net/1x1/lorc/padlock.html), [specific SVG](https://game-icons.net/icons/ffffff/000000/1x1/lorc/padlock.svg), [CC BY3.0 Unported](https://creativecommons.org/licenses/by/3.0/). |Commercial adaptation/redistribution allowed with title/author/source/license credit and derivative-change notice; no endorsement claim or additional legal/technical restriction on licensed reuse. Preserve notices; review packaging obligations before adoption. |686 bytes; SHA256 `6357f13cc4d14f535a47a8fe2635ea34def7c4b21e205a5c34c8f5fdba3c8cd3`. SVG silhouette,512-unit design; Godot rasterization/import test and target pixel size pending. |Legally identified but visually less consistent than existing line glass lock. Not recommended for the primary direction. |

Example CC-BY credit if later adopted: “Padlock — Lorc, game-icons.net, CC BY3.0; recoloured/scaled for Layer Sort”, with source/license links and retained notices. MIT text must also be bundled if Tabler is used; an About icon credit alone is not a substitute. Update existing credits/license records only after a specific asset is approved and imported.

**Rejected / not ship-eligible:** NC/ND licenses; “free” without a specific license; unknown uploader rights; ripped competitor graphics/audio; paid/registration-only packs with unverifiable terms; unverified individual Freesound/OpenGameArt uploads; copyrighted music; generic AI-output assumptions. A site-wide reputation is not a license for every item. No texture/3D/large pack is proposed: current vector geometry provides equal or better fit and lower operational cost. PNG/WAV/SVG eligibility does not mean the file has passed integration or owner approval.

## 6. Audio proposal

Current source has four reusable voices and a uniform-5dB player level; six preloaded cues, mute/focus handling and explicit stop/stream cleanup. Pour SFX is0.27s while normal presentation is0.48s and its transfer window is the middle half; source confirms the cue starts at flow start. This does not prove audible mismatch: audition both together before changing timing. Complete and win can occur close together, and Circuit activation currently reuses completion audio; evaluate perceptual distinction instead of assuming it is broken.

Proposed cue hierarchy:

| Cue | Proposed intent | Scope/acceptance |
|---|---|---|
| Selection/UI | Soft, short glass contact / restrained click; less prominent than gameplay. | Keep deterministic original synthesis; optional Kenney click A/B. No constant hover sounds on touch. |
| Pour | Controlled low-volume flow with a soft glass resonance, attack/release aligned to normalized transfer. | Refine noise filtering/envelope in the existing generator; alternatively owner-created clean original recording with documented rights. No loops or new runtime framework. |
| Invalid | Quiet rounded “blocked” tick distinct from positive select. | No harsh buzz or punitive volume; visual feedback remains sufficient when muted. |
| Circuit unlock | Brief airy glass latch cue distinguishable from tube completion. | Prefer original synthesis, proposed only; count toward existing voice pool, not a new audio system. Owner approval before adding a file. |
| Complete / win | Short confirmation and restrained final resolution; avoid two equally loud celebratory cues stacking. | Review cue priorities/per-cue gain and headroom using the existing four players. No reward or gameplay delay. |

Audition on the owner's phone speaker and headphones at low/medium volume, Arabic/English sessions and repeated fast input. Check clicks, clipping/peak/RMS, cue masking, mute/focus/pause/restore and no replayed sounds after resume. Target short mono samples; do not invent loudness scores or declare “natural water sound” from waveform inspection. No soundtrack system now; longer music belongs Later after a separate decision.

## 7. Performance plan and budgets

All numbers below are **proposed limits/acceptance targets**, not measurements of the OPPO or competitors. Retain Compatibility, Godot4.7.2, existing ABI/package/signature/export and offline behavior.

- Baseline source: TubePainter creates ellipse/rim PackedVector2Arrays during redraw; layer shading has2/4 bands and multiple lines/polygons. Profile redraw/call counts before deciding to cache normalized geometry per size or bake an overlay. Cache only after a measured benefit; invalidate on size/quality changes. Avoid permanent `_process` animations.
- Keep the low tier readable with contours, markers and meniscus; optional reflection detail on high tier only. Reduced Motion must remain functionally equivalent with minimal motion. No screen-space blur/refraction, full-screen particles or expensive shader branches.
- Initial target:60Hz frame budget16.7ms on devices capable of it; if a separately approved30Hz low-end tier is necessary,33.3ms. Do not silently lower quality/framerate to turn a failing test into PASS. Capture median/p95/p99 frame time and stall counts on the same device/build; Linux llvmpipe numbers are not Android GPU evidence.
- Before/after test: same3/6-tube boards, selected state, repeated pours and Circuit unlock, three repeated60-second samples after warm-up; separate cold/warm startup, five pause/resume cycles and memory snapshots after cleanup. State actual tool, device, resolution, sample count and variance. Any clear regression blocks rollout until explained.
- Proposed UI texture ceiling for an optional custom accent: one512×512 RGBA atlas is1MiB uncompressed without mips (~1.33MiB with a full mip chain). This is arithmetic, not measured Godot residency. No atlas needed if vectors win. Avoid large transparent quads/oversized textures.
- Keep four audio voices, finite pulses/Tweens and bounded Map nodes. Proposed added decoded audio budget256KiB; report actual bytes after any changes. No runtime allocations added to authoritative pour rules.
- Existing APK CI budget remains32MiB. Accepted corrected baseline:29,102,331 bytes; SHA256 `fd1172722e912faba4b2f4a51708782a9685c2c548a8a548d04477f6014ebed2`. Compare exact future artifacts, archive contributions and source hashes; no claim that native-runtime size comes from gameplay scripts.

## 8. Now / Next / Later and implementation sequence

**Now — authorized audit/documentation only:** record acceptance; inventory exact licenses and bytes; obtain/review current captures where access permits; approve the marker-fit reproduction, visual priorities and audio audition plan. No game edit, import or benchmark execution is performed here.

**Next — separate owner implementation approval required:**

1. Reproduce marker-fit on5-colour narrow content and current captures; choose a symbol layout retaining accessibility. Freeze one representative glass/liquid before/after comparison, not every screen at once.
2. Implement a small procedural material/selection/pour prototype with tokens; verify a6-tube narrow scene, Circuit19 and Reduced Motion before broader application. Keep rendering independent from authoritative state.
3. After approval, apply shared icon/state/typography/spacing treatment to HUD, Home, Map and Win; preserve exact navigation and current touch behavior.
4. Audition/mix the existing original SFX first. Import a specific external candidate only if it wins an A/B and all exact-revision/license/hash/import checks pass. Retain generated sources/derived hashes.
5. Run full regression/graphical/Android artifact verification; then owner device testing and aesthetic acceptance. Stage reviewable commits and retain failed evidence. Keep PR19 Draft unless separately instructed.

**Later — deferred:** soundtrack, theme packs, large bespoke background art, optional 3D references/render-baked experiments, broad accessibility certification and store presentation. Each needs a separate scope decision; G6 generation/new mechanics are not polish work and remain unauthorized.

Provisional total for a bounded approved polish slice:5–9 engineer-days depending on the selected alternative, assets and iterations; not a delivery promise. Proposed scope can be reduced after the representative screen review rather than silently expanding into a redesign.

## 9. Acceptance tests and rollback

Before any future polish is accepted:

- Preserve SHA-256 of all Levels1–20 and relevant schema/catalog identities; all Classic/Circuit, atomic commits, invalid action, Undo/Restart, progression/duplicate-win and save/recovery/future-schema regressions pass. No new rule, save migration or reset.
- Genuine fresh-scene Arabic/English captures at600/720 for3–6 tubes,5-colour assistance, initial/selected/invalid/pour samples/completed tube, Circuit locked/activation/unlocked/Undo, Pause, Map and final20 victory/Replay. Check actual drawn indicator centers and viewport bounds; do not rely on resize-only or getter-only assertions. Inspect images manually and label mockups separately.
- Validate current touch controls and assistive names/focus/disabled states, physical dp on Android, marker readability independent of hue, safe areas and legible text wrapping. Touch scrolling must not launch a level; overlays must not receive/forward unintended gameplay taps.
- Both quality modes and Reduced Motion preserve readable state and exact board synchronization; no ghosts after cancel/navigation, no overlapping input or duplicate commits. Audio mute/focus/lifecycle, bounded voices and P3 teardown leak guard pass without suppressing diagnostics.
- Full pinned CI and signed APK integrity/package/certificate/size/provenance checks pass on the exact candidate. Record performance with real instrumentation as proposed above; new leaks/errors block acceptance. Keep historical warnings distinguished from new regressions.
- Owner signs off on visual coherence and audio on the exact APK; separately record device QA from CI. No benchmark/phone/logcat PASS without evidence. A successful build does not authorize a merge or G6.

Rollback is a separately reviewed revert of future polish commits, preserving schema, level identities, accepted content and real saves. Keep before/after captures, editable original artwork, synthesis source, exact third-party bytes/licenses and derived hashes. Never uninstall/reset data, rewrite history, delete branches or alter signing to roll back art. This documentation commit can be reverted independently and contains no runtime assets/code.
