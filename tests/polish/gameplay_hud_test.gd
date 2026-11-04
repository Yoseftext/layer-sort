extends SceneTree

var checks: int = 0
var failures: int = 0
var output: String

# Presentation-only future-count fixture; packaged loader limit remains unchanged.
class LayoutFixture extends ClassicGame:
	var tube_count: int = 6
	func _ready() -> void:
		layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
		var initial: GameState = LevelLoader.read_file("res://content/levels/level_016.json").state
		while initial.tubes.size() < tube_count:
			initial.tubes.append(TubeModel.new([]))
		_session = GameSession.new(initial)
		_build_ui()
		_refresh()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("HUD_POLISH_FAIL " + label)

func run() -> void:
	output = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for width: int in [600, 720]:
		root.content_scale_size = Vector2i(width, 1600)
		root.size = Vector2i(width, 1600)
		await process_frame
		for language: String in ["ar", "en"]:
			for count: int in [6, 7, 8]:
				var game: ClassicGame = await make_game(width, language, count)
				var original: String = game.committed_snapshot().identity()
				check(game.find_child("GameTitle", true, false) == null and game.find_child("GameHelp", true, false) == null, "no permanent mode/help labels")
				check(not game._status.visible, "feedback hidden at launch")
				check((game.find_child("LevelBadge", true, false) as Label).text == UiText.get_text("level_number", language) % "16", "level16 unpadded")
				check(game._moves.text == UiText.get_text("moves", language) % 0, "moves retained")
				check(game._board.rows.size() == (1 if count == 6 else 2), "responsive row count")
				check(game._board.rows[0].get_child_count() == (6 if count == 6 else 4), "four columns for seven/eight")
				for name: String in ["HomeButton", "PauseButton", "UndoButton", "RestartButton"]:
					var button: Button = game.find_child(name, true, false) as Button
					check(button != null and button.size.x >= 96 and button.size.y >= 96 and root.get_visible_rect().encloses(button.get_global_rect()), "HUD touch bounds " + name)
				for i: int in range(count):
					var view: TubeView = game._views[i]
					check(view.size.x >= 64 and root.get_visible_rect().encloses(view.get_global_rect()), "tube target in viewport")
					if i > 0 and view.get_parent() == game._views[i-1].get_parent():
						check(view.global_position.x >= game._views[i-1].get_global_rect().end.x + 11, "stable LTR tube order with spacing")
				await capture("%d-%s-%dt-layout-fixture" % [width, language, count], (width == 600 and language == "ar" and count == 8) or (width == 720 and language == "en" and count == 6))
				if count == 8:
					check(game._views[4].global_position.y >= game._views[0].get_global_rect().end.y + 71, "row gap")
					# Cross-row valid pour uses existing production input and atomic state.
					game._on_tube_pressed(0)
					game._on_tube_pressed(7)
					check(game.committed_snapshot().move_count == 1, "cross-row input commits once")
					await create_timer(0.6).timeout
					game._on_undo()
					check(game.committed_snapshot().identity() == original, "cross-row Undo exact")
					game.restart_attempt()
					check(game.committed_snapshot().identity() == original, "Restart preserves fixture")
				await icon_pixels(game)
				game.queue_free()
				await process_frame
			await circuit(width, language)
	await completed_tube()
	await audio_lifecycle()
	print("HUD_POLISH_PASS checks=%d" % checks if failures == 0 else "HUD_POLISH_FAIL failures=%d" % failures)
	call_deferred("quit", 0 if failures == 0 else 1)

func make_game(_width: int, language: String, count: int) -> ClassicGame:
	var game: LayoutFixture = LayoutFixture.new()
	game.tube_count = count
	game.language = language
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.2).timeout
	return game

