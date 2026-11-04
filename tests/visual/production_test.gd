extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio: GameAudio = GameAudio.new()
	root.add_child(audio)
	audio.play("pour")
	check(audio._voices[0].playing, "cue uses a preallocated voice")
	audio.enabled = false
	check(not audio._voices[0].playing, "mute immediately stops current cue")
	audio.enabled = true
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	audio.play("select")
	check(not audio._voices[1].playing, "resume without focus suppresses new cues")
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	audio._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	audio.play("select")
	check(not audio._voices[1].playing, "focus without resume suppresses new cues")
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not audio._voices[0].playing, "resume does not replay stale audio")
	var scene: PackedScene = load("res://scenes/game/classic_game.tscn")
	var game: ClassicGame = scene.instantiate() as ClassicGame
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var initial: String = game.committed_snapshot().identity()
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	var committed: String = game.committed_snapshot().identity()
	await create_timer(0.32).timeout
	check(game._views[0].self_modulate.a == 0.0, "source ghost replaces only visual source")
	check(game._views[3].visual_delta > 0.0 and game._views[3].visual_delta <= 1.0, "receiver interpolates bounded transfer")
	check(game.committed_snapshot().identity() == committed, "tilt never mutates committed board")
	game._on_undo()
	check(game.committed_snapshot().identity() == initial, "undo cancels pour atomically")
	check(game._views[0].self_modulate.a == 1.0 and game._views[3].visual_delta == 0.0, "undo clears ghost and visual deltas")
	await create_timer(0.4).timeout
	check(game.committed_snapshot().identity() == initial, "stale visual callback cannot recommit")
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	game.restart_attempt()
	check(game._views[0].self_modulate.a == 1.0 and game.committed_snapshot().identity() == initial, "restart clears tilted source")
	game.reduce_motion = true
	var completions: Array[int] = [0]
	for tube: TubeView in game._views:
		tube.completed.connect(func() -> void: completions[0] += 1)
	var solution: Array[Vector2i] = [Vector2i(0,3),Vector2i(2,0),Vector2i(1,2),Vector2i(1,3),Vector2i(0,1),Vector2i(2,0),Vector2i(2,3),Vector2i(1,2),Vector2i(0,1),Vector2i(0,3)]
	for move: Vector2i in solution:
		game._on_tube_pressed(move.x)
		game._on_tube_pressed(move.y)
		await create_timer(0.14).timeout
	check(completions[0] == 3, "one completion cue per newly completed tube")
	game._refresh()
	check(completions[0] == 3, "redraw does not duplicate completion cues")
	check(not game._session.animation_locked and game._trail._progress == 0.0, "reduced motion settles without tilt")
	var fixture: GameState = game.committed_snapshot()
	fixture.move_count = 0
	fixture.tubes = [TubeModel.new([0,0,0,0]), TubeModel.new([1,2,1,2]), TubeModel.new([2,1,2,1]), TubeModel.new([]), TubeModel.new([])]
	game._session = GameSession.new(fixture)
	game._refresh()
	completions[0] = 0
	game._on_tube_pressed(0)
	game._on_tube_pressed(3)
	await create_timer(0.14).timeout
	check(completions[0] == 1, "forward completion gives one cue")
	game._on_undo()
	check(completions[0] == 1, "Undo restoring a completed tube does not celebrate again")
	game.queue_free()
	audio.queue_free()
	await process_frame
	print("G4_PRODUCTION_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G4_PRODUCTION_FAIL " + label)
