extends SceneTree

class FailingWrite extends SaveRepository:
	func _write_temp(_path: String, _contents: String) -> bool:
		return false

class FailingReplace extends SaveRepository:
	func _replace_temp(_temporary: String, _target: String) -> bool:
		return false

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
	check(saves.load_latest(catalog).status == "NO_SAVE" or saves.load_latest(catalog).ok, "missing save distinguished")
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
	var tampered: FileAccess = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	tampered.store_string('{"payload":{"save_schema_version":1,"sequence":2,"completed":{},"active":{}},"checksum":"incorrect"}')
	tampered.close()
	check(saves.load_latest(catalog).sequence == 1, "checksum mismatch recovers older")
	var future: FileAccess = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	future.store_string('{"payload":{"save_schema_version":2},"checksum":"x"}')
	future.close()
	check(saves.load_latest(catalog).sequence == 1, "unsupported schema preserves older")
	var future_payload: Dictionary = {"save_schema_version": 2, "sequence": 3, "completed": {}, "active": {}}
	var canonical: String = JSON.stringify(JSON.parse_string(JSON.stringify(future_payload, "", true)), "", true)
	var future_envelope: Dictionary = {"payload": future_payload, "checksum": canonical.sha256_text()}
	future = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	future.store_string(JSON.stringify(future_envelope))
	future.close()
	var recovered: Dictionary = saves.load_latest(catalog)
	check(recovered.status == "UNSUPPORTED_VERSION" and recovered.sequence == 1, "future schema blocks downgrade")
	check(saves.write_result(3, progress.completed, active).status == "UNSUPPORTED_VERSION", "future slot not overwritten")
	var failed_write: FailingWrite = FailingWrite.new()
	failed_write.directory = saves.directory
	check(failed_write.write_result(5, progress.completed, active).status == "WRITE_FAILED", "write failure reported")
	var failed_replace: FailingReplace = FailingReplace.new()
	failed_replace.directory = saves.directory
	check(failed_replace.write_result(5, progress.completed, active).status == "REPLACE_FAILED", "replace failure reported")
	check(not FileAccess.file_exists(saves.directory.path_join("save_a.json.tmp")), "failed replacement temp cleaned")
	check(FileAccess.file_exists(saves.directory.path_join("save_a.json")), "last valid slot retained")
	check(saves.write_result(1000000001, progress.completed, active).status == "UNSUPPORTED_VERSION", "future schema still blocks writes")
	var temporary: FileAccess = FileAccess.open(saves.directory.path_join("save_a.json.tmp"), FileAccess.WRITE)
	temporary.store_string("{incomplete")
	temporary.close()
	check(saves.load_latest(catalog).sequence == 1, "orphan temp ignored")
	var bounded: SaveRepository = SaveRepository.new()
	bounded.directory = saves.directory
	check(bounded.write_result(1000000001, progress.completed, active).status == "INVALID_SEQUENCE", "sequence bound")
	var oversized: Dictionary = active.duplicate(true)
	oversized.move_count = 1000001
	check(not bounded._valid_active(oversized, catalog), "move bound")
	check(recovered.status == "UNSUPPORTED_VERSION", "future status retained")
	future = FileAccess.open(saves.directory.path_join("save_b.json"), FileAccess.WRITE)
	future.store_string('{"payload":{"save_schema_version":2},"checksum":"future-algorithm"}')
	future.close()
	check(saves.load_latest(catalog).status == "UNSUPPORTED_VERSION", "future checksum algorithm blocks overwrite")
	var invalid: Progression = Progression.new(catalog)
	check(not invalid.load_records({"level_404": {"stars": 1, "best_moves": 1}}), "unknown level refused")
	print("G3B_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3B_FAIL " + name)
