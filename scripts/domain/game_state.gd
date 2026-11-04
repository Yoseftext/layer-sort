class_name GameState
extends RefCounted

## Authoritative Classic state. Presentation must only read copies of it.
var level_id: String = ""
var content_version: int = 1
var capacity: int = 4
var tubes: Array[TubeModel] = []
var move_count: int = 0
var circuit: Dictionary = {}
var circuit_open: bool = false


func copy() -> GameState:
	var result: GameState = GameState.new()
	result.level_id = level_id
	result.content_version = content_version
	result.capacity = capacity
	result.move_count = move_count
	result.circuit = circuit.duplicate(true)
	result.circuit_open = circuit_open
	for tube: TubeModel in tubes:
		result.tubes.append(tube.copy())
	return result


func identity() -> String:
	## G2 debug identity ONLY; no production save/hash-format commitment.
	var parts: PackedStringArray = [level_id, str(content_version), str(capacity), str(move_count)]
	for tube: TubeModel in tubes:
		var layer_parts: PackedStringArray = []
		for colour: int in tube.layers:
			layer_parts.append(str(colour))
		parts.append("[" + ",".join(layer_parts) + "]")
	if not circuit.is_empty():
		parts.append(str(circuit_open))
	return "|".join(parts)
