extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G5_VISUAL_FAIL " + label)

func check_text(game: ClassicGame, language: String) -> void:
	check(game.find_child("GameTitle", true, false) == null, "no mode label in gameplay")
	check(game.find_child("GameHelp", true, false) == null, "no persistent lower instruction")
	check(not game._status.visible, "no persistent upper instruction")
	check((game.find_child("LevelBadge", true, false) as Label).text == UiText.get_text("level_number", language) % "15", "localized unpadded Circuit level")

func check_indicators(game: ClassicGame) -> void:
	var overlay: CircuitOverlay = game._circuit
	var state: GameState = game.committed_snapshot()
	for index: int in [int(state.circuit.sensor_tube), int(state.circuit.gate_tube)]:
		var center: Vector2 = overlay.sensor_indicator_position() if index == int(state.circuit.sensor_tube) else overlay.gate_indicator_position()
		center += overlay.global_position
		var tube: Rect2 = game._views[index].get_global_rect()
		check(tube.position.x >= 0 and tube.end.x <= root.get_visible_rect().size.x, "tube fits current narrow viewport")
		check(is_equal_approx(center.x, tube.get_center().x), "indicator centered on its tube")
		check(center.y + 18.0 < tube.position.y, "entire indicator above tube and liquid")
		check(root.get_visible_rect().encloses(Rect2(center - Vector2(18, 18), Vector2(36, 36))), "indicator inside portrait viewport")
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "indicators cannot intercept touch")

func run() -> void:
	var output: String = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for width: int in [720, 600]:
		root.content_scale_size = Vector2i(width, 1600)
		root.size = Vector2i(width, 1600)
		for language: String in ["en", "ar"]:
			var game: ClassicGame = ClassicGame.new()
			game.level_path = "res://content/levels/level_015.json"
			game.language = language
			root.add_child(game)
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await create_timer(0.25).timeout
			var prefix: String = "%d-%s" % [width, language]
			check_text(game, language)
			check_indicators(game)
			var identity: String = game.committed_snapshot().identity()
			var other: String = "ar" if language == "en" else "en"
			game.apply_language(other)
			await process_frame
			check_text(game, other)
			game.apply_language(language)
			await process_frame
			check_text(game, language)
			check(game.committed_snapshot().identity() == identity, "language switching preserves attempt")
			await capture(output.path_join(prefix + "-locked.png"))
			game._on_tube_pressed(1)
			check(game.committed_snapshot().identity() == identity, "locked interaction has no domain mutation")
			check(game._status.text == UiText.get_text("reject_gate_closed", language), "localized locked feedback")
			await capture(output.path_join(prefix + "-locked-feedback.png"))
			game._on_tube_pressed(0)
			game._on_tube_pressed(2)
			check(game.committed_snapshot().circuit_open, "activation opens gate")
			check(game._circuit.pulse > 0.0, "activation pulse starts")
			game._circuit._tween.pause()
			await capture(output.path_join(prefix + "-pulse.png"))
			game._circuit._tween.play()
			await create_timer(0.65).timeout
			check(game._circuit.state.circuit_open and is_zero_approx(game._circuit.pulse), "settled unlocked presentation")
			check_indicators(game)
			await capture(output.path_join(prefix + "-unlocked.png"))
			game._on_undo()
			check(game._circuit.pulse == 0.0, "Undo cancels pulse")
			check(not game._circuit.state.circuit_open, "Undo restores locked presentation")
			check(game.committed_snapshot().identity() == identity, "Undo restores exact state")
			await capture(output.path_join(prefix + "-undo-locked.png"))
			game.reduce_motion = true
			game._on_tube_pressed(0)
			game._on_tube_pressed(2)
			check(game.committed_snapshot().circuit_open and game._circuit.pulse == 0.0, "Reduced Motion opens without pulse")
			await create_timer(0.15).timeout
			await capture(output.path_join(prefix + "-reduced-motion.png"))
			game.queue_free()
			await process_frame
	var classic: ClassicGame = ClassicGame.new()
	root.add_child(classic)
	classic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	for language: String in ["en", "ar"]:
		classic.apply_language(language)
		check(classic.find_child("GameTitle", true, false) == null, "Classic has no mode label")
		check(classic.find_child("GameHelp", true, false) == null and not classic._status.visible, "Classic has no permanent instructions")
	classic.queue_free()
	await process_frame
	print("G5_VISUAL_PASS checks=%d" % checks if failures == 0 else "G5_VISUAL_FAIL failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "screenshot written")
