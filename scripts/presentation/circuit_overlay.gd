class_name CircuitOverlay
extends Control

var state: GameState
var views: Array[TubeView] = []
var pulse: float = 0.0
var drawn_sensor_center: Vector2
var drawn_gate_center: Vector2
var _tween: Tween
var _panel: StyleBoxFlat = StyleBoxFlat.new()

func _ready() -> void:
	set_notify_transform(true)
	item_rect_changed.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func present(value: GameState, tubes: Array[TubeView], reduced: bool) -> void:
	var activated: bool = state != null and not state.circuit_open and value.circuit_open
	state = value.copy()
	if views != tubes:
		for tube: TubeView in views:
			if is_instance_valid(tube) and tube.item_rect_changed.is_connected(queue_redraw):
				tube.item_rect_changed.disconnect(queue_redraw)
		views = tubes
		for tube: TubeView in views:
			tube.item_rect_changed.connect(queue_redraw)
	visible = not state.circuit.is_empty()
	if not state.circuit_open or reduced:
		if _tween != null:
			_tween.kill()
		pulse = 0.0
	if activated and not reduced:
		if _tween != null:
			_tween.kill()
		pulse = 1.0
		_tween = create_tween()
		_tween.tween_method(_set_pulse, 1.0, 0.0, 0.35)
	queue_redraw()

func _set_pulse(value: float) -> void:
	pulse = value
	queue_redraw()

## Centers are above the entire tube control, leaving room for the ring pulse
## and lock shackle without overlapping either liquid or the selected tube lift.
func sensor_indicator_position() -> Vector2:
	return _indicator_position(int(state.circuit.sensor_tube))

func gate_indicator_position() -> Vector2:
	return _indicator_position(int(state.circuit.gate_tube))

func _indicator_position(index: int) -> Vector2:
	var tube: TubeView = views[index]
	var tube_to_overlay: Transform2D = get_global_transform_with_canvas().affine_inverse() * tube.get_global_transform_with_canvas()
	return tube_to_overlay * Vector2(tube.size.x * 0.5, -22.0)

func _draw() -> void:
	if state == null or state.circuit.is_empty() or views.is_empty():
		return
	var a: Vector2 = sensor_indicator_position()
	var b: Vector2 = gate_indicator_position()
	drawn_sensor_center = a
	drawn_gate_center = b
	var colour: Color = TubePainter.COLOURS[int(state.circuit.target_colour)]
	draw_line(a, b, Color(0.5, 0.8, 0.9, 0.85 if state.circuit_open else 0.5), 1.5 + pulse, true)
	draw_circle(a, 14.0 + pulse * 4.0, Color(0.05, 0.12, 0.2))
	draw_arc(a, 12.0, 0, TAU, 24, colour, 3.0, true)
	# Target colour uses the same stable numeric symbol as the liquid layers.
	draw_string(ThemeDB.fallback_font, a + Vector2(-4, 5), str(int(state.circuit.target_colour) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_style_box(_lock_panel(), Rect2(b - Vector2(12, 10), Vector2(24, 20)))
	var offset: float = 8.0 * (1.0 - pulse) if state.circuit_open else 0.0
	draw_arc(b + Vector2(offset, -10), 8.0, PI, TAU, 12, Color(0.8, 0.9, 1), 3.0, true)
	if state.circuit_open:
		draw_line(b + Vector2(-6, 0), b + Vector2(-1, 5), Color.WHITE, 2)
		draw_line(b + Vector2(-1, 5), b + Vector2(7, -5), Color.WHITE, 2)

func _lock_panel() -> StyleBoxFlat:
	var box: StyleBoxFlat = _panel
	box.bg_color = Color(0.12, 0.25, 0.3) if state.circuit_open else Color(0.3, 0.22, 0.12)
	box.border_color = Color(0.7, 0.8, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box
