extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var loaded: Dictionary = LevelCatalog.load_catalog()
	check(loaded.ok, "catalog")
	var catalog: LevelCatalog = loaded.catalog
	var progress: Progression = Progression.new(catalog)
	check(progress.is_unlocked("level_001") and not progress.is_unlocked("level_002"), "initial lock")
	check(not progress.record_win("level_002", 2), "locked win refused")
	check(progress.record_win("level_001", 3), "first win")
	check(not progress.record_win("level_001", 1), "duplicate win refused")
	check(progress.completed.level_001.best_moves == 3 and progress.is_unlocked("level_002"), "completion retained and next unlocked")
	check(not progress.load_records({"level_002": {"stars": 1, "best_moves": 2}}), "gap refused")
	check(progress.completed.level_001.best_moves == 3, "invalid records do not mutate")
	var saves: SaveRepository = SaveRepository.new()
	saves.directory = "user://g3b_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.directory))
	var initial: Dictionary = LevelLoader.read_file(catalog.path_for("level_001"))
	var tubes: Array = []
	for tube: TubeModel in initial.state.tubes:
		tubes.append(tube.layers.duplicate())
	var active: Dictionary = {"level_id": "level_001", "content_version": 1, "move_count": 0, "tubes": tubes}
	check(saves.write(1, progress.completed, active), "write first slot")
	check(saves.write(2, progress.completed, active), "write second slot")
	check(saves.load_latest(catalog).get("sequence", -1) == 2, "newest valid loaded")
	var damaged: FileAccess = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	damaged.store_string("{partial")
	damaged.close()
	check(saves.load_latest(catalog).sequence == 1, "interrupted newer slot recovers older")
	var future: FileAccess = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	future.store_string('{"payload":{"save_schema_version":2},"checksum":"x"}')
	future.close()
	check(saves.load_latest(catalog).sequence == 1, "unsupported schema preserves older")
	var invalid: Progression = Progression.new(catalog)
	check(not invalid.load_records({"level_404": {"stars": 1, "best_moves": 1}}), "unknown level refused")
	print("G3B_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3B_FAIL " + name)
