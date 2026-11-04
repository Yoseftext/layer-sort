class_name AttributionCatalog
extends RefCounted

const PATH: String = "res://content/about/credits.json"


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > 8192:
		return result
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return result
	var data: Dictionary = parser.data
	if data.get("schema_version") != 1 or not data.get("entries") is Array:
		return result
	if data.entries.size() > 32:
		return result
	for item: Variant in data.entries:
		if not item is Dictionary:
			return []
		for field: String in ["name", "role", "license", "url"]:
			if not item.has(field) or not item[field] is String or String(item[field]).length() > 256:
				return []
		result.append(item)
	return result
