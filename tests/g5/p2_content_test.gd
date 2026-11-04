extends SceneTree

## Finite authored-path proofs: at most 64 commands per fixture, never a generator.
var checks: int = 0
var failures: int = 0
var sequence: int = 0
var repository: SaveRepository
var catalog: LevelCatalog
var progression: Progression

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G5_P2_FAIL " + label)

func _initialize() -> void:
	catalog = LevelCatalog.load_catalog().catalog
	progression = Progression.new(catalog)
	for number: int in range(1, 15):
		check(progression.record_win("level_%03d" % number, 20), "existing completion retained")
	var legacy: Dictionary = progression.completed.duplicate(true)
	repository = SaveRepository.new()
	repository.directory = "user://g5_p2_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repository.directory))
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	var classic: Dictionary = LevelLoader.read_file(catalog.path_for("level_016"))
	var circuit: Dictionary = LevelLoader.read_file(catalog.path_for("level_017"))
	check(classic.ok and classic.state.circuit.is_empty(), "16 is ordinary Classic")
	check(circuit.ok and not circuit.state.circuit.is_empty(), "17 declares existing Circuit")
	check(circuit.state.circuit == LevelLoader.read_file(catalog.path_for("level_015")).state.circuit, "17 reuses exact sensor/gate contract")
	check(classic.palette.size() == 5 and classic.state.tubes.size() == 6, "16 increases colour/space planning")
	check(circuit.palette.size() == 3 and fixtures.level_017.moves > fixtures.level_015.moves, "17 extends introductory planning")
	check(not progression.is_unlocked("level_016") and not progression.is_unlocked("level_017"), "new content initially locked")
	for number: int in [15, 16, 17]:
		var id: String = "level_%03d" % number
		check(progression.is_unlocked(id), "previous victory unlocks " + id)
		var loaded: Dictionary = LevelLoader.read_file(catalog.path_for(id))
		check(loaded.ok, "validated data " + id)
		var session: GameSession = GameSession.new(loaded.state)
		verify_save(session.snapshot(), loaded.state)
		var initial: String = session.snapshot().identity()
		var before: GameState = session.snapshot()
		check(not session.submit(-1, 0).ok and session.snapshot().identity() == initial, "invalid index is atomic")
		check(not session.submit(0, 0).ok and session.snapshot().identity() == initial, "same-tube rejection is atomic")
		if number == 17:
			check(not session.submit(0, 1).ok and not session.submit(1, 3).ok, "closed gate blocks both directions")
			check(session.snapshot().identity() == initial, "locked actions do not mutate")
		var solution: Array = fixtures[id].solution
		check(solution.size() == int(fixtures[id].moves) and solution.size() <= 64, "finite verified path")
		var activation_count: int = 0
		for step: int in range(solution.size()):
			var pair: Array = solution[step]
			before = session.snapshot()
			var transition: Dictionary = session.submit(int(pair[0]), int(pair[1]))
			check(transition.ok, "%s legal production step %d" % [id, step])
			if not transition.ok:
				break
			var committed: GameState = session.snapshot()
			check(committed.move_count == before.move_count + 1, "exactly one committed move")
			check(not session.submit(int(pair[0]), int(pair[1])).ok, "animation lock rejects duplicate input")
			check(session.snapshot().identity() == committed.identity(), "duplicate does not change state")
			if not before.circuit_open and committed.circuit_open:
				activation_count += 1
				if number == 17:
					check(step == 2, "17 requires three planned pours to uncover target")
				check(session.undo() and session.snapshot().identity() == before.identity(), "activation Undo restores entire transition")
				check(session.submit(int(pair[0]), int(pair[1])).ok, "activation can be replayed once")
			session.finish_animation()
			verify_save(session.snapshot(), loaded.state)
			if step == 0:
				check(session.undo() and session.snapshot().identity() == initial, "first move Undo restores board")
				check(session.submit(int(pair[0]), int(pair[1])).ok, "Undo leaves legal replay")
				session.finish_animation()
				var records_before: Dictionary = progression.completed.duplicate(true)
				session.restart()
				check(session.snapshot().identity() == initial, "Restart restores all mechanics")
				check(progression.completed == records_before, "Restart preserves permanent progression")
				check(session.submit(int(pair[0]), int(pair[1])).ok, "restart starts same legal puzzle")
				session.finish_animation()
		check(WinRules.is_won(session.snapshot()), "production-verified solved " + id)
		if number != 16:
			check(activation_count == 1 and session.snapshot().circuit_open, "one required Circuit activation")
			var no_objective: GameState = session.snapshot()
			no_objective.circuit_open = false
			check(not WinRules.is_won(no_objective), "sorted board still requires gate objective")
		check(progression.record_win(id, session.snapshot().move_count), "valid win records completion")
		check(not progression.record_win(id, 1), "duplicate completion/reward refused")
		for old_id: String in legacy:
			check(progression.completed[old_id] == legacy[old_id] and progression.is_unlocked(old_id), "existing progress unchanged")
	check(progression.is_unlocked("level_016") and progression.is_unlocked("level_017"), "15 to16 to17 remains accessible")
	check(progression.is_unlocked("level_018"), "accepted P2 completion unlocks newly packaged18")
	print("G5_P2_PASS checks=%d" % checks if failures == 0 else "G5_P2_FAIL failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func verify_save(state: GameState, initial: GameState) -> void:
	var active: Dictionary = {"level_id":state.level_id, "content_version":state.content_version, "move_count":state.move_count, "tubes":[]}
	for tube: TubeModel in state.tubes:
		active.tubes.append(tube.layers.duplicate())
	if not state.circuit.is_empty():
		active.circuit_open = state.circuit_open
	if not state.circuit.is_empty() and not state.circuit_open:
		var tampered: Dictionary = active.duplicate(true)
		tampered.tubes[int(state.circuit.gate_tube)].reverse()
		check(not repository._valid_active(tampered, catalog), "closed gate rejects altered arrangement with conserved colours")
	sequence += 1
	check(repository.write(sequence, progression.completed, active), "isolated committed save written")
	var saved: Dictionary = repository.load_latest(catalog)
	check(saved.ok and saved.sequence == sequence, "saved progress survives reload")
	if not saved.ok:
		return
	check(saved.completed.size() == progression.completed.size(), "completion count survives reload")
	for id: String in progression.completed:
		check(saved.completed.has(id) and saved.completed[id].stars == progression.completed[id].stars and saved.completed[id].best_moves == progression.completed[id].best_moves, "completion values survive JSON numeric conversion")
	check(saved.active.level_id == state.level_id, "active identity survives reload")
	var restored: GameSession = GameSession.new(initial)
	restored.restore_committed(saved.active)
	check(restored.snapshot().identity() == state.identity(), "board and latch survive exact restore")
