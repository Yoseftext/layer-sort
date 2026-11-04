class_name CircuitRules
extends RefCounted

## One finite, explicitly declared sensor/gate. No evaluation at initialization.
static func parse(value: Variant, tube_count: int, colours: int) -> Dictionary:
	if not value is Array or value.size() > 1:
		return {"ok": false}
	if value.is_empty():
		return {"ok": true, "definition": {}}
	if not value[0] is Dictionary:
		return {"ok": false}
	var item: Dictionary = value[0]
	if item.size() != 5 or item.get("name") != "layer_circuit" or (typeof(item.get("version")) != TYPE_INT and typeof(item.get("version")) != TYPE_FLOAT) or item.get("version") != 1:
		return {"ok": false}
	for key: String in ["sensor_tube", "gate_tube", "target_colour"]:
		var number: Variant = item.get(key)
		if (typeof(number) != TYPE_INT and typeof(number) != TYPE_FLOAT) or not is_finite(float(number)) or number < 0 or number > 100 or float(number) != floor(float(number)):
			return {"ok": false}
	if item.sensor_tube >= tube_count or item.gate_tube >= tube_count or item.target_colour >= colours or item.sensor_tube == item.gate_tube:
		return {"ok": false}
	return {"ok": true, "definition": item.duplicate(true)}

static func blocked(state: GameState, index: int) -> bool:
	return not state.circuit.is_empty() and not state.circuit_open and int(state.circuit.gate_tube) == index

static func after_pour(state: GameState) -> void:
	if state.circuit.is_empty() or state.circuit_open:
		return
	var tube: TubeModel = state.tubes[int(state.circuit.sensor_tube)]
	if not tube.layers.is_empty() and tube.top() == int(state.circuit.target_colour):
		state.circuit_open = true

static func valid_saved(state: GameState, active: Dictionary) -> bool:
	if state.circuit.is_empty():
		return not active.has("circuit_open")
	if not active.get("circuit_open") is bool:
		return false
	if active.circuit_open:
		return active.move_count > 0
	var gate: int = int(state.circuit.gate_tube)
	if active.tubes[gate] != state.tubes[gate].layers:
		return false
	var sensor: Array = active.tubes[int(state.circuit.sensor_tube)]
	return active.move_count == 0 or sensor.is_empty() or int(sensor.back()) != int(state.circuit.target_colour)
