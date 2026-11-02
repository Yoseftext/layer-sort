class_name VictoryBadge
extends Control

## One star matches the current progression reward; no invented three-star economy.
func _ready() -> void:
	custom_minimum_size = Vector2(0, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, 56, Color("f5c65a", 0.08))
	draw_arc(center, 47, 0, TAU, 48, Color("f5c65a", 0.35), 1.5, true)
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(10):
		var angle: float = -PI * 0.5 + float(index) * PI / 5.0
		var radius: float = 32.0 if index % 2 == 0 else 15.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color("f5c65a"))
	points.append(points[0])
	draw_polyline(points, Color("fff0bd"), 1.5, true)
