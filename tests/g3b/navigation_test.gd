extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/navigation/root.tscn")
	var navigation: NavigationCoordinator = scene.instantiate()
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
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	check(game.has_unsaved_move(), "committed move")
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
	for move: Vector2i in solution:
		game._on_tube_pressed(move.x)
		game._on_tube_pressed(move.y)
		await create_timer(0.3).timeout
	check(navigation.get("_win_dialog") != null, "valid win opens completion")
	(navigation.get("_win_dialog") as AcceptDialog).hide()
	(navigation.get("_win_dialog") as AcceptDialog).confirmed.emit()
	level_map = navigation.current_screen() as LevelMapScreen
	check(not (level_map.find_child("level_002", true, false) as Button).disabled, "win unlocks next level")
	navigation.queue_free()
	print("G3B_NAV_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3B_NAV_FAIL " + name)
