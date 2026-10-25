class_name MoveRules
extends RefCounted

## Pure validation and atomic transition: never mutate the supplied state.
static func validate(state: GameState, source: int, destination: int) -> String:
	if source < 0 or destination < 0 or source >= state.tubes.size() or destination >= state.tubes.size():
		return "INVALID_INDEX"
	if source == destination:
		return "SAME_TUBE"
	var from_tube: TubeModel = state.tubes[source]
	var to_tube: TubeModel = state.tubes[destination]
	if from_tube.layers.is_empty():
		return "EMPTY_SOURCE"
	if to_tube.layers.size() >= state.capacity:
		return "FULL_DESTINATION"
	if not to_tube.layers.is_empty() and to_tube.top() != from_tube.top():
		return "COLOUR_MISMATCH"
	return ""


static func pour(state: GameState, source: int, destination: int) -> Dictionary:
	var reason: String = validate(state, source, destination)
	if not reason.is_empty():
		return {"ok": false, "reason": reason, "state": state, "moved": 0}
	var result: GameState = state.copy()
	var from_tube: TubeModel = result.tubes[source]
	var to_tube: TubeModel = result.tubes[destination]
	var count: int = mini(from_tube.top_group_size(), result.capacity - to_tube.layers.size())
	for _unit: int in range(count):
		to_tube.layers.append(from_tube.layers.pop_back())
	result.move_count += 1
	return {"ok": true, "reason": "", "state": result, "moved": count}
