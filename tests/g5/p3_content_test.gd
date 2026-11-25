extends SceneTree

const COMMAND_BUDGET: int = 64
var checks: int = 0
var failures: int = 0
var sequence: int = 0
var catalog: LevelCatalog
var progress: Progression
var saves: SaveRepository
var serializer: NavigationCoordinator

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G5_P3_FAIL " + label)

func _initialize() -> void:
	catalog = LevelCatalog.load_catalog().catalog
	progress = Progression.new(catalog)
	for number: int in range(1, 18):
		check(progress.record_win("level_%03d" % number, number + 10), "synthetic accepted completion")
	var accepted: Dictionary = progress.completed.duplicate(true)
	saves = SaveRepository.new()
	saves.directory = "user://g5_p3_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.directory))
	serializer = NavigationCoordinator.new()
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/g5/p3_metrics.json"))
	for id: String in metrics.accepted_content_sha256:
		check(FileAccess.get_file_as_string(catalog.path_for(id)).sha256_text() == metrics.accepted_content_sha256[id], "accepted content bytes preserved")
	validate_content()
	check(SaveRepository.SCHEMA == 1, "save schema remains1")
	for number: int in [18, 19, 20]:
		var id: String = "level_%03d" % number
		check(progress.is_unlocked(id), "predecessor unlocks " + id)
		var initial: GameState = LevelLoader.read_file(catalog.path_for(id)).state
		var game: GameSession = GameSession.new(initial)
		var path: Array = fixtures[id].solution
		check(path.size() == fixtures[id].moves and path.size() == metrics.levels[id].moves and path.size() <= COMMAND_BUDGET, "bounded fixture length")
		verify_save(game.snapshot(), initial)
		var activations: int = 0
		var later_undos: int = 0
		for step: int in range(path.size()):
			var pair: Array = path[step]
			var before: GameState = game.snapshot()
			var identity: String = before.identity()
			var history: int = game.history_size()
			for source: int in range(-1, before.tubes.size() + 1):
				for destination: int in range(-1, before.tubes.size() + 1):
					if not MoveRules.validate(before, source, destination).is_empty():
						check(not MoveRules.pour(before, source, destination).ok, "pure invalid action rejected")
						check(not game.submit(source, destination).ok and game.snapshot().identity() == identity and game.history_size() == history, "invalid action preserves entire state/history")
			var pure: Dictionary = MoveRules.pour(before, int(pair[0]), int(pair[1]))
			var result: Dictionary = game.submit(int(pair[0]), int(pair[1]))
			check(pure.ok and result.ok, "legal production step " + id)
			if not pure.ok or not result.ok:
				break
			check(before.identity() == identity, "pure transition cannot mutate source snapshot")
			var committed: GameState = game.snapshot()
			check(committed.identity() == pure.state.identity() and committed.move_count == step + 1, "session commits pure result once")
			check(not game.submit(int(pair[0]), int(pair[1])).ok and game.snapshot().identity() == committed.identity(), "duplicate input locked")
			if number == 19 and committed.circuit_open:
				if not before.circuit_open:
					activations += 1
					check(game.undo() and not game.snapshot().circuit_open and game.snapshot().identity() == identity, "activation Undo closes gate atomically")
				else:
					later_undos += 1
					check(game.undo() and game.snapshot().circuit_open and game.snapshot().identity() == identity, "later Undo retains open latch")
				check(game.submit(int(pair[0]), int(pair[1])).ok, "same command legally reapplied after Undo")
			game.finish_animation()
			verify_save(game.snapshot(), initial)
			if step == 0 or (number == 19 and not before.circuit_open and committed.circuit_open):
				var records_before: Dictionary = progress.completed.duplicate(true)
				var probe: GameSession = GameSession.new(initial)
				probe.restore_committed(serializer._snapshot_data(game.snapshot()))
				probe.restart()
				check(probe.snapshot().identity() == initial.identity() and probe.history_size() == 0, "Restart restores authored state/history/latch")
				check(progress.completed == records_before, "Restart retains permanent progress")
			check(WinRules.is_won(game.snapshot()) == (step == path.size() - 1), "victory only at complete verified path")
		check(WinRules.is_won(game.snapshot()), "complete path wins " + id)
		if number == 19:
			check(activations == 1 and later_undos > 0 and game.snapshot().circuit_open, "one activation and tested later latch Undo")
			var closed: GameState = game.snapshot()
			closed.circuit_open = false
			check(not WinRules.is_won(closed), "sorting cannot bypass required gate")
		check(progress.record_win(id, game.snapshot().move_count), "valid victory recorded")
		var best: int = progress.completed[id].best_moves
		check(not progress.record_win(id, best + 1) and progress.completed[id].best_moves == best, "replay cannot duplicate reward or overwrite best")
		for old_id: String in accepted:
			check(progress.completed[old_id] == accepted[old_id] and progress.is_unlocked(old_id), "all accepted progress retained")
	sequence += 1
	check(saves.write(sequence, progress.completed, {}), "save final campaign completion")
	var final_save: Dictionary = saves.load_latest(catalog)
	var final_progress: Progression = Progression.new(catalog)
	check(final_save.ok and final_progress.load_records(final_save.completed) and final_progress.completed.size() == 20 and final_save.active.is_empty(), "all20 completions survive reload")
	check(not progress.is_unlocked("level_021") and catalog.path_for("level_021").is_empty(), "no nonexistent21")
	serializer.free()
	print("G5_P3_PASS checks=%d" % checks if failures == 0 else "G5_P3_FAIL failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func verify_save(state: GameState, initial: GameState) -> void:
	sequence += 1
	check(saves.write(sequence, progress.completed, serializer._snapshot_data(state)), "real serializer writes committed state")
	var loaded: Dictionary = saves.load_latest(catalog)
	check(loaded.ok and loaded.sequence == sequence, "newest valid slot restored")
	if not loaded.ok:
		return
	check(loaded.completed.size() == progress.completed.size(), "all completions preserved")
	for id: String in progress.completed:
		check(loaded.completed.has(id) and loaded.completed[id].stars == progress.completed[id].stars and loaded.completed[id].best_moves == progress.completed[id].best_moves, "record values preserved across JSON")
	var restored: GameSession = GameSession.new(initial)
	restored.restore_committed(loaded.active)
	check(restored.snapshot().identity() == state.identity(), "exact active identity board moves and latch restored")

func validate_content() -> void:
	check(catalog.available_level_ids.size() == 20, "exact20-level catalog")
	for number: int in [18, 19, 20]:
		var id: String = "level_%03d" % number
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog.path_for(id)))
		var loaded: Dictionary = LevelLoader.from_data(raw)
		check(loaded.ok and loaded.state.level_id == id and loaded.state.content_version == 1, "strict level identity/version")
		check(loaded.state.circuit.is_empty() == (number != 19), "explicit Classic Circuit Classic allocation")
		for key: String in ["schema_version", "content_version", "capacity"]:
			var invalid: Dictionary = raw.duplicate(true)
			invalid[key] = 999
			check(not LevelLoader.from_data(invalid).ok, "reject unsupported " + key)
		var bad_id: Dictionary = raw.duplicate(true)
		bad_id.level_id = "../escape"
		check(not LevelLoader.from_data(bad_id).ok, "reject invalid identifier")
		var bad_colour: Dictionary = raw.duplicate(true)
		bad_colour.tubes_bottom_to_top[0][0] = raw.palette.size()
		check(not LevelLoader.from_data(bad_colour).ok, "reject colour outside palette")
		var bad_palette: Dictionary = raw.duplicate(true)
		bad_palette.palette[1] = bad_palette.palette[0]
		check(not LevelLoader.from_data(bad_palette).ok, "reject duplicate palette")
		var missing: Dictionary = raw.duplicate(true)
		missing.erase("mechanics")
		check(not LevelLoader.from_data(missing).ok, "mechanic declaration required")
		if number == 19:
			check(raw.mechanics.size() == 1 and raw.mechanics[0].version == 1 and loaded.state.tubes[1].layers.size() == 4, "one existing gate protects required liquid")
			for key: String in ["sensor_tube", "gate_tube", "target_colour", "version"]:
				var invalid: Dictionary = raw.duplicate(true)
				invalid.mechanics[0][key] = 999
				check(not LevelLoader.from_data(invalid).ok, "invalid Circuit reference/version rejected")
			var initially_active: Dictionary = raw.duplicate(true)
			initially_active.mechanics[0].target_colour = raw.tubes_bottom_to_top[0].back()
			check(not LevelLoader.from_data(initially_active).ok, "no pre-move activation")
	var invalid_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelCatalog.CATALOG_PATH))
	invalid_catalog.available_level_ids.append("level_020")
	check(not LevelCatalog.from_data(invalid_catalog).ok, "duplicate catalog identity rejected")
	check(not LevelLoader.from_data("{truncated").ok, "non-JSON root rejected")
