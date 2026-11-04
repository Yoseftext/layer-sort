class_name LevelCatalog
extends RefCounted

const CATALOG_PATH: String = "res://content/levels/catalog.json"
const LEVEL_DIR: String = "res://content/levels/"

var entry_level_id: String = ""
var available_level_ids: Array[String] = []


static func load_catalog() -> Dictionary:
	var file: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "CATALOG_NOT_FOUND"}
	if file.get_length() > 4096:
		return {"ok": false, "error": "CATALOG_TOO_LARGE"}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "error": "INVALID_CATALOG_JSON"}
	return from_data(parser.data)


static func from_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "INVALID_CATALOG"}
	var data: Dictionary = value
	if data.size() != 3 or not data.has("schema_version") or data.schema_version != 1:
		return {"ok": false, "error": "INVALID_CATALOG_SCHEMA"}
	if not data.has("entry_level_id") or not data.has("available_level_ids"):
		return {"ok": false, "error": "INVALID_CATALOG_FIELDS"}
	if not data.entry_level_id is String or not data.available_level_ids is Array:
		return {"ok": false, "error": "INVALID_CATALOG_FIELDS"}
	if data.available_level_ids.is_empty() or data.available_level_ids.size() > 100:
		return {"ok": false, "error": "INVALID_CATALOG_SIZE"}
	var catalog: LevelCatalog = LevelCatalog.new()
	for raw_id: Variant in data.available_level_ids:
		if not raw_id is String or not _valid_id(raw_id) or catalog.available_level_ids.has(raw_id):
			return {"ok": false, "error": "INVALID_LEVEL_ID"}
		catalog.available_level_ids.append(raw_id)
	if not catalog.available_level_ids.has(data.entry_level_id):
		return {"ok": false, "error": "ENTRY_NOT_AVAILABLE"}
	catalog.entry_level_id = data.entry_level_id
	return {"ok": true, "catalog": catalog}


func path_for(level_id: String) -> String:
	if not _valid_id(level_id) or not available_level_ids.has(level_id):
		return ""
	return LEVEL_DIR + level_id + ".json"


static func _valid_id(level_id: String) -> bool:
	return not level_id.is_empty() and level_id.length() <= 64 and level_id.begins_with("level_") and level_id.is_valid_identifier()
