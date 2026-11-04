extends SceneTree
var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var loaded: Dictionary = LevelLoader.read_file("res://content/levels/level_015.json")
	check(loaded.ok, "fixture loads")
	var initial: GameState = loaded.state
	var session: GameSession = GameSession.new(initial)
	check(MoveRules.validate(initial, 0, 1) == "GATE_CLOSED", "gate destination blocked")
	check(MoveRules.validate(initial, 1, 2) == "GATE_CLOSED", "gate source blocked")
	var identity: String = initial.identity()
	check(not session.submit(0, 1).ok and session.snapshot().identity() == identity, "invalid atomic")
	var sequence: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/g5/solution.json"))
	for pair: Array in sequence:
		check(session.submit(int(pair[0]), int(pair[1])).ok, "verified legal solution step")
		session.finish_animation()
	check(WinRules.is_won(session.snapshot()), "solution wins")
	check(session.snapshot().circuit_open, "latch stays open after sensor colour changes")
	session.restart()
	check(not session.snapshot().circuit_open, "restart closes gate")
	check(session.submit(0, 2).ok and session.snapshot().circuit_open, "correct top activates")
	check(not session.submit(1, 0).ok, "animation blocks duplicate")
	check(session.undo() and session.snapshot().identity() == identity, "undo closes gate atomically")
	var wrong: GameState = initial.copy()
	CircuitRules.after_pour(wrong)
	check(not wrong.circuit_open, "wrong colour inactive")
	wrong.tubes[0] = TubeModel.new()
	CircuitRules.after_pour(wrong)
	check(not wrong.circuit_open, "empty inactive")
	var solved: GameState = session.snapshot()
	solved.tubes = [TubeModel.new([0,0,0,0]), TubeModel.new([1,1,1,1]), TubeModel.new(), TubeModel.new()]
	check(not WinRules.is_won(solved), "objective required")
	var catalog: LevelCatalog = LevelCatalog.load_catalog().catalog
	var repo: SaveRepository = SaveRepository.new()
	repo.directory = "user://g5_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repo.directory))
	var records: Dictionary = {}
	for number: int in range(1, 15):
		records["level_%03d" % number] = {"best_moves": 20, "stars": 1}
	# Boundary validation is also exercised without altering real user saves.
	var legacy: Dictionary = repo._read("res://tests/g5/g4_schema1_save.json", catalog)
	check(legacy.ok and legacy.completed.level_001.best_moves == 3 and legacy.active.level_id == "level_001", "G4 schema1 fixture preserves progress")
	var active: Dictionary = {"level_id":"level_015", "content_version":1, "move_count":1, "tubes":[[0,0],[1,1,0,0],[1,1],[]], "circuit_open":true}
	check(repo._valid_active(active, catalog), "valid persisted latch")
	var restored: GameSession = GameSession.new(initial)
	restored.restore_committed(active)
	check(restored.snapshot().circuit_open and restored.snapshot().move_count == 1, "exact resume latch")
	check(repo.write(1, records, active), "write isolated Circuit save")
	check(repo.load_latest(catalog).ok, "reload actual Circuit envelope")
	check(not CircuitRules.parse([initial.circuit, initial.circuit], 4, 2).ok, "duplicate rejected")
	var definition: Dictionary = initial.circuit.duplicate()
	definition.target_colour = 9
	check(not CircuitRules.parse([definition], 4, 2).ok, "invalid colour rejected")
	definition.target_colour = 0
	definition.gate_tube = 9
	check(not CircuitRules.parse([definition], 4, 2).ok, "invalid tube rejected")
	definition.gate_tube = 1
	definition.name = "unknown"
	check(not CircuitRules.parse([definition], 4, 2).ok, "unknown mechanic rejected")
	active.circuit_open = false
	check(not repo._valid_active(active, catalog), "impossible unlatched matching sensor rejected")
	active.erase("circuit_open")
	check(not repo._valid_active(active, catalog), "missing Circuit latch rejected")
	active.circuit_open = "true"
	check(not repo._valid_active(active, catalog), "reject malformed latch")
	for number: int in range(1,15):
		check(LevelLoader.read_file("res://content/levels/level_%03d.json" % number).state.circuit.is_empty(), "Classic has no mechanics")
	print("G5_CIRCUIT_PASS %d" % checks if failures == 0 else "G5_CIRCUIT_FAIL %d" % failures)
	quit(0 if failures == 0 else 1)
