# Real Game UI — implementation and verification

Base: PR14 /24809327f45f0d7ee4633e67456a03def74471a4. Branch feat/real-game-ui. Owner authorized this refinement in ADR0005. No Classic rules, save architecture, level fixtures, Android identity/signing or renderer changes. Godot4.7.2 Standard Compatibility preserved.

## Implemented

Home has original rendered glass identity, one real dynamic Play/Continue action, compact Map/Settings and no About button. Shared OpticalIconButton draws original vector icons with localized accessible names and96-reference-pixel targets. Gameplay Home/Pause/Undo/Restart reuse it; tube geometry remains unchanged. Win is borderless withoutX, with actualNextlevel primary, compactReplay/Map, and finalcampaignMap fallback. A modal dimmer isolates input. About now returns to its calling Settings, including Pause Settings without losing the live committed game. Existing Optical Clarity material and licensed fonts are reused.

Responsibilities: presentation/optical_icon_button.gd owns vector control rendering; home_glass_hero.gd draws decorative original glass (not a game/session); optical_theme.gd centralizes fonts/colors; UI screens compose controls; navigation_coordinator routes actions/About contexts and modal isolation. New real_ui_test exercises narrowlayout, iconclicks, Replay and blockedbackground input; navigation tests coverAboutreturn and exactpausedsnapshot. Existing cloudsmoke covers actualNext/Map/Replay and bilingual journeys.

## Evidence and limits

Actual Godot before/after captures are in evidence/real-game-ui. Before is exactPR14head running its existing harness, after is this source using changed selectors for iconcontrols. Baseline and modified screenshots are genuine viewport readbacks, not mockups. Optical tests cover3/4/5/6 tubes, selected, sampledpour andReducedMotion. Linux graphical evidence does not prove Android behavior.

Prior interrupted-session screenshots/logs were in ephemeral/tmp and are no longer available. They were not invented or reconstructed as historical evidence; fresh runs on pinnedengine regenerate current evidence. Earlierreported191cloud/9narrow success is contextual only; new logs and CI are the source of verification. Full existing regression suites run in finalCI.

Independent review: parent reviewed actualHomeEN/AR, game, Win and narrowArabic screenshots and coordinator diff before interruption; found similarUndo/Restart glyphs and graycornerartifact, both corrected; requestedmodaldimmer now implemented. Liquid remains stylized rigid layered fill while tilted. Existing exit-time resource warnings remain open. No claim of finalpremiumvisual or accessibility acceptance.

TrackB UNVERIFIED: no adb/agentctl/phonequeue locally, RemoteDesktop reports no connecteddevices. No phone modifications or saves deleted. Remaining: install exactCIAPK via authorizedlock withoutclearingdata, checkupdatepreservation, touchlatency/targets, framepacing/memory, audiofocus/lifecycle, Arabicfontscaling, safeareas, lowbrightness and rapidinput. G15-QA-001 OPEN.

Rollback: revert this feature commit on a new reviewbranch; preserve saves and existingPRstack. No main/protectedbranch changes, merges or futuremechanics. Font assets remain originalOFL sources from baseline; newicons/hero are originalCanvasItemcode, no externalart/newdependencies.
