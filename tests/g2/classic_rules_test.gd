extends SceneTree

## Run: godot --headless --path . --script res://tests/g2/classic_rules_test.gd
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("RULE_FAIL: " + message)


func _board(rows: Array) -> GameState:
	var state: GameState = GameState.new()
	state.level_id = "test"
	for raw: Array in rows:
		var layers: Array[int] = []
		for colour: int in raw:
			layers.append(colour)
		state.tubes.append(TubeModel.new(layers))
	return state


func _reject(state: GameState, source: int, target: int, expected: String) -> void:
	var before: String = state.identity()
	var result: Dictionary = MoveRules.pour(state, source, target)
	_check(not result.ok and result.reason == expected, "rejection " + expected)
	_check(state.identity() == before and result.state == state, "invalid action preserves original state")


func _run() -> void:
	var state: GameState = _board([[1, 0, 0], [2, 0], []])
	var original: String = state.identity()
	var empty: Dictionary = MoveRules.pour(state, 0, 2)
	_check(empty.ok and empty.moved == 2, "valid empty destination takes contiguous top group")
	_check(empty.state.tubes[0].layers == [1] and empty.state.tubes[2].layers == [0, 0], "top group and source remainder")
	_check(state.identity() == original, "pour does not mutate input")
	var match_move: Dictionary = MoveRules.pour(state, 0, 1)
	_check(match_move.ok and match_move.moved == 2 and match_move.state.tubes[1].layers == [2, 0, 0, 0], "matching target")
	_reject(_board([[1], [2], []]), 0, 1, "COLOUR_MISMATCH")
	_reject(_board([[], [0], []]), 0, 1, "EMPTY_SOURCE")
	_reject(_board([[1], [1, 1, 1, 1], []]), 0, 1, "FULL_DESTINATION")
	_reject(state, 0, 0, "SAME_TUBE")
	_reject(state, -1, 2, "INVALID_INDEX")
	_reject(state, 0, 9, "INVALID_INDEX")
	var partial: GameState = _board([[2, 1, 1, 1], [0, 1, 1], []])
	var partial_result: Dictionary = MoveRules.pour(partial, 0, 1)
	_check(partial_result.ok and partial_result.moved == 1, "partial pour amount")
	_check(partial_result.state.tubes[0].layers == [2, 1, 1], "partial source remainder")
	_check(partial_result.state.tubes[1].layers.size() == 4, "destination capacity")
	_check(_counts(partial) == _counts(partial_result.state), "colour conservation")
	var group: Dictionary = MoveRules.pour(_board([[2, 0, 0], []]), 0, 1)
	_check(group.moved == 2 and group.state.tubes[0].layers == [2], "do not pour deeper colour")
	_check(WinRules.is_won(_board([[0, 0, 0, 0], [1, 1, 1, 1], []])), "full monochrome win")
	_check(not WinRules.is_won(_board([[0, 0], []])), "partly filled is not won")
	_check(not WinRules.is_won(_board([[0, 1, 0, 1], []])), "mixed full is not won")
	var session: GameSession = GameSession.new(partial)
	var before: String = session.snapshot().identity()
	_check(session.submit(0, 1).ok, "session commits partial pour")
	_check(session.history_size() == 1 and session.snapshot().move_count == 1, "one history item and one move")
	_check(session.submit(0, 2).reason == "ANIMATING", "rapid second move rejected")
	_check(session.history_size() == 1, "animation lock prevents duplicate history")
	_check(session.undo() and session.snapshot().identity() == before, "undo exact partial board and move count")
	_check(not session.undo(), "undo without history no-op")
	_check(session.submit(0, 2).ok, "move after undo")
	session.restart()
	_check(session.snapshot().identity() == before and session.history_size() == 0, "restart exact initial state")
	var almost: GameState = _board([[0, 0, 0], [0], []])
	var winning: GameSession = GameSession.new(almost)
	var winning_before: String = winning.snapshot().identity()
	var result: Dictionary = winning.submit(1, 0)
	_check(result.ok and result.won and WinRules.is_won(winning.snapshot()), "win after committed move")
	_check(winning.undo() and winning.snapshot().identity() == winning_before, "undo winning move")
	var replay_a: GameSession = GameSession.new(state)
	var replay_b: GameSession = GameSession.new(state)
	for replay: GameSession in [replay_a, replay_b]:
		_check(replay.submit(0, 2).ok, "deterministic replay first")
		replay.finish_animation()
		_check(replay.submit(1, 2).ok, "deterministic replay second")
	_check(replay_a.snapshot().identity() == replay_b.snapshot().identity(), "identical actions identical identity")
	var good: Dictionary = LevelLoader.read_file("res://content/levels/level_001.json")
	_check(good.ok and good.state.tubes.size() == 5, "individual file level loads")
	var malformed: Dictionary = {"schema_version": 1, "level_id": "fixture", "content_version": 1, "capacity": 4,
		"palette": ["red", "blue"], "tubes_bottom_to_top": [[0, 0, 0, 0], [1, 1, 1, 1], []], "mechanics": []}
	_check(not LevelLoader.from_data(malformed).ok, "already solved fixture rejected")
	malformed.tubes_bottom_to_top[0][0] = 9
	_check(not LevelLoader.from_data(malformed).ok, "out of range colour rejected")
	malformed.tubes_bottom_to_top[0][0] = 0
	malformed.mechanics = ["circuit"]
	_check(not LevelLoader.from_data(malformed).ok, "advanced mechanic rejected in G2")
	malformed.mechanics = []
	malformed.schema_version = 2
	_check(not LevelLoader.from_data(malformed).ok, "unsupported schema rejected")
	_check(not LevelLoader.read_file("user://other.json").ok, "untrusted path rejected")
	var solution: Array[Vector2i] = [Vector2i(0, 3), Vector2i(2, 0), Vector2i(1, 2), Vector2i(1, 3),
		Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 3), Vector2i(1, 2), Vector2i(0, 1), Vector2i(0, 3)]
	if good.ok:
		var puzzle: GameSession = GameSession.new(good.state)
		for step: Vector2i in solution:
			var move: Dictionary = puzzle.submit(step.x, step.y)
			_check(move.ok, "fixture solution legal move " + str(step))
			puzzle.finish_animation()
		_check(WinRules.is_won(puzzle.snapshot()), "fixture solution reaches win")
	print("G2_RULE_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _counts(state: GameState) -> Dictionary:
	var totals: Dictionary = {}
	for tube: TubeModel in state.tubes:
		for colour: int in tube.layers:
			totals[colour] = totals.get(colour, 0) + 1
	return totals
