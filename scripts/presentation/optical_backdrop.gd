class_name OpticalBackdrop
extends Control

## Static optical stage: redraw only on resize, no textures, particles or processing.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OpticalTheme.NAVY)
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.52)
	var radius: float = minf(size.x * 0.47, size.y * 0.26)
	# Bounded layered discs form a quiet light pool, not a realtime glow pass.
	for index: int in range(12, 0, -1):
		var factor: float = float(index) / 12.0
		draw_circle(center, radius * factor, Color(0.15, 0.29, 0.39, 0.018), true, -1.0, true)
	draw_arc(center, radius * 0.86, -PI * 0.92, -PI * 0.08, 64, Color("75d7ea", 0.10), 1.0, true)
	draw_arc(center, radius * 0.91, PI * 0.08, PI * 0.92, 64, Color("75d7ea", 0.06), 1.0, true)
	var line_y: float = size.y * 0.66
	draw_line(Vector2(48, line_y), Vector2(size.x - 48, line_y), Color("aabbd0", 0.10), 1.0, true)
