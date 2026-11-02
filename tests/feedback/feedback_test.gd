extends SceneTree
var checks: int = 0
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("FEEDBACK_FAIL " + message)
		quit(1)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1600)
	root.gui_embed_subwindows = true
	var saves: SaveRepository = SaveRepository.new()
	saves.directory = "user://feedback_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.directory))
	var nav: NavigationCoordinator = NavigationCoordinator.new()
	nav.set("_saves", saves)
	root.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.6).timeout
	var progress: Progression = nav.get("_progression")
	for number: int in range(1, 12):
		progress.record_win("level_%03d" % number, 20)
	nav.open_level("level_010")
	var replay: ClassicGame = nav.current_screen() as ClassicGame
	replay.reduce_motion = true
	replay.call("_on_tube_pressed", 0)
	replay.call("_on_tube_pressed", 4)
	await create_timer(0.2).timeout
	var replay_identity: String = replay.committed_snapshot().identity()
	nav.go_home()
	nav.call("_on_play")
	expect((nav.current_screen() as ClassicGame).committed_snapshot().identity() == replay_identity, "level 10 exact Home Play replay")
	expect(progress.completed.level_010.best_moves == 20, "replay preserves best record")
	nav.set("_active", {})
	nav.call("_on_play")
	var game: ClassicGame = nav.current_screen() as ClassicGame
	expect(game.committed_snapshot().level_id == "level_012", "Play starts next incomplete")
	game.reduce_motion = true
	game.call("_on_tube_pressed", 0)
	game.call("_on_tube_pressed", 5)
	await create_timer(0.2).timeout
	var identity: String = game.committed_snapshot().identity()
	nav.go_home()
	expect(nav.current_screen().find_child("ContinueButton", true, false) == null, "one Play action")
	nav.call("_on_play")
	game = nav.current_screen() as ClassicGame
	expect(game.committed_snapshot().identity() == identity, "Home Play exact committed board")
	nav.queue_free()
	await process_frame
	nav = NavigationCoordinator.new()
	nav.set("_saves", saves)
	root.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.6).timeout
	nav.call("_on_play")
	game = nav.current_screen() as ClassicGame
	expect(game.committed_snapshot().identity() == identity, "relaunch exact committed board")
	nav.open_level("level_001")
	game = nav.current_screen() as ClassicGame
	var before: String = game.committed_snapshot().identity()
	game.call("_on_tube_pressed", 0)
	game.call("_on_tube_pressed", 1)
	expect(game.get("_selected_source") == 1, "invalid full destination switches source")
	expect(game.committed_snapshot().identity() == before, "selection does not mutate")
	game.call("_on_tube_pressed", 1)
	expect(game.get("_selected_source") == -1, "same tap deselects")
	game.call("_on_tube_pressed", 0)
	game.call("_on_tube_pressed", 3)
	game.call("_on_tube_pressed", 1)
	game.call("_on_tube_pressed", 2)
	await create_timer(0.55).timeout
	expect(game.get("_selected_source") == 2, "latest intent only after transfer")
	expect(game.committed_snapshot().move_count == 1, "no duplicate commit")
	game.call("_on_undo")
	expect(game.get("_pending_tap") == -1, "Undo clears intent")
	game.set("_pending_tap", 2)
	nav.call("_open_pause")
	expect(game.get("_pending_tap") == -1, "Pause clears intent")
	nav.call("_close_pause")
	var trail: PourTrail = game.get("_trail")
	for t: float in [0.25, 0.4, 0.6, 0.75]:
		trail.play(game.get("_views")[0], game.get("_views")[3], 1, 0, 10.0)
		trail.call("_set_progress", t)
		expect(is_equal_approx(game.get("_views")[3].visual_delta, PourTrail.transfer_progress(t)), "shared normalized transfer")
		trail.clear()
	nav.go_home()
	nav.set("_active", {})
	progress = nav.get("_progression")
	for number: int in range(1, 15):
		progress.record_win("level_%03d" % number, 20)
	nav.call("_on_play")
	expect(nav.current_screen() is LevelMapScreen, "complete campaign opens explicit replay map")
	print("FEEDBACK_TESTS PASS checks=", checks)
	nav.queue_free()
	await process_frame
	quit()
