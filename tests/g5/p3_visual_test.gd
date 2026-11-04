extends SceneTree

var checks: int = 0
var failures: int = 0
var output: String
var solutions: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G5_P3_VISUAL_FAIL " + label)

func run() -> void:
	output = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	root.gui_embed_subwindows = true
	for number: int in [18, 19, 20]:
		for language: String in ["en", "ar"]:
			root.content_scale_size = Vector2i(720, 1600)
			root.size = Vector2i(720, 1600)
			var game: ClassicGame = ClassicGame.new()
			game.level_path = "res://content/levels/level_%03d.json" % number
			game.language = language
			root.add_child(game)
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await create_timer(0.2).timeout
			check_layout(game, language)
			await capture("level_%03d_%s" % [number, language])
			var original: String = game.committed_snapshot().identity()
			if number == 19:
				game._on_tube_pressed(1)
				check(game.committed_snapshot().identity() == original and game._status.text == UiText.get_text("reject_gate_closed", language), "locked feedback is localized and atomic")
			var first: Array = solutions["level_%03d" % number].solution[0]
			game._on_tube_pressed(int(first[0]))
			game._on_tube_pressed(int(first[1]))
			var committed: String = game.committed_snapshot().identity()
			game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			check(game.committed_snapshot().identity() == committed and not game._session.animation_locked and game._pending_tap == -1, "focus transition settles committed input without duplication")
			game._on_undo()
			check(game.committed_snapshot().identity() == original, "Undo after focus restores exact initial attempt")
			root.content_scale_size = Vector2i(600, 1600)
			root.size = Vector2i(600, 1600)
			game.reduce_motion = true
			await create_timer(0.2).timeout
			check_layout(game, language)
			await capture("level_%03d_%s_narrow_reduced" % [number, language])
			if number == 19:
				for pair: Array in solutions.level_019.solution:
					game._on_tube_pressed(int(pair[0]))
					game._on_tube_pressed(int(pair[1]))
					await create_timer(0.14).timeout
					if game.committed_snapshot().circuit_open:
						break
				check(game.committed_snapshot().circuit_open and game._circuit.pulse == 0.0, "Reduced Motion shows required unlock without pulse")
				await capture("level_019_%s_unlocked" % language)
				game._on_undo()
				check(not game.committed_snapshot().circuit_open, "activation Undo closes visual gate")
			game.restart_attempt()
			check(game.committed_snapshot().identity() == original, "Restart preserves authored content")
			# Focus cancellation invalidates callbacks; let their finite timers settle
			# before freeing test fixtures so the harness owns no suspended pours.
			await create_timer(0.55).timeout
			game.queue_free()
			await process_frame
	await fresh_circuit_matrix()
	for language: String in ["en", "ar"]:
		await final_campaign_flow(language)
	print("G5_P3_VISUAL_PASS checks=%d" % checks if failures == 0 else "G5_P3_VISUAL_FAIL failures=%d" % failures)
	call_deferred("quit", 0 if failures == 0 else 1)

func check_layout(game: ClassicGame, language: String) -> void:
	check(game.layout_direction == (Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR), "language layout direction")
	var circuit: bool = not game.committed_snapshot().circuit.is_empty()
	check((game.find_child("GameTitle", true, false) as Label).text == UiText.get_text("circuit_game_title" if circuit else "game_title", language), "title follows declared mechanic")
	var bounds: Rect2 = root.get_visible_rect()
	for name: String in ["HomeButton", "PauseButton", "UndoButton", "RestartButton"]:
		var button: Button = game.find_child(name, true, false) as Button
		check(button.size.x >= 96 and button.size.y >= 96 and bounds.encloses(button.get_global_rect()), "HUD touch target and viewport " + name)
	for view: TubeView in game._views:
		check(view.size.x >= 64 and bounds.encloses(view.get_global_rect()), "existing tube target bounds")
	check(game._views[0].global_position.x < game._views[1].global_position.x, "logical tube order remains LTR in both languages")

