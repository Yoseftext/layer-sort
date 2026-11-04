class_name HomeGlassHero
extends Control

## Decorative original still life using the game's glass material; no game state.
var _painter: TubePainter = TubePainter.new()
func _ready() -> void:
	custom_minimum_size.y = 400
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, 170, -PI * 0.95, PI * 0.95, 64, Color("75d7ea", 0.14), 1.0, true)
	var arrangements: Array[Array] = [[0, 0, 2], [1, 1, 1, 1], [3, 2, 0]]
	for index: int in range(3):
		var layers: Array[int] = []
		layers.assign(arrangements[index])
		var height: float = 255.0 if index == 1 else 215.0
		var body: Rect2 = Rect2(center.x - 116 + float(index) * 86, center.y - height * 0.5, 60, height)
		_painter.paint(self, body, layers, 4, false, 0.0, 0, true)
