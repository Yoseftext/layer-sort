extends SceneTree
var checks: int = 0
func _initialize() -> void:
	var catalog: LevelCatalog = LevelCatalog.load_catalog().catalog
	var solutions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign/solutions.json"))
	var progress: Progression = Progression.new(catalog)
	for id: String in catalog.available_level_ids:
		var loaded: Dictionary = LevelLoader.read_file(catalog.path_for(id))
		assert(loaded.ok)
		assert(progress.is_unlocked(id))
		var session: GameSession = GameSession.new(loaded.state)
		for pair: Array in solutions[id].solution:
			assert(session.submit(int(pair[0]), int(pair[1])).ok)
			session.finish_animation()
			checks += 1
		assert(WinRules.is_won(session.snapshot()))
		assert(progress.record_win(id, session.snapshot().move_count))
		assert(not progress.record_win(id, session.snapshot().move_count))
		checks += 5
	var restored: Progression = Progression.new(catalog)
	assert(restored.load_records({"level_001": {"stars": 1, "best_moves": 10}, "level_002": {"stars": 1, "best_moves": 10}}))
	assert(restored.is_unlocked("level_003") and not restored.is_unlocked("level_004"))
	print("CAMPAIGN_TESTS PASS checks=", checks + 2)
	quit()
