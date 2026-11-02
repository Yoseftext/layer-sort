extends SceneTree
var nav: NavigationCoordinator
var out: String = OS.get_environment("VISUAL_CAPTURE_DIR")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FEEDBACK_VISUAL_FAIL " + label)
		quit(1)
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func touch(position: Vector2, down: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(720, 1600)
	root.gui_embed_subwindows = true
	var saves: SaveRepository = SaveRepository.new()
	saves.directory = "user://feedback_visual_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.directory))
	nav = NavigationCoordinator.new()
	nav.set("_saves", saves)
	root.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.6).timeout
	await capture("01-home")
	var progress: Progression = nav.get("_progression")
	for number: int in range(1, 10):
		progress.record_win("level_%03d" % number, 20)
	var level: Dictionary = LevelLoader.read_file("res://content/levels/level_010.json")
	nav.set("_active", nav.call("_snapshot_data", level.state))
	nav.show_map()
	await create_timer(0.2).timeout
	await capture("02-grid-en")
	var map: LevelMapScreen = nav.current_screen() as LevelMapScreen
	check((map.get("_grid") as GridContainer).columns == 3, "standard three columns")
	check((map.find_child("level_001", true, false) as Button).text.contains("★"), "completion star readable")
	check((map.find_child("level_010", true, false) as Button).text.contains("Current"), "selected attempt shown")
	# Exercise actual scrolling with a bounded future-size catalog; 14 tiles can fit.
	for number: int in range(15, 61):
		map.catalog.available_level_ids.append("level_%03d" % number)
	map.call("_populate")
	await create_timer(0.2).timeout
	var first: Button = map.find_child("level_001", true, false) as Button
	var start: Vector2 = first.get_global_rect().get_center()
	await touch(start, true)
	for step: int in range(1, 9):
		var event: InputEventScreenDrag = InputEventScreenDrag.new()
		event.index = 0
		event.position = start - Vector2(0, step * 60)
		event.relative = Vector2(0, -60)
		Input.parse_input_event(event)
		await process_frame
	await touch(start - Vector2(0, 480), false)
	check(nav.current_screen() == map, "drag over unlocked button never opens level")
	check((map.get("_scroll") as ScrollContainer).scroll_vertical > 200, "raw touch scrolls")
	await capture("03-dragged-grid")
	var last: Button = map.find_child("level_060", true, false) as Button
	(map.get("_scroll") as ScrollContainer).ensure_control_visible(last)
	await process_frame
	check(last.get_global_rect().end.y < 1600, "last level reachable")
	var locked: Vector2 = last.get_global_rect().get_center()
	await touch(locked, true)
	await touch(locked, false)
	check(nav.current_screen() == map, "locked touch rejected")
	(map.get("_scroll") as ScrollContainer).scroll_vertical = 0
	await process_frame
	start = first.get_global_rect().get_center()
	await touch(start, true)
	await touch(start, false)
	check(nav.current_screen() is ClassicGame, "actual touch tap opens unlocked level")
	root.size = Vector2i(720, 1600)
	var game: ClassicGame = nav.current_screen() as ClassicGame
	game.call("_on_tube_pressed", 0)
	await create_timer(0.16).timeout
	await capture("04-source-a")
	game.call("_on_tube_pressed", 1)
	await create_timer(0.16).timeout
	await capture("05-switch-b")
	game.call("_on_tube_pressed", 3)
	await create_timer(0.16).timeout
	await capture("06-transfer-start")
	var trail: PourTrail = game.get("_trail")
	var tween: Tween = trail.get("_tween")
	if tween != null:
		tween.pause()
	game.set("_animation_token", int(game.get("_animation_token")) + 1)
	# Controlled real renderer frames; do not label these as real-time measurements.
	for phase: float in [0.3, 0.5, 0.7]:
		trail.call("_set_progress", phase)
		await capture("07-transfer-%02d" % int(phase * 100))
	game.get("_session").finish_animation()
	game.call("_refresh")
	trail.clear()
	await create_timer(0.4).timeout
	game.apply_language("ar")
	await capture("08-game-ar")
	nav.go_home()
	var catalog: LevelCatalog = nav.get("_catalog")
	catalog.available_level_ids.resize(14)
	nav.get("_settings").set_language("ar")
	nav.show_map()
	await create_timer(0.2).timeout
	await capture("09-grid-ar")
	print("FEEDBACK_VISUAL %s checks=%d" % ["PASS" if failures == 0 else "FAIL", checks])
	nav.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
