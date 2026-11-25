class_name SaveRepository
extends RefCounted

const SCHEMA: int = 1
const LIMIT: int = 32768
var directory: String = "user://"
var _future_blocked: bool = false


func load_latest(catalog: LevelCatalog) -> Dictionary:
	var best: Dictionary = {"ok": false, "sequence": -1}
	var found: bool = false
	var invalid: bool = false
	var future: bool = false
	for slot: String in ["a", "b"]:
		var path: String = directory.path_join("save_" + slot + ".json")
		if not FileAccess.file_exists(path):
			continue
		found = true
		var candidate: Dictionary = _read(path, catalog)
		if candidate.get("status") == "UNSUPPORTED_VERSION":
			future = true
		elif candidate.ok and candidate.sequence > best.sequence:
			best = candidate
		elif not candidate.ok:
			invalid = true
	_future_blocked = future
	if best.ok:
		best["status"] = "UNSUPPORTED_VERSION" if future else ("RECOVERED" if invalid else "OK")
		best["write_blocked"] = future
		return best
	return {"ok": false, "status": "UNSUPPORTED_VERSION" if future else ("CORRUPT" if found else "NO_SAVE"), "write_blocked": future}


func write_result(sequence: int, completed: Dictionary, active: Dictionary) -> Dictionary:
	if _future_blocked:
		return {"ok": false, "status": "UNSUPPORTED_VERSION"}
	if sequence < 1 or sequence > 1000000000:
		return {"ok": false, "status": "INVALID_SEQUENCE"}
	var payload: Dictionary = {"save_schema_version": SCHEMA, "sequence": sequence, "completed": completed, "active": active}
	var body: String = JSON.stringify(payload, "", true)
	var envelope: Dictionary = {"payload": payload, "checksum": JSON.stringify(JSON.parse_string(body), "", true).sha256_text()}
	var slot: String = "a" if sequence % 2 == 1 else "b"
	var target: String = directory.path_join("save_" + slot + ".json")
	var temporary: String = target + ".tmp"
	if not _write_temp(temporary, JSON.stringify(envelope)):
		_discard_temp(temporary)
		return {"ok": false, "status": "WRITE_FAILED"}
	if not _replace_temp(temporary, target):
		_discard_temp(temporary)
		return {"ok": false, "status": "REPLACE_FAILED"}
	return {"ok": true, "status": "OK"}


func write(sequence: int, completed: Dictionary, active: Dictionary) -> bool:
	return write_result(sequence, completed, active).ok


func _write_temp(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	return written


func _discard_temp(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _replace_temp(temporary: String, target: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target)) == OK


func _read(path: String, catalog: LevelCatalog) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > LIMIT:
		return {"ok": false}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false}
	var envelope: Dictionary = parser.data
	if not envelope.has("payload") or not envelope.payload is Dictionary or not envelope.has("checksum") or not envelope.checksum is String:
		return {"ok": false}
	var payload: Dictionary = envelope.payload
	if not _nonnegative_integer(payload.get("save_schema_version")):
		return {"ok": false}
	if payload.save_schema_version > SCHEMA:
		return {"ok": false, "status": "UNSUPPORTED_VERSION"}
	if JSON.stringify(payload, "", true).sha256_text() != envelope.checksum:
		return {"ok": false}
	if payload.save_schema_version != SCHEMA or not Progression._positive_integer(payload.get("sequence")) or payload.sequence > 1000000000:
		return {"ok": false}
	var progress: Progression = Progression.new(catalog)
	if not progress.load_records(payload.get("completed")):
		return {"ok": false}
	if not _valid_active(payload.get("active"), catalog):
		return {"ok": false}
	if not payload.active.is_empty() and not progress.is_unlocked(payload.active.level_id):
		return {"ok": false}
	return {"ok": true, "sequence": int(payload.sequence), "completed": progress.completed, "active": payload.active}


func _valid_active(value: Variant, catalog: LevelCatalog) -> bool:
	if not value is Dictionary:
		return false
	var active: Dictionary = value
	if active.is_empty():
		return true
	if not active.has("level_id") or not active.level_id is String or catalog.path_for(active.level_id).is_empty():
		return false
	if not Progression._positive_integer(active.get("content_version")) or not _nonnegative_integer(active.get("move_count")) or active.move_count > 1000000:
		return false
	var level: Dictionary = LevelLoader.read_file(catalog.path_for(active.level_id))
	if not level.ok or level.state.content_version != active.content_version:
		return false
	if not active.has("tubes") or not active.tubes is Array or active.tubes.size() != level.state.tubes.size():
		return false
	var counts: Dictionary = {}
	for tube: Variant in active.tubes:
		if not tube is Array or tube.size() > level.state.capacity:
			return false
		for colour: Variant in tube:
			if not _nonnegative_integer(colour) or colour >= level.palette.size():
				return false
			counts[int(colour)] = int(counts.get(int(colour), 0)) + 1
	for index: int in range(level.palette.size()):
		if counts.get(index, 0) != level.state.capacity:
			return false
	return CircuitRules.valid_saved(level.state, active)


static func _nonnegative_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= 0 and float(value) == float(int(value))
