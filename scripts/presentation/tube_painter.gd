class_name TubePainter
extends RefCounted

## Original vector glass/liquid renderer, shared by static tubes and the pour ghost.
const COLOURS: Array[Color] = [Color("f47783"), Color("55d4c3"), Color("f5c65a"), Color("b7a2fa"), Color("78b8fa"), Color("f5a873")]
var _glass: StyleBoxFlat = StyleBoxFlat.new()
var _inner: StyleBoxFlat = StyleBoxFlat.new()
var _selection: StyleBoxFlat = StyleBoxFlat.new()
var _liquid: Array[StyleBoxFlat] = []

func _init() -> void:
	_glass.bg_color = Color("203c50", 0.38)
	_glass.border_color = Color("b5dce4", 0.72)
	_glass.set_border_width_all(2)
	_glass.set_corner_radius_all(8)
	_glass.corner_radius_bottom_left = 23
	_glass.corner_radius_bottom_right = 23
	_inner.bg_color = Color.TRANSPARENT
	_inner.border_color = Color(1, 1, 1, 0.19)
	_inner.set_border_width_all(1)
	_inner.set_corner_radius_all(18)
	_selection.bg_color = Color.TRANSPARENT
	_selection.border_color = Color("75d7ea", 0.48)
	_selection.set_border_width_all(2)
	_selection.set_corner_radius_all(28)
	for colour: Color in COLOURS:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = colour
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 15
		_liquid.append(style)

func paint(canvas: CanvasItem, body: Rect2, layers: Array[int], capacity: int, selected: bool = false, delta: float = 0.0, added_colour: int = 0, detail: bool = false, grounded: bool = true) -> void:
	if grounded:
		canvas.draw_colored_polygon(_ellipse(Vector2(body.get_center().x, body.end.y + 14), Vector2(body.size.x * 0.6, 6.0)), Color(0.02, 0.05, 0.09, 0.65))
	canvas.draw_style_box(_glass, body)
	_draw_liquid(canvas, body.grow(-6), layers, capacity, delta, added_colour, detail)
	canvas.draw_style_box(_inner, body.grow(-4))
	# Two narrow reflections and an elliptical lip give depth without refraction.
	canvas.draw_line(body.position + Vector2(5, 14), body.position + Vector2(5, body.size.y - 27), Color(1, 1, 1, 0.35), 2.0, true)
	canvas.draw_line(body.position + Vector2(body.size.x - 5, 18), body.end - Vector2(5, 27), Color("75d7ea", 0.2), 2.0, true)
	var rim: PackedVector2Array = PackedVector2Array()
	for step: int in range(25):
		var angle: float = TAU * float(step) / 24.0
		rim.append(Vector2(body.get_center().x + cos(angle) * body.size.x * 0.5, body.position.y + sin(angle) * 5.0))
	canvas.draw_polyline(rim, Color("c2f4fa", 0.85), 2.5, true)
	canvas.draw_polyline(_ellipse(Vector2(body.get_center().x, body.position.y + 3), Vector2(body.size.x * 0.5 - 4, 3)), Color("e7faff", 0.36), 1.0, true)
	canvas.draw_arc(Vector2(body.get_center().x, body.end.y - 19), body.size.x * 0.5 - 6, 0.28, PI - 0.28, 18, Color("b5dce4", 0.30), 3.0, true)
	# Broad softbox edge, plus a thin opposing reflection; light never hides markers.
	canvas.draw_line(body.position + Vector2(8, 25), Vector2(body.position.x + 8, body.end.y - 34), Color(1, 1, 1, 0.10), 5.0, true)
	if detail:
		canvas.draw_rect(Rect2(body.position + Vector2(9, 18), Vector2(5, body.size.y * 0.33)), Color(1, 1, 1, 0.08))
	if selected:
		canvas.draw_style_box(_selection, body.grow(7))

func _draw_liquid(canvas: CanvasItem, inner: Rect2, layers: Array[int], capacity: int, delta: float, added_colour: int, detail: bool) -> void:
	var units: float = clampf(float(layers.size()) + delta, 0.0, float(capacity))
	var height: float = inner.size.y / float(maxi(1, capacity))
	for index: int in range(ceili(units)):
		var amount: float = minf(1.0, units - float(index))
		var colour_index: int = layers[index] if index < layers.size() else added_colour
		if colour_index < 0 or colour_index >= COLOURS.size():
			continue
		var region: Rect2 = Rect2(inner.position.x, inner.end.y - height * (float(index) + amount), inner.size.x, height * amount)
		if index == 0:
			canvas.draw_style_box(_liquid[colour_index], region)
		else:
			canvas.draw_rect(region, COLOURS[colour_index])
		# Narrow lateral attenuation suggests a cylindrical volume without a shader.
		var bands: int = 4 if detail else 2
		for band: int in range(bands):
			var shade: float = 0.16 * (1.0 - float(band) / float(bands))
			var band_width: float = region.size.x * 0.26 / float(bands)
			canvas.draw_rect(Rect2(region.position + Vector2(float(band) * band_width, 0), Vector2(band_width, region.size.y)), Color(0.04, 0.08, 0.15, shade))
			canvas.draw_rect(Rect2(region.position + Vector2(region.size.x - float(band + 1) * band_width, 0), Vector2(band_width, region.size.y)), Color(0.04, 0.08, 0.15, shade * 0.8))
		canvas.draw_colored_polygon(_ellipse(Vector2(region.get_center().x, region.position.y + 2), Vector2(region.size.x * 0.5 - 1, 2.2)), COLOURS[colour_index].lightened(0.10))
		canvas.draw_line(region.position + Vector2(3, 1), region.position + Vector2(region.size.x - 3, 1), Color(1, 1, 1, 0.30), 1.0)
		if amount > 0.65:
			for dot: int in range(colour_index + 1):
				canvas.draw_circle(region.position + Vector2(12 + dot * 7, region.size.y * 0.52), 2.3, Color("152437", 0.72), true, -1.0, true)
	if units > 0:
		var surface: float = inner.end.y - height * units
		var top_colour: int = layers[ceili(units) - 1] if ceili(units) <= layers.size() else added_colour
		var oval: PackedVector2Array = PackedVector2Array()
		for step: int in range(24):
			var angle: float = TAU * float(step) / 24.0
			oval.append(Vector2(inner.get_center().x + cos(angle) * (inner.size.x * 0.5 - 1), surface + 2 + sin(angle) * 3.0))
		canvas.draw_colored_polygon(oval, COLOURS[top_colour].lightened(0.14))
		canvas.draw_line(Vector2(inner.position.x + 2, surface + 2), Vector2(inner.end.x - 2, surface + 2), Color(1, 1, 1, 0.65), 2.0, true)


func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(25):
		var angle: float = TAU * float(step) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
