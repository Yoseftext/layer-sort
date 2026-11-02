class_name TubeView
extends Button

signal completed
const COLOURS: Array[Color] = TubePainter.COLOURS
var logical_layers: Array[int] = []
var capacity: int = 4
var selected: bool = false
var rich_effects: bool = false
var reduce_motion: bool = false
var visual_delta: float = 0.0:
	set(value):
		visual_delta = value
		queue_redraw()
var transfer_colour: int = 0
var _painter: TubePainter = TubePainter.new()
var _lift: float = 0.0
var _invalid_flash: float = 0.0
var _completion_flash: float = 0.0
var _selection_tween: Tween
var _flash_tween: Tween
var _completion_tween: Tween
var _has_snapshot: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(100, 400)
	focus_mode = Control.FOCUS_ALL
	flat = true
	for state: String in ["normal", "pressed", "hover", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func show_tube(tube: TubeModel, max_layers: int, is_selected: bool, celebrate: bool = false) -> void:
	var was_complete: bool = is_complete()
	logical_layers = tube.layers.duplicate()
	capacity = max_layers
	if selected != is_selected:
		selected = is_selected
		if _selection_tween != null:
			_selection_tween.kill()
		_selection_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_selection_tween.tween_method(_set_lift, _lift, 9.0 if selected else 0.0, 0.08 if reduce_motion else 0.14)
	if celebrate and _has_snapshot and not was_complete and is_complete():
		_completion_flash = 1.0
		if _completion_tween != null:
			_completion_tween.kill()
		_completion_tween = create_tween()
		_completion_tween.tween_method(_set_completion_flash, 1.0, 0.0, 0.1 if reduce_motion else 0.35)
		completed.emit()
	_has_snapshot = true
	queue_redraw()

func is_complete() -> bool:
	if logical_layers.size() != capacity or logical_layers.is_empty():
		return false
	for colour: int in logical_layers:
		if colour != logical_layers[0]:
			return false
	return true

func mouth_position() -> Vector2:
	return global_position + Vector2(size.x * 0.5, 20.0 - _lift)

func flash_invalid() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_invalid_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_invalid_flash, 1.0, 0.0, 0.12)

func _set_lift(value: float) -> void:
	_lift = value
	queue_redraw()

func _set_invalid_flash(value: float) -> void:
	_invalid_flash = value
	queue_redraw()

func _set_completion_flash(value: float) -> void:
	_completion_flash = value
	queue_redraw()

func _draw() -> void:
	var body: Rect2 = Rect2(Vector2(15, 20 - _lift), Vector2(size.x - 30, size.y - 54))
	_painter.paint(self, body, logical_layers, capacity, selected or has_focus(), visual_delta, transfer_colour, rich_effects)
	if _invalid_flash > 0.0:
		draw_line(body.position + Vector2(8, 10), body.position + Vector2(body.size.x - 8, 10), Color("ef8292", _invalid_flash), 4.0, true)
	if is_complete():
		var badge: Vector2 = Vector2(size.x * 0.5, size.y - 16)
		draw_circle(badge, 9.0 + _completion_flash * 3.0, Color("7ccda6", 0.25 + _completion_flash * 0.3))
		draw_polyline(PackedVector2Array([badge + Vector2(-4, 0), badge + Vector2(-1, 3), badge + Vector2(5, -4)]), Color("a4edc1"), 2.0, true)
