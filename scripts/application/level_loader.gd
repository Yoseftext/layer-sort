class_name LevelLoader
extends RefCounted

## G2: strict, finite Classic fixture format. Later mechanics need a new parser.
static func read_file(path: String) -> Dictionary:
	if path != path.simplify_path() or path.get_base_dir() != "res://content/levels" or not path.get_file().begins_with("level_") or not path.ends_with(".json"):
		return {"ok": false, "error": "INVALID_PATH"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "FILE_NOT_FOUND"}
	if file.get_length() > 16384:
		return {"ok": false, "error": "LEVEL_TOO_LARGE"}
	var text: String = file.get_as_text()
	if text.length() > 16384:
		return {"ok": false, "error": "LEVEL_TOO_LARGE"}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error": "INVALID_JSON"}
	return from_data(parser.data)


static func from_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "INVALID_ROOT"}
	var data: Dictionary = value
	var required: PackedStringArray = ["schema_version", "level_id", "content_version", "capacity", "palette", "tubes_bottom_to_top", "mechanics"]
	for key: String in required:
		if not data.has(key):
			return {"ok": false, "error": "MISSING_" + key.to_upper()}
	if data.size() != required.size() or not _integer_is(data.schema_version, 1) or not _integer_is(data.content_version, 1):
		return {"ok": false, "error": "UNSUPPORTED_VERSION_OR_FIELDS"}
	if not data.level_id is String or String(data.level_id).length() > 64 or not String(data.level_id).is_valid_identifier():
		return {"ok": false, "error": "INVALID_ID"}
	if not _integer_is(data.capacity, 4):
		return {"ok": false, "error": "INVALID_CAPACITY"}
	if not data.palette is Array or data.palette.size() < 2 or data.palette.size() > 6:
		return {"ok": false, "error": "INVALID_PALETTE"}
	var names: Dictionary = {}
	for name: Variant in data.palette:
		if not name is String or String(name).is_empty() or String(name).length() > 32 or names.has(name):
			return {"ok": false, "error": "INVALID_PALETTE"}
		names[name] = true
	if not data.mechanics is Array or not data.mechanics.is_empty():
		return {"ok": false, "error": "UNSUPPORTED_MECHANIC"}
	if not data.tubes_bottom_to_top is Array or data.tubes_bottom_to_top.size() < 3 or data.tubes_bottom_to_top.size() > 6:
		return {"ok": false, "error": "INVALID_TUBES"}
	var state: GameState = GameState.new()
	state.level_id = data.level_id
	state.content_version = int(data.content_version)
	state.capacity = int(data.capacity)
	var empty_count: int = 0
	var colour_counts: Array[int] = []
	colour_counts.resize(data.palette.size())
	colour_counts.fill(0)
	for raw_tube: Variant in data.tubes_bottom_to_top:
		if not raw_tube is Array or raw_tube.size() > state.capacity:
			return {"ok": false, "error": "INVALID_TUBE"}
		var layers: Array[int] = []
		if raw_tube.is_empty():
			empty_count += 1
		for colour: Variant in raw_tube:
			if typeof(colour) != TYPE_INT and typeof(colour) != TYPE_FLOAT:
				return {"ok": false, "error": "INVALID_COLOUR"}
			if not is_finite(float(colour)) or colour < 0 or colour >= data.palette.size() or float(colour) != float(int(colour)):
				return {"ok": false, "error": "INVALID_COLOUR"}
			layers.append(int(colour))
			colour_counts[int(colour)] += 1
		state.tubes.append(TubeModel.new(layers))
	if empty_count < 1 or empty_count > 2:
		return {"ok": false, "error": "INVALID_EMPTY_COUNT"}
	for amount: int in colour_counts:
		if amount != state.capacity:
			return {"ok": false, "error": "INVALID_COLOUR_QUANTITY"}
	if WinRules.is_won(state):
		return {"ok": false, "error": "ALREADY_SOLVED"}
	return {"ok": true, "state": state, "palette": data.palette.duplicate()}


static func _integer_is(value: Variant, expected: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == expected
