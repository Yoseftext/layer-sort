extends SceneTree
var checks: int = 0
var output: String = OS.get_environment("VISUAL_CAPTURE_DIR")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.content_scale_size = Vector2i(600, 1333)
	root.size = Vector2i(600, 1333)
	root.gui_embed_subwindows = true
	var repo: SaveRepository = SaveRepository.new()
	repo.directory = "user://real_ui_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repo.directory))
	var navigation: NavigationCoordinator = load("res://scenes/navigation/root.tscn").instantiate() as NavigationCoordinator
	navigation.set("_saves", repo)
	root.add_child(navigation)
	await create_timer(0.65).timeout
	var home: HomeScreen = navigation.current_screen() as HomeScreen
	assert(home.find_child("AboutButton", true, false) == null)
	checks += 1
	for name: String in ["MapButton", "SettingsButton"]:
		var icon: OpticalIconButton = home.find_child(name, true, false) as OpticalIconButton
		assert(icon != null and not icon.accessibility_name.is_empty() and icon.size.x >= 96 and icon.size.y >= 96)
		checks += 1
	await capture("home-narrow-en")
	await tap(home.find_child("SettingsButton", true, false) as Control)
	assert(navigation.current_screen() is SettingsScreen)
	checks += 1
	(navigation.get("_settings") as AppSettings).set_language("ar")
	navigation.go_home()
	await capture("home-narrow-ar")
	(navigation.get("_progression") as Progression).record_win("level_001", 10)
	(navigation.get("_progression") as Progression).record_win("level_002", 10)
	assert(navigation.open_level("level_003"))
	var game: ClassicGame = navigation.current_screen() as ClassicGame
	game.reduce_motion = true
	await create_timer(0.2).timeout
	var solutions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	for move: Array in solutions.level_003.solution:
		game._on_tube_pressed(int(move[0]))
		game._on_tube_pressed(int(move[1]))
		await create_timer(0.14).timeout
	var win: WinDialog = navigation.get("_win_dialog") as WinDialog
	assert(win.visible and win.borderless and win.position.x >= 0 and win.position.x + win.size.x <= 600)
	checks += 1
	assert((navigation.get("_win_dimmer") as ColorRect).visible)
	checks += 1
	await capture("win-narrow-ar")
	var identity: String = game.committed_snapshot().identity()
	await tap(game.find_child("RestartButton", true, false) as Control)
	assert(game.committed_snapshot().identity() == identity and win.visible)
	checks += 1
	await tap(win.find_child("ReplayButton", true, false) as Control)
	game = navigation.current_screen() as ClassicGame
	assert(game.committed_snapshot().level_id == "level_003" and game.committed_snapshot().move_count == 0)
	assert(not (navigation.get("_win_dimmer") as ColorRect).visible)
	checks += 2
	await capture("replay-narrow-ar")
	navigation.queue_free()
	await process_frame
	print("REAL_UI_TESTS PASS checks=%d" % checks)
	quit()
func tap(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	if control.get_window() != root:
		position += Vector2(control.get_window().position)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await create_timer(0.15).timeout
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		root.get_texture().get_image().save_png(output + "/" + name + ".png")
