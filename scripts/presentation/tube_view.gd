class_name TubeView
extends Button

## Draws a committed tube snapshot; animation and selection are presentation only.
const COLOURS: Array[Color] = [Color("f47783"), Color("55d4c3"), Color("f5c65a"), Color("b7a2fa"), Color("78b8fa"), Color("f5a873")]
const GLASS: Color = Color("a7e8f4")

var logical_layers: Array[int] = []
var capacity: int = 4
var selected: bool = false
var _invalid_flash: float = 0.0
var _flash_tween: Tween
var _glass_style: StyleBoxFlat
var _liquid_styles: Array[StyleBoxFlat] = []


func _ready() -> void:
	custom_minimum_size = Vector2(100, 400)
	focus_mode = Control.FOCUS_ALL
	flat = true
	_glass_style = StyleBoxFlat.new()
	_glass_style.bg_color = Color("233a53", 0.62)
	_glass_style.border_color = GLASS
	_glass_style.set_border_width_all(3)
	_glass_style.set_corner_radius_all(20)
	for colour: Color in COLOURS:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = colour
		style.set_corner_radius_all(6)
		_liquid_styles.append(style)
	queue_redraw()


func show_tube(tube: TubeModel, max_layers: int, is_selected: bool) -> void:
	logical_layers = tube.layers.duplicate()
	capacity = max_layers
	selected = is_selected
	queue_redraw()


func flash_invalid() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_invalid_flash = 1.0
	queue_redraw()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_invalid_flash, 1.0, 0.0, 0.15)


func _set_invalid_flash(value: float) -> void:
	_invalid_flash = value
	queue_redraw()


func _draw() -> void:
	var lift: float = 9.0 if selected else 0.0
	var body: Rect2 = Rect2(Vector2(15, 26 - lift), Vector2(size.x - 30, size.y - 58))
	var halo: Color = Color("75d7ea", 0.20 if selected else 0.06)
	draw_rect(body.grow(10), halo, true)
	_glass_style.border_color = GLASS.lerp(Color("ff9f9f"), _invalid_flash)
	draw_style_box(_glass_style, body)
	var inner: Rect2 = Rect2(body.position + Vector2(7, 9), body.size - Vector2(14, 18))
	var segment_height: float = inner.size.y / float(maxi(capacity, 1))
	for index: int in range(logical_layers.size()):
		var colour_index: int = logical_layers[index]
		if colour_index < 0 or colour_index >= _liquid_styles.size():
			continue
		var segment: Rect2 = Rect2(Vector2(inner.position.x, inner.end.y - segment_height * float(index + 1) + 2), Vector2(inner.size.x, segment_height - 4))
		draw_style_box(_liquid_styles[colour_index], segment)
		draw_rect(Rect2(segment.position + Vector2(4, 4), Vector2(3, maxf(segment.size.y - 8, 1))), Color(1, 1, 1, 0.36), true)
		# Each colour carries a distinct row of dots so the layer is not identified by hue alone.
		for dot: int in range(colour_index + 1):
			draw_circle(segment.position + Vector2(13 + dot * 8, segment.size.y * 0.5), 2.2, Color("152437", 0.68))
	if not logical_layers.is_empty():
		var liquid_top: float = inner.end.y - segment_height * float(logical_layers.size())
		draw_line(Vector2(inner.position.x + 5, liquid_top + 3), Vector2(inner.end.x - 5, liquid_top + 3), Color(1, 1, 1, 0.55), 2.0, true)
	draw_line(body.position + Vector2(9, 12), body.position + Vector2(9, body.size.y * 0.54), Color(1, 1, 1, 0.37), 3.0, true)
	draw_arc(Vector2(body.get_center().x, body.position.y + 3), body.size.x * 0.45, PI, TAU, 18, GLASS, 2.0, true)
	if selected or has_focus():
		draw_rect(Rect2(Vector2(4, 8 - lift), Vector2(size.x - 8, size.y - 24)), Color("8cefff"), false, 3.0)