func final_campaign_flow(language: String) -> void:
	var repository: SaveRepository = SaveRepository.new()
	repository.directory = "user://g5_p3_ui_%s_%d" % [language, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repository.directory))
	var nav: NavigationCoordinator = NavigationCoordinator.new()
	nav.set("_saves", repository)
	root.add_child(nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.65).timeout
	(nav.get("_settings") as AppSettings).set_language(language)
	var progress: Progression = nav.get("_progression") as Progression
	for number: int in range(1, 20):
		check(progress.record_win("level_%03d" % number, 30), "synthetic unlocked predecessor")
	check(nav.open_level("level_020"), "final level accessible")
	await solve_final(nav)
	var win: WinDialog = nav.get("_win_dialog") as WinDialog
	check(win != null and win.visible and win.ok_button_text == UiText.get_text("level_map", language), "final primary is Map without nonexistent Next21")
	await capture("level_020_%s_victory" % language)
	var records: Dictionary = progress.completed.duplicate(true)
	(win.find_child("ReplayButton", true, false) as Button).pressed.emit()
	var replay: ClassicGame = nav.current_screen() as ClassicGame
	check(replay != null and replay.committed_snapshot().level_id == "level_020" and replay.committed_snapshot().move_count == 0, "Replay starts20 directly")
	win.confirmed.emit()
	check(nav.current_screen() == replay, "stale victory confirmation cannot replace replay")
	await solve_final(nav)
	check(progress.completed == records, "replay victory preserves all best records and completion count")
	win = nav.get("_win_dialog") as WinDialog
	win.confirmed.emit()
	win.confirmed.emit()
	check(nav.current_screen() is LevelMapScreen, "Map action handles duplicate victory input once")
	nav.go_home()
	var home: HomeScreen = nav.current_screen() as HomeScreen
	check(home.primary_label == UiText.get_text("home_choose_level", language), "fully completed Home offers replay map")
	(home.find_child("PlayButton", true, false) as Button).pressed.emit()
	check(nav.current_screen() is LevelMapScreen and nav._catalog.path_for("level_021").is_empty(), "completed Play opens Map never21 or silent1")
	# Drain test-owned AudioServer playbacks while players are still alive.
	var audio: GameAudio = nav.get("_audio") as GameAudio
	audio.stop_all()
	for voice: AudioStreamPlayer in audio._voices:
		voice.stream = null
	await create_timer(0.2).timeout
	nav.queue_free()
	await process_frame

func solve_final(nav: NavigationCoordinator) -> void:
	var game: ClassicGame = nav.current_screen() as ClassicGame
	game.reduce_motion = true
	for pair: Array in solutions.level_020.solution:
		game._on_tube_pressed(int(pair[0]))
		game._on_tube_pressed(int(pair[1]))
		await create_timer(0.14).timeout
	check(WinRules.is_won(game.committed_snapshot()), "final fixture wins via UI production commands")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "actual Godot screenshot written")

# Fresh roots are essential: a resize-only case can mask RTL layout invalidation.
func fresh_circuit_matrix() -> void:
	for width: int in [600, 720]:
		for language: String in ["ar", "en"]:
			root.content_scale_size = Vector2i(width, 1600)
			root.size = Vector2i(width, 1600)
			await process_frame
			var game: ClassicGame = ClassicGame.new()
			game.level_path = "res://content/levels/level_019.json"
			game.language = language
			game.reduce_motion = true
			root.add_child(game)
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await create_timer(0.25).timeout
			await check_drawn_indicators(game, "%d-%s-initial" % [width, language])
			for pair: Array in solutions.level_019.solution:
				game._on_tube_pressed(int(pair[0]))
				game._on_tube_pressed(int(pair[1]))
				await create_timer(0.14).timeout
				if game.committed_snapshot().circuit_open:
					break
			check(game.committed_snapshot().circuit_open, "fresh scene unlock")
			await check_drawn_indicators(game, "%d-%s-unlocked" % [width, language])
			game._on_undo()
			check(not game.committed_snapshot().circuit_open, "fresh scene Undo closes gate")
			await check_drawn_indicators(game, "%d-%s-undo" % [width, language])
			game.queue_free()
			await process_frame

func check_drawn_indicators(game: ClassicGame, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var overlay: CircuitOverlay = game._circuit
	var transform: Transform2D = overlay.get_global_transform_with_canvas()
	var centers: Array[Vector2] = [transform * overlay.drawn_sensor_center, transform * overlay.drawn_gate_center]
	var state: GameState = game.committed_snapshot()
	var indices: Array[int] = [int(state.circuit.sensor_tube), int(state.circuit.gate_tube)]
	for i: int in range(2):
		var tube: TubeView = game._views[indices[i]]
		var expected: Vector2 = tube.get_global_transform_with_canvas() * Vector2(tube.size.x * 0.5, -22.0)
		check(centers[i].distance_to(expected) < 0.1, "drawn indicator follows actual tube center " + label)
		check(root.get_visible_rect().encloses(Rect2(centers[i] - Vector2(18,18), Vector2(36,36))), "drawn indicator inside viewport " + label)
	await capture("fresh19-" + label)
