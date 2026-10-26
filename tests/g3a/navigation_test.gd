extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_settings()
	_test_routes()
	var root_scene: PackedScene = load("res://scenes/navigation/root.tscn")
	var navigation: NavigationCoordinator = root_scene.instantiate()
	root.add_child(navigation)
	await create_timer(0.65).timeout
	_expect(navigation.current_route() == NavigationState.Route.HOME, "splash reaches Home")
	_expect(navigation.current_screen() is HomeScreen, "Home screen loaded")

	var home: HomeScreen = navigation.current_screen() as HomeScreen
	var settings_button: Button = home.find_child("SettingsButton", true, false) as Button
	_expect(settings_button != null, "Settings button reachable")
	settings_button.pressed.emit()
	_expect(navigation.current_route() == NavigationState.Route.SETTINGS, "Settings opens")
	var settings: SettingsScreen = navigation.current_screen() as SettingsScreen
	var arabic_button: Button = settings.find_child("ArabicButton", true, false) as Button
	_expect(arabic_button != null, "Arabic setting reachable")
	arabic_button.pressed.emit()
	settings = navigation.current_screen() as SettingsScreen
	_expect(settings.language == "ar", "language changes immediately")
	_expect(settings.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic UI is RTL")
	navigation.go_back()
	_expect(navigation.current_route() == NavigationState.Route.HOME, "Back to Home")
	home = navigation.current_screen() as HomeScreen
	_expect(home.language == "ar", "language survives screen changes")
	var about_button: Button = home.find_child("AboutButton", true, false) as Button
	_expect(about_button != null, "About button reachable")
	about_button.pressed.emit()
	_expect(navigation.current_screen() is AboutScreen, "About opens")
	navigation.go_back()
	_expect(navigation.current_route() == NavigationState.Route.HOME, "About Back returns Home")
	_expect(not navigation.open_level("../other"), "unknown level rejected")
	var catalog_result: Dictionary = LevelCatalog.load_catalog()
	_expect(catalog_result.ok, "catalog loads")
	if catalog_result.ok:
		_expect(navigation.open_level(catalog_result.catalog.entry_level_id), "catalog level opens")
		_expect(navigation.current_screen() is ClassicGame, "playable scene loaded")
		var game: ClassicGame = navigation.current_screen() as ClassicGame
		_expect(game.language == "ar", "game inherits locale")
		var board: HBoxContainer = game.find_child("TubeRow", true, false) as HBoxContainer
		_expect(board != null and board.layout_direction == Control.LAYOUT_DIRECTION_LTR, "tube order stays LTR")
		game._on_tube_pressed(0)
		game._on_tube_pressed(3)
		_expect(game.has_unsaved_move(), "fixture move committed")
		navigation.go_back()
		var pause: PauseScreen = navigation.get("_pause_screen") as PauseScreen
		_expect(pause != null and pause.visible, "game Back opens Pause")
		_expect(game.has_unsaved_move(), "Pause retains committed move")
		navigation.go_back()
		_expect(navigation.get("_pause_screen") == null and game.has_unsaved_move(), "Back resumes without changing move")
		var pause_button: Button = game.find_child("PauseButton", true, false) as Button
		pause_button.pressed.emit()
		pause = navigation.get("_pause_screen") as PauseScreen
		var settings_from_pause: Button = pause.find_child("SettingsButton", true, false) as Button
		settings_from_pause.pressed.emit()
		_expect(navigation.get("_pause_settings") is SettingsScreen, "Pause Settings opens")
		navigation.go_back()
		_expect(navigation.get("_pause_settings") == null and navigation.get("_pause_screen") != null, "Settings Back returns Pause")
		var restart_from_pause: Button = pause.find_child("RestartButton", true, false) as Button
		restart_from_pause.pressed.emit()
		var restart_dialog: ConfirmationDialog = navigation.get("_restart_dialog") as ConfirmationDialog
		_expect(restart_dialog != null and restart_dialog.visible, "played attempt restart confirms")
		navigation.go_back()
		_expect(game.has_unsaved_move(), "cancelled restart retains move")
		var exit_from_pause: Button = pause.find_child("HomeButton", true, false) as Button
		exit_from_pause.pressed.emit()
		_expect(navigation.get("_leave_dialog") != null, "Pause exit uses unsaved confirmation")
		navigation.go_back()
		var resume: Button = pause.find_child("ResumeButton", true, false) as Button
		resume.pressed.emit()
		_expect(navigation.get("_pause_screen") == null and game.has_unsaved_move(), "Resume retains move")
		var game_home_button: Button = game.find_child("HomeButton", true, false) as Button
		_expect(game_home_button != null, "game Home button reachable")
		game_home_button.pressed.emit()
		_expect(navigation.current_route() == NavigationState.Route.GAME, "unsaved attempt requires confirmation")
		var leave: ConfirmationDialog = navigation.get("_leave_dialog") as ConfirmationDialog
		_expect(leave != null and leave.visible, "leave confirmation displayed")
		navigation.go_back()
		_expect(navigation.current_route() == NavigationState.Route.GAME, "Back dismisses confirmation")
		game_home_button.pressed.emit()
		if leave != null:
			leave.confirmed.emit()
			_expect(navigation.current_route() == NavigationState.Route.HOME, "confirmed leave returns Home")
		_expect(navigation.open_level(catalog_result.catalog.entry_level_id), "fixture reopens")
		navigation.go_back()
		_expect(navigation.get("_pause_screen") is PauseScreen, "fresh game Back opens Pause")
		var fresh_game: ClassicGame = navigation.current_screen() as ClassicGame
		fresh_game._on_tube_pressed(0)
		fresh_game._on_tube_pressed(3)
		var fresh_pause: PauseScreen = navigation.get("_pause_screen") as PauseScreen
		(fresh_pause.find_child("RestartButton", true, false) as Button).pressed.emit()
		(navigation.get("_restart_dialog") as ConfirmationDialog).confirmed.emit()
		_expect(not fresh_game.has_unsaved_move() and navigation.get("_pause_screen") == null, "confirmed Restart resets attempt")
		(navigation.get("_restart_dialog") as ConfirmationDialog).hide()
		navigation.go_back()
		(navigation.get("_pause_screen") as PauseScreen).find_child("HomeButton", true, false).pressed.emit()
		_expect(navigation.current_route() == NavigationState.Route.HOME, "unused attempt exits without confirmation")
	navigation.go_back()
	var exit_dialog: ConfirmationDialog = navigation.get("_exit_dialog") as ConfirmationDialog
	_expect(exit_dialog != null and exit_dialog.visible, "Home Back confirms exit")
	navigation.go_back()
	_expect(not exit_dialog.visible and navigation.current_route() == NavigationState.Route.HOME, "Back dismisses exit confirmation")
	navigation.queue_free()
	print("G3A_NAV_TESTS status=%s checks=%d failures=%d" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_catalog() -> void:
	var valid: Dictionary = LevelCatalog.load_catalog()
	_expect(valid.ok, "valid catalog")
	if valid.ok:
		_expect(valid.catalog.path_for(valid.catalog.entry_level_id) == "res://content/levels/level_001.json", "parameterized path")
		_expect(valid.catalog.path_for("level_404").is_empty(), "unknown ID rejected")
	var duplicate: Dictionary = LevelCatalog.from_data({"schema_version": 1, "entry_level_id": "level_001", "available_level_ids": ["level_001", "level_001"]})
	_expect(not duplicate.ok, "duplicate ID rejected")
	var traversal: Dictionary = LevelCatalog.from_data({"schema_version": 1, "entry_level_id": "../x", "available_level_ids": ["../x"]})
	_expect(not traversal.ok, "path escape rejected")


func _test_settings() -> void:
	var settings: AppSettings = AppSettings.new()
	_expect(not settings.set_language("xx"), "unsupported language rejected")
	_expect(settings.set_language("en"), "English selectable")
	_expect(settings.set_language("ar"), "Arabic selectable")
	_expect(settings.language == "ar", "language state retained")


func _test_routes() -> void:
	var state: NavigationState = NavigationState.new()
	state.open_home()
	_expect(not state.back(), "Home Back requests exit")
	state.open_settings()
	_expect(state.back() and state.route == NavigationState.Route.HOME, "Settings Back")
	state.open_about()
	_expect(state.back() and state.route == NavigationState.Route.HOME, "About Back")
	state.open_game("level_002")
	_expect(state.level_id == "level_002", "level entry parameter")
	_expect(state.back() and state.level_id.is_empty(), "game Back clears level")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("G3A_FAIL: " + description)
