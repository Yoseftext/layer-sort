extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport_width: int = int(OS.get_environment("VISUAL_WIDTH")) if not OS.get_environment("VISUAL_WIDTH").is_empty() else 720
	var viewport_height: int = int(OS.get_environment("VISUAL_HEIGHT")) if not OS.get_environment("VISUAL_HEIGHT").is_empty() else 1600
	root.size = Vector2i(viewport_width, viewport_height)
	var scene: PackedScene = load("res://scenes/game/classic_game.tscn")
	var game: ClassicGame = scene.instantiate() as ClassicGame
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	check(game._views.size() == 5, "fixture tubes rendered")
	check(game._views[0].size.x >= 64.0, "tube hit target has minimum width")
	check(game._views[0].global_position.x >= 0.0, "tube remains on screen")
	check(game._views[4].global_position.x + game._views[4].size.x <= root.get_visible_rect().size.x, "last tube remains in logical viewport")
	await _capture("gameplay-en.png")
	var before: String = game._session.snapshot().identity()
	game._on_tube_pressed(0)
	check(game._views[0].selected, "selection has a visual state")
	await _capture("gameplay-selected.png")
	game._on_tube_pressed(3)
	check(game._session.snapshot().identity() != before, "accepted pour commits once")
	check(game._session.animation_locked, "pour locks gameplay input")
	await create_timer(0.7).timeout
	check(not game._session.animation_locked, "pour releases gameplay input")
	await _capture("gameplay-after-pour.png")
	game.queue_free()
	await process_frame
	var arabic: ClassicGame = scene.instantiate() as ClassicGame
	arabic.language = "ar"
	arabic.reduce_motion = true
	root.add_child(arabic)
	arabic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	check(arabic.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic screen is RTL")
	check(arabic._views[0].global_position.x < arabic._views[1].global_position.x, "tube order is not mirrored")
	await _capture("gameplay-ar.png")
	arabic._on_tube_pressed(0)
	arabic._on_tube_pressed(3)
	await create_timer(0.14).timeout
	check(not arabic._session.animation_locked, "reduced motion releases input by next sampled frame")
	arabic._on_restart()
	var solution: Array[Vector2i] = [Vector2i(0, 3), Vector2i(2, 0), Vector2i(1, 2), Vector2i(1, 3), Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 3), Vector2i(1, 2), Vector2i(0, 1), Vector2i(0, 3)]
	for index: int in range(solution.size()):
		var move: Vector2i = solution[index]
		arabic._on_tube_pressed(move.x)
		arabic._on_tube_pressed(move.y)
		if index == solution.size() - 1:
			arabic._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			await create_timer(0.14).timeout
	var won_state: String = arabic._session.snapshot().identity()
	check(arabic._pending_win, "focus loss retains pending win presentation")
	arabic._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not arabic._pending_win, "focus return resolves pending win once")
	check(arabic._session.snapshot().identity() == won_state, "focus return preserves committed win")
	arabic.queue_free()
	print("VISUAL_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _capture(filename: String) -> void:
	var directory: String = OS.get_environment("VISUAL_CAPTURE_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	await process_frame
	var output: String = directory.path_join(filename)
	var status: Error = root.get_texture().get_image().save_png(output)
	check(status == OK, "screenshot saved: " + filename)


func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("VISUAL_FAIL " + name)
