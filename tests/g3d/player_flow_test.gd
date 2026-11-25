extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository: SaveRepository = SaveRepository.new()
	repository.directory = "user://g3d_flow_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repository.directory))
	var scene: PackedScene = load("res://scenes/navigation/root.tscn")
	var navigation: NavigationCoordinator = scene.instantiate() as NavigationCoordinator
	navigation.set("_saves", repository)
	root.add_child(navigation)
	await create_timer(0.65).timeout
	var home: HomeScreen = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_play_level", home.language) % "001", "fresh Home names actual entry level")
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	var game: ClassicGame = navigation.current_screen() as ClassicGame
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	check(navigation.current_screen() == game, "stale Home double press cannot replace active game")
	game.reduce_motion = true
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	await create_timer(0.14).timeout
	var identity: String = game.committed_snapshot().identity()
	navigation.go_home()
	home = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_resume_level", home.language) % "001", "Home names saved attempt")
	(navigation.get("_settings") as AppSettings).set_language("ar")
	navigation.go_home()
	home = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_resume_level", "ar") % "001", "Arabic Home names saved attempt")
	(navigation.get("_settings") as AppSettings).set_language("en")
	navigation.go_home()
	home = navigation.current_screen() as HomeScreen
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	check((navigation.current_screen() as ClassicGame).committed_snapshot().identity() == identity, "primary restores exact committed board")
	navigation.queue_free()
	await process_frame
	navigation = scene.instantiate() as NavigationCoordinator
	navigation.set("_saves", repository)
	root.add_child(navigation)
	await create_timer(0.65).timeout
	home = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_resume_level", home.language) % "001", "relaunch retains named attempt")
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	game = navigation.current_screen() as ClassicGame
	check(game.committed_snapshot().identity() == identity, "relaunch restores exact committed board")
	var solutions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	navigation.open_level("level_001")
	game = navigation.current_screen() as ClassicGame
	await solve(game, solutions["level_001"].solution)
	var win: WinDialog = navigation.get("_win_dialog") as WinDialog
	check(win != null and win.visible, "valid win presents result")
	check(win.ok_button_text == UiText.get_text("next_level", "en") % "002", "primary Win action names unlocked next level")
	check(win.find_child("ReplayButton", true, false) != null and win.find_child("MapButton", true, false).visible, "Win exposes Replay and Map")
	(win.find_child("ReplayButton", true, false) as Button).pressed.emit()
	game = navigation.current_screen() as ClassicGame
	check(game.committed_snapshot().level_id == "level_001" and game.committed_snapshot().move_count == 0, "Replay starts same level anew")
	check((navigation.get("_progression") as Progression).completed.has("level_001"), "Replay preserves first completion")
	await solve(game, solutions["level_001"].solution)
	win = navigation.get("_win_dialog") as WinDialog
	(win.find_child("MapButton", true, false) as Button).pressed.emit()
	check(navigation.current_screen() is LevelMapScreen, "secondary Map opens map")
	var level_map: LevelMapScreen = navigation.current_screen() as LevelMapScreen
	var map_level: Button = level_map.find_child("level_001", true, false) as Button
	map_level.pressed.emit()
	var opened: Control = navigation.current_screen()
	map_level.pressed.emit()
	check(navigation.current_screen() == opened, "stale Map double press cannot replace active game")
	game = navigation.current_screen() as ClassicGame
	await solve(game, solutions["level_001"].solution)
	win = navigation.get("_win_dialog") as WinDialog
	win.confirmed.emit()
	check((navigation.current_screen() as ClassicGame).committed_snapshot().level_id == "level_002", "primary Next opens next unlocked level")
	win.confirmed.emit()
	check((navigation.current_screen() as ClassicGame).committed_snapshot().level_id == "level_002", "duplicate Win confirmation ignored")
	var progress: Progression = navigation.get("_progression") as Progression
	for number: int in range(2, 14):
		progress.record_win("level_%03d" % number, 20)
	navigation.go_home()
	navigation.set("_active", {})
	navigation.go_home()
	home = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_play_level", home.language) % "014", "Home names first incomplete level")
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	game = navigation.current_screen() as ClassicGame
	check(game.committed_snapshot().level_id == "level_014", "primary opens level 14")
	await solve(game, solutions["level_014"].solution)
	win = navigation.get("_win_dialog") as WinDialog
	check(win.ok_button_text == UiText.get_text("next_level", "en") % "015", "Classic finale offers first Circuit")
	win.confirmed.emit()
	game = navigation.current_screen() as ClassicGame
	check(game.committed_snapshot().level_id == "level_015", "Next opens Circuit directly")
	await solve(game, solutions["level_015"].solution)
	win = navigation.get("_win_dialog") as WinDialog
	for number: int in [16, 17, 18, 19, 20]:
		check(win.ok_button_text == UiText.get_text("next_level", "en") % ("%03d" % number), "Next names the next allocated level")
		win.confirmed.emit()
		game = navigation.current_screen() as ClassicGame
		check(game.committed_snapshot().level_id == "level_%03d" % number, "Next opens correct level")
		await solve(game, solutions["level_%03d" % number].solution)
		win = navigation.get("_win_dialog") as WinDialog
	check(win.ok_button_text == UiText.get_text("level_map", "en"), "last level primary gracefully opens Map")
	check(not (win.find_child("MapButton", true, false) as Button).visible, "last level has no duplicate Map action")
	win.confirmed.emit()
	check(navigation.current_screen() is LevelMapScreen, "last level result returns Map")
	navigation.go_home()
	home = navigation.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_choose_level", home.language), "completed campaign names replay map")
	navigation.queue_free()
	await process_frame
	print("G3D_FLOW_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func solve(game: ClassicGame, solution: Array) -> void:
	game.reduce_motion = true
	for pair: Array in solution:
		game._on_tube_pressed(int(pair[0]))
		game._on_tube_pressed(int(pair[1]))
		await create_timer(0.14).timeout
	check(WinRules.is_won(game.committed_snapshot()), "fixture solution wins")


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3D_FLOW_FAIL " + label)
