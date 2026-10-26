# G3-A — navigation foundation

The entry scene is `scenes/navigation/root.tscn`. `NavigationCoordinator` owns the active screen and Android Back routing. `NavigationState` records the route and selected level. Home reads the validated entry ID from `content/levels/catalog.json`; the game receives a validated level path before it enters the tree. `LevelLoader` retains its strict G2 schema. Returning Home discards the in-memory G2 session; a played attempt requires confirmation before leaving. This is prototype behavior, not save/resume.

The short splash leads to Home after 0.5 seconds. Settings changes language in the current process and updates screen direction. The settings screen says explicitly that the choice lasts for this session. About reads bounded attribution entries from `content/about/credits.json`. The UI uses the approved dark/cyan palette and scalable containers; premium assets remain G4.

| File | Primary responsibility |
|---|---|
| `navigation_coordinator.gd` | Screen ownership and Android Back |
| `navigation_state.gd` | Route/level state transitions |
| `level_catalog.gd` | Validate catalog and resolve approved level IDs |
| `app_settings.gd` | Session language setting |
| `ui_text.gd` | English/Arabic UI strings |
| `screen_widgets.gd` | Shared temporary visual tokens/components |
| `splash_screen.gd`, `home_screen.gd`, `settings_screen.gd`, `about_screen.gd` | Presentation and emitted intents |
| `attribution_catalog.gd` | Read bounded credit data |
| `classic_game.gd` | G2 interaction and G3 Home event, without rule changes |

G3-B can add a level map that calls `open_level(level_id)`, use catalog metadata to choose unlocked levels, and replace `AppSettings`' in-memory lifetime with a separately tested repository. A progress/save coordinator must own crash-safe snapshots before Home can offer Continue. No implicit default level ID should enter the navigation contract. The two current fixture files are not a shipped campaign.

QA is split: `tests/g3a/navigation_test.gd` checks route/screen/language/catalog behavior; the unchanged G2 rule suite checks Classic regression. Device QA must install the exact CI APK and separately capture splash/Home, Settings, About, game move, return/reopen and Android Back, with AR/EN screenshots and logcat. G15-QA-001 remains open. Track B is UNVERIFIED until that run occurs.
