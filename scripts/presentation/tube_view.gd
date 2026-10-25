class_name TubeView
extends Button

## Accessible tap target + original temporary layer drawing. Never owns state.
const COLOURS: Array[Color] = [Color("f46d75"), Color("55d4c3"), Color("f5c65a"), Color("ae9af5"), Color("75acff"), Color("f39a61")]

var logical_layers: Array[int] = []
var capacity: int = 4
var selected: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(106, 440)
	focus_mode = Control.FOCUS_NONE
	flat = true
	queue_redraw()


func show_tube(tube: TubeModel, max_layers: int, is_selected: bool) -> void:
	logical_layers = tube.layers.duplicate()
	capacity = max_layers
	selected = is_selected
	queue_redraw()


func _draw() -> void:
	var outer: Rect2 = Rect2(Vector2(16, 24), Vector2(size.x - 32, size.y - 48))
	draw_rect(outer, Color("1d2b43"), true)
	draw_rect(outer, Color("78d7e9") if selected else Color("839db4"), false, 5.0 if selected else 3.0)
	var inner_width: float = outer.size.x - 12.0
	var height_per_layer: float = (outer.size.y - 16.0) / float(capacity)
	for index: int in range(logical_layers.size()):
		var x: float = outer.position.x + 6.0
		var y: float = outer.end.y - 8.0 - height_per_layer * float(index + 1)
		draw_rect(Rect2(x, y, inner_width, height_per_layer - 3.0), COLOURS[logical_layers[index]], true)
	if selected:
		draw_rect(Rect2(7, 8, size.x - 14, size.y - 16), Color("8cefff"), false, 3.0)
