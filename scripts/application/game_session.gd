class_name GameSession
extends RefCounted

## Command boundary. Copies prevent UI code from mutating stored snapshots.
var _initial: GameState
var _state: GameState
var _history: Array[GameState] = []
## Explicit finite safety limit, not a permanent gameplay/save specification.
const MAX_HISTORY: int = 512
var _animation_locked: bool = false
var animation_locked: bool:
	get:
		return _animation_locked


func _init(initial: GameState) -> void:
	_initial = initial.copy()
	_state = initial.copy()


func snapshot() -> GameState:
	return _state.copy()


func submit(source: int, destination: int) -> Dictionary:
	if animation_locked:
		return {"ok": false, "reason": "ANIMATING", "moved": 0}
	if WinRules.is_won(_state):
		return {"ok": false, "reason": "ALREADY_WON", "moved": 0}
	var action: Dictionary = MoveRules.pour(_state, source, destination)
	if not action.ok:
		return {"ok": false, "reason": action.reason, "moved": 0}
	if _history.size() >= MAX_HISTORY:
		return {"ok": false, "reason": "HISTORY_FULL", "moved": 0}
	_history.append(_state.copy())
	_state = action.state
	_animation_locked = true
	return {"ok": true, "reason": "", "moved": action.moved, "won": WinRules.is_won(_state)}


func finish_animation() -> void:
	_animation_locked = false


func undo() -> bool:
	if _history.is_empty():
		return false
	_state = _history.pop_back()
	_animation_locked = false
	return true


func restart() -> void:
	_state = _initial.copy()
	_history.clear()
	_animation_locked = false


func history_size() -> int:
	return _history.size()


func restore_committed(saved: Dictionary) -> void:
	var restored: GameState = _initial.copy()
	restored.move_count = saved.move_count
	for index: int in range(restored.tubes.size()):
		var layers: Array[int] = []
		for colour: Variant in saved.tubes[index]:
			layers.append(int(colour))
		restored.tubes[index] = TubeModel.new(layers)
	_state = restored
	_history.clear()
	_animation_locked = false
