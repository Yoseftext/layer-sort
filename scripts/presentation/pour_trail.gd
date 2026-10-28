class_name PourTrail
extends Control

## Temporary visual cue. It never reads or writes GameSession.
var _from: Vector2
var _to: Vector2
var _colour: Color
var _progress: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(from: Vector2, to: Vector2, colour: Color, duration: float) -> void:
	clear()
	_from = from
	_to = to
	_colour = colour
	var tween: Tween = create_tween()
	_tween = tween
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	tween.tween_callback(clear)


func clear() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
	_progress = 0.0
	queue_redraw()


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _progress <= 0.0:
		return
	var control: Vector2 = (_from + _to) * 0.5 + Vector2(0, -110)
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(19):
		var t: float = float(step) / 18.0 * _progress
		points.append(_from * pow(1.0 - t, 2.0) + control * 2.0 * t * (1.0 - t) + _to * t * t)
	draw_polyline(points, Color(_colour, 0.25), 17.0, true)
	draw_polyline(points, _colour, 7.0, true)
	draw_circle(points[points.size() - 1], 7.0, Color(1, 1, 1, 0.75))