func icon_pixels(game: ClassicGame) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var undo: Rect2 = (game.find_child("UndoButton", true, false) as Control).get_global_rect()
	var restart: Rect2 = (game.find_child("RestartButton", true, false) as Control).get_global_rect()
	var difference: int = 0
	for y: int in range(int(undo.size.y)):
		for x: int in range(int(undo.size.x)):
			var a: Color = image.get_pixelv(Vector2i(undo.position)+Vector2i(x,y))
			var b: Color = image.get_pixelv(Vector2i(restart.position)+Vector2i(x,y))
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.15:
				difference += 1
	check(difference > 100, "Undo and Restart have different rendered silhouettes")

func circuit(width: int, language: String) -> void:
	var game: ClassicGame = ClassicGame.new()
	game.language = language
	game.reduce_motion = true
	game.level_path = "res://content/levels/level_015.json"
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.2).timeout
	var identity: String = game.committed_snapshot().identity()
	check(game._circuit.visible and game._circuit.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Circuit readable without input interception")
	await capture("%d-%s-circuit-locked" % [width,language], width == 600 and language == "ar")
	var board_before: Rect2 = game._views[0].get_global_rect()
	game._on_tube_pressed(1)
	check(game._status.visible and game._status.text == UiText.get_text("reject_gate_closed",language) and game.committed_snapshot().identity() == identity, "localized temporary locked feedback is atomic")
	await create_timer(2.1).timeout
	check(not game._status.visible and game._views[0].get_global_rect() == board_before, "feedback expires without moving board")
	game._on_tube_pressed(0)
	game._on_tube_pressed(2)
	await create_timer(0.15).timeout
	check(game._circuit.state.circuit_open and game._circuit.pulse == 0, "Reduced Motion unlock retained")
	await capture("%d-%s-circuit-open" % [width,language], false)
	game._on_undo()
	check(not game._circuit.state.circuit_open and game.committed_snapshot().identity() == identity, "Undo restores visual and logical gate")
	game.apply_language("en" if language == "ar" else "ar")
	check(not game._status.visible and game.find_child("GameHelp",true,false) == null, "switching language keeps HUD uncluttered")
	game.queue_free()
	await process_frame

func completed_tube() -> void:
	var tube: TubeView = TubeView.new()
	root.add_child(tube)
	tube.position = Vector2(120,300)
	tube.size = Vector2(100,400)
	tube.show_tube(TubeModel.new([0,0,0,0]),4,false)
	await process_frame
	await RenderingServer.frame_post_draw
	check(tube.is_complete(), "completion detection preserved")
	var image: Image = root.get_texture().get_image()
	var p: Vector2i = Vector2i(tube.global_position + Vector2(tube.size.x*0.5,tube.size.y-16))
	var pixel: Color = image.get_pixelv(p)
	check(pixel.g - pixel.r < 0.04, "no green completed badge below tube")
	await capture("completed-no-checkmark",false)
	tube.queue_free()
	await process_frame

func audio_lifecycle() -> void:
	var audio: GameAudio = GameAudio.new()
	root.add_child(audio)
	for cue: String in ["select","pour","invalid","complete","win"]:
		audio.play(cue)
	check(audio._voices.size() == 4, "bounded existing voice pool")
	audio.enabled = false
	for voice: AudioStreamPlayer in audio._voices:
		check(not voice.playing, "mute stops gameplay sounds")
	audio.enabled = true
	audio._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	audio.play("pour")
	for voice: AudioStreamPlayer in audio._voices:
		check(not voice.playing, "focus loss blocks sound")
	audio._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for voice: AudioStreamPlayer in audio._voices:
		voice.stream = null
	await create_timer(0.1).timeout
	audio.queue_free()
	await process_frame

func capture(label: String, preview: bool) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png")) == OK, "fresh rendered capture")
	if preview:
		var encoded: String = Marshalls.raw_to_base64(image.save_png_to_buffer())
		print("HUD_PNG_BEGIN ",label)
		for offset: int in range(0,encoded.length(),4000):
			print("HUD_PNG_CHUNK ",encoded.substr(offset,4000))
		print("HUD_PNG_END ",label)
