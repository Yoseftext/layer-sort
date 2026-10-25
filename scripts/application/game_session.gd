class_name GameSession
extends RefCounted

## Command boundary. Copies prevent UI code from mutating stored snapshots.
var _initial: GameState
var _state: GameState
var _history: Array[GameState] = []
var animation_locked: bool = false


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
	_history.append(_state.copy())
	_state = action.state
	animation_locked = true
	return {"ok": true, "reason": "", "moved": action.moved, "won": WinRules.is_won(_state)}


func finish_animation() -> void:
	animation_locked = false


func undo() -> bool:
	if _history.is_empty():
		return false
	_state = _history.pop_back()
	animation_locked = false
	return true


func restart() -> void:
	_state = _initial.copy()
	_history.clear()
	animation_locked = false


func history_size() -> int:
	return _history.size()
