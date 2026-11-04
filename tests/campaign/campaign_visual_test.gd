extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(720, 1600)
	var output: String = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for number: int in [1, 3, 5, 6, 11, 14]:
		for language: String in ["en", "ar"]:
			var game: ClassicGame = ClassicGame.new()
			game.level_path = "res://content/levels/level_%03d.json" % number
			game.language = language
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			root.add_child(game)
			await create_timer(3.2).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/level_%03d_%s.png" % [number, language])
			var views: Array = game.get("_views")
			for tube: Control in views:
				assert(tube.get_global_rect().end.x <= 720)
				assert(tube.size.x >= 64)
			if number <= 5:
				var first: int = 0
				var state: GameState = game.committed_snapshot()
				var dest: int = state.tubes.size() - 1
				game.call("_on_tube_pressed", first)
				game.call("_on_tube_pressed", dest)
				await create_timer(0.8).timeout
				assert(game.committed_snapshot().move_count == 1)
				assert(not (game.find_child("TutorialToggle", true, false) as Button).visible)
			game.queue_free()
			await process_frame
	var level_map: LevelMapScreen = LevelMapScreen.new()
	level_map.catalog = LevelCatalog.load_catalog().catalog
	level_map.progression = Progression.new(level_map.catalog)
	level_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(level_map)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/map-top.png")
	var last: Button = level_map.find_child("level_014", true, false) as Button
	var scroll: ScrollContainer = last.get_parent().get_parent() as ScrollContainer
	scroll.ensure_control_visible(last)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(last.get_global_rect().end.y <= 1600)
	root.get_texture().get_image().save_png(output + "/map-bottom.png")
	print("CAMPAIGN_VISUAL PASS 12 renders, tutorial commits and tube bounds")
	quit()
