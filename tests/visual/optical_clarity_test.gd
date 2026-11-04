extends SceneTree

var checks: int = 0
var output: String
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	output = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for number: int in [3, 5, 6, 11]:
		for language: String in ["en", "ar"]:
			var game: ClassicGame = await make_game(number, language, 720, false)
			await capture("%d-tubes-%s" % [game._views.size(), language])
			game.queue_free()
			await process_frame
	var game: ClassicGame = await make_game(11, "ar", 600, false)
	await capture("narrow-6-ar")
	game.queue_free()
	await process_frame
	game = await make_game(6, "en", 720, false)
	game._on_tube_pressed(0)
	await create_timer(0.16).timeout
	await capture("selected")
	var before: String = game.committed_snapshot().identity()
	game._on_tube_pressed(4)
	var committed: String = game.committed_snapshot().identity()
	assert(before != committed)
	checks += 1
	# Deterministic presentation samples; slow the scene clock so the normal
	# completion timer cannot clear the ghost while software screenshots read back.
	Engine.time_scale = 0.01
	game._trail._tween.pause()
	for sample: int in range(3):
		game._trail._set_progress(0.30 + float(sample) * 0.20)
		assert(game.committed_snapshot().identity() == committed)
		checks += 1
		await capture("pour-%d" % sample)
	Engine.time_scale = 1.0
	game._trail._tween.play()
	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	game = await make_game(3, "ar", 720, true)
	var solutions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	for move: Array in solutions.level_003.solution:
		game._on_tube_pressed(int(move[0]))
		game._on_tube_pressed(int(move[1]))
		await create_timer(0.14).timeout
	assert(WinRules.is_won(game.committed_snapshot()))
	checks += 1
	await capture("completed-reduced-motion")
	game.queue_free()
	await process_frame
	print("OPTICAL_VISUAL PASS checks=%d" % checks)
	quit()

func make_game(number: int, language: String, width: int, reduced: bool) -> ClassicGame:
	root.content_scale_size = Vector2i(width, 1600)
	root.size = Vector2i(width, 1600)
	var game: ClassicGame = ClassicGame.new()
	game.language = language
	game.reduce_motion = reduced
	game.rich_effects = not reduced
	game.level_path = "res://content/levels/level_%03d.json" % number
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.3).timeout
	for tube: TubeView in game._views:
		assert(tube.get_global_rect().position.x >= 0 and tube.get_global_rect().end.x <= width)
		assert(tube.size.x >= 64)
		checks += 2
	return game

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
