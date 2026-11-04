extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/navigation/root.tscn")
	var test_saves: SaveRepository = SaveRepository.new()
	test_saves.directory = "user://navigation_isolated_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_saves.directory))
	var navigation: NavigationCoordinator = scene.instantiate()
	navigation.set("_saves", test_saves)
	root.add_child(navigation)
	await create_timer(0.65).timeout
	var home: HomeScreen = navigation.current_screen() as HomeScreen
	check(home != null and not home.continue_enabled, "fresh Home has no Continue")
	(home.find_child("MapButton", true, false) as Button).pressed.emit()
	check(navigation.current_screen() is LevelMapScreen, "Map opens")
	var level_map: LevelMapScreen = navigation.current_screen() as LevelMapScreen
	check((level_map.find_child("level_002", true, false) as Button).disabled, "next level locked")
	check(not navigation.open_level("level_002") and navigation.current_screen() == level_map, "locked request retains Map")
	(level_map.find_child("level_001", true, false) as Button).pressed.emit()
	check(navigation.current_screen() is ClassicGame, "unlocked level opens")
	var game: ClassicGame = navigation.current_screen() as ClassicGame
	var original_layers: Array[int] = game._views[0].logical_layers.duplicate()
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	check(game.has_unsaved_move(), "committed move")
	check(game._views[0].logical_layers == original_layers, "drawing remains pre-pour until presentation completes")
	var committed: String = game._session.snapshot().identity()
	game._on_tube_pressed(1)
	check(game._session.snapshot().identity() == committed, "pour input locked during presentation")
	await create_timer(0.7).timeout
	check(game._views[0].logical_layers != original_layers, "drawing catches up with committed board")
	navigation.go_back()
	var pause: PauseScreen = navigation.get("_pause_screen") as PauseScreen
	check(pause != null, "Back opens Pause")
	(pause.find_child("MapButton", true, false) as Button).pressed.emit()
	var leave: ConfirmationDialog = navigation.get("_leave_dialog") as ConfirmationDialog
	check(leave != null and leave.visible, "Map exit confirms attempt")
	leave.hide()
	leave.confirmed.emit()
	check(navigation.current_screen() is LevelMapScreen, "confirmed exit opens Map")
	level_map = navigation.current_screen() as LevelMapScreen
	(level_map.find_child("level_001", true, false) as Button).pressed.emit()
	game = navigation.current_screen() as ClassicGame
	var solution: Array[Vector2i] = [Vector2i(0, 3), Vector2i(2, 0), Vector2i(1, 2), Vector2i(1, 3), Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 3), Vector2i(1, 2), Vector2i(0, 1), Vector2i(0, 3)]
	for index: int in range(solution.size()):
		var move: Vector2i = solution[index]
		game._on_tube_pressed(move.x)
		game._on_tube_pressed(move.y)
		if index == solution.size() - 1:
			check(navigation.get("_win_dialog") == null, "win dialog waits for pour presentation")
			navigation.go_back()
		await create_timer(0.7).timeout
	check(navigation.get("_win_dialog") == null, "Pause defers win dialog")
	navigation._restart_game()
	check(not game.has_unsaved_move() and navigation.get("_win_dialog") == null, "restart cancels deferred win presentation")
	game.reduce_motion = true
	for move: Vector2i in solution:
		game._on_tube_pressed(move.x)
		game._on_tube_pressed(move.y)
		await create_timer(0.14).timeout
	check(navigation.get("_win_dialog") != null, "valid win opens completion")
	navigation.go_back()
	check(navigation.current_screen() is LevelMapScreen, "Back from win returns Map")
	level_map = navigation.current_screen() as LevelMapScreen
	check(not (level_map.find_child("level_002", true, false) as Button).disabled, "win unlocks next level")
	(level_map.find_child("level_002", true, false) as Button).pressed.emit()
	game = navigation.current_screen() as ClassicGame
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	check(game.has_unsaved_move(), "second level attempt committed")
	navigation.queue_free()
	await process_frame
	var restarted: NavigationCoordinator = scene.instantiate()
	restarted.set("_saves", test_saves)
	root.add_child(restarted)
	await create_timer(0.65).timeout
	home = restarted.current_screen() as HomeScreen
	check(home.continue_enabled, "restarted app offers saved Continue")
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	check((restarted.current_screen() as ClassicGame).has_unsaved_move(), "Continue restores committed board")
	restarted.queue_free()
	print("G3B_NAV_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3B_NAV_FAIL " + name)
