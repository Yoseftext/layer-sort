class_name PourTrail
extends Control

signal flow_started
var _flow_began: bool = false

## A disposable visual snapshot. It cannot commit or undo game state.
var _source: TubeView
var _destination: TubeView
var _layers: Array[int] = []
var _origin: Vector2
var _target: Vector2
var _colour: int = 0
var _moved: int = 0
var _capacity: int = 4
var _body_size: Vector2
var _progress: float = 0.0
var _tween: Tween
var _painter: TubePainter = TubePainter.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(source: TubeView, destination: TubeView, moved: int, colour: int, duration: float) -> void:
	clear()
	_flow_began = false
	_source = source
	_destination = destination
	_layers = source.logical_layers.duplicate()
	_origin = source.mouth_position() - global_position
	_target = destination.mouth_position() - global_position
	_body_size = Vector2(source.size.x - 30, source.size.y - 54)
	_capacity = source.capacity
	_moved = moved
	_colour = colour
	_source.self_modulate.a = 0.0
	_destination.transfer_colour = colour
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, duration)

func clear() -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	if is_instance_valid(_source):
		_source.self_modulate.a = 1.0
	if is_instance_valid(_destination):
		_destination.visual_delta = 0.0
	_source = null
	_destination = null
	_progress = 0.0
	queue_redraw()

func _exit_tree() -> void:
	clear()

func _set_progress(value: float) -> void:
	_progress = value
	if is_instance_valid(_source):
		_origin = _source.mouth_position() - global_position
	if is_instance_valid(_destination):
		_target = _destination.mouth_position() - global_position
	if value >= 0.25 and not _flow_began:
		_flow_began = true
		flow_started.emit()
	if is_instance_valid(_destination):
		_destination.visual_delta = float(_moved) * transfer_progress(value)
	queue_redraw()

func _draw() -> void:
	if _progress <= 0.0 or _progress >= 1.0:
		return
	var direction: float = 1.0 if _target.x > _origin.x else -1.0
	var raised: Vector2 = _target + Vector2(-direction * 18, -65)
	var travel: float = smoothstep(0.0, 0.25, _progress) if _progress < 0.25 else 1.0 - smoothstep(0.78, 1.0, _progress)
	var mouth: Vector2 = _origin.lerp(raised, travel)
	var reach: float = raised.x - 40.0 if direction > 0 else size.x - raised.x - 40.0
	var tilt: float = minf(1.12, asin(clampf(reach / _body_size.y, 0.0, 1.0)))
	var rotation_angle: float = direction * tilt * travel
	var amount: float = transfer_progress(_progress)
	var lip: Vector2 = mouth + Vector2(direction * _body_size.x * 0.42, 0).rotated(rotation_angle)
	if _progress >= 0.25 and _progress < 0.75:
		var strength: float = sin(PI * (_progress - 0.25) / 0.5)
		var width: float = 2.0 + 3.0 * strength
		draw_line(lip, _target + Vector2(0, 9), Color(TubePainter.COLOURS[_colour], 0.14 * strength), width + 6.0, true)
		draw_line(lip, _target + Vector2(0, 9), TubePainter.COLOURS[_colour], width, true)
		draw_line(lip, _target + Vector2(0, 9), Color(1, 1, 1, 0.25 * strength), 1.0, true)
	# Rotate around the lip so the liquid bridge joins the mouth, not the tube wall.
	draw_set_transform(mouth, rotation_angle)
	_painter.paint(self, Rect2(Vector2(-_body_size.x * 0.5, 0), _body_size), _layers, _capacity, false, -float(_moved) * amount, _colour, false, false)
	draw_set_transform(Vector2.ZERO)


static func transfer_progress(value: float) -> float:
	return smoothstep(0.25, 0.75, value)
