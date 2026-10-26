class_name Progression
extends RefCounted

var catalog: LevelCatalog
var completed: Dictionary = {}


func _init(level_catalog: LevelCatalog) -> void:
	catalog = level_catalog


func is_unlocked(id: String) -> bool:
	var index: int = catalog.available_level_ids.find(id)
	return index >= 0 and (index == 0 or completed.has(catalog.available_level_ids[index - 1]))


func record_win(id: String, moves: int) -> bool:
	if not is_unlocked(id) or moves < 1:
		return false
	if completed.has(id):
		return false
	completed[id] = {"stars": 1, "best_moves": moves}
	return true


func load_records(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var records: Dictionary = value
	var validated: Dictionary = {}
	for id: Variant in records:
		if not id is String or catalog.path_for(id).is_empty() or not records[id] is Dictionary:
			return false
		var record: Dictionary = records[id]
		if record.size() != 2 or not record.has("stars") or not record.has("best_moves"):
			return false
		if not _positive_integer(record.stars) or record.stars != 1 or not _positive_integer(record.best_moves):
			return false
		validated[id] = record.duplicate()
	for index: int in range(catalog.available_level_ids.size()):
		if validated.has(catalog.available_level_ids[index]) and index > 0 and not validated.has(catalog.available_level_ids[index - 1]):
			return false
	completed = validated
	return true


static func _positive_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= 1 and float(value) == float(int(value))
