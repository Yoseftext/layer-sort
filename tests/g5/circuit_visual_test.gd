extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output: String = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(720, 1600)
	for language: String in ["en", "ar"]:
		var game: ClassicGame = ClassicGame.new()
		game.level_path = "res://content/levels/level_015.json"
		game.language = language
		root.add_child(game)
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await create_timer(0.25).timeout
		await capture(output.path_join(language + "-locked.png"))
		var identity: String = game.committed_snapshot().identity()
		game._on_tube_pressed(1)
		assert(game.committed_snapshot().identity() == identity)
		game._on_tube_pressed(0)
		game._on_tube_pressed(2)
		assert(game.committed_snapshot().circuit_open)
		await create_timer(0.12).timeout
		await capture(output.path_join(language + "-pulse.png"))
		await create_timer(0.55).timeout
		await capture(output.path_join(language + "-unlocked.png"))
		game._on_undo()
		assert(game.committed_snapshot().identity() == identity)
		game.queue_free()
		await process_frame
	print("G5_VISUAL_PASS")
	quit()
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
