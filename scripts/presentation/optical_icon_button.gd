class_name OpticalIconButton
extends Button

## Original vector actions. The localized accessible name is independent of the glyph.
var glyph: String = "home"

func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("203247", 0.8) if state == "hover" or state == "pressed" else Color.TRANSPARENT
		style.set_corner_radius_all(24)
		if state == "focus":
			style.border_color = OpticalTheme.ACCENT
			style.set_border_width_all(2)
		add_theme_stylebox_override(state, style)

func set_label(value: String) -> void:
	text = ""
	tooltip_text = value
	accessibility_name = value

func _draw() -> void:
	var color: Color = OpticalTheme.MUTED if disabled else OpticalTheme.INK
	var center: Vector2 = size * 0.5
	draw_set_transform(center, 0.0, Vector2.ONE * 1.25)
	match glyph:
		"home":
			line([Vector2(-14, -1), Vector2(0, -13), Vector2(14, -1)], color)
			line([Vector2(-10, -3), Vector2(-10, 12), Vector2(-3, 12), Vector2(-3, 4), Vector2(4, 4), Vector2(4, 12), Vector2(11, 12), Vector2(11, -3)], color)
		"pause":
			draw_line(Vector2(-6, -12), Vector2(-6, 12), color, 4.0, true)
			draw_line(Vector2(6, -12), Vector2(6, 12), color, 4.0, true)
		"map":
			line([Vector2(-14,-10),Vector2(-4,-14),Vector2(5,-9),Vector2(14,-13),Vector2(14,10),Vector2(5,14),Vector2(-4,9),Vector2(-14,13),Vector2(-14,-10)], color)
			draw_line(Vector2(-4,-14),Vector2(-4,9),color,2.0,true)
			draw_line(Vector2(5,-9),Vector2(5,14),color,2.0,true)
		"settings":
			draw_arc(Vector2.ZERO, 10, 0, TAU, 24, color, 2.0, true)
			draw_arc(Vector2.ZERO, 3, 0, TAU, 16, color, 2.0, true)
			for index: int in range(8):
				var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				draw_line(direction * 10, direction * 15, color, 3.0, true)
		"undo":
			# A single return arrow, distinct from Restart's complete circular path.
			line([Vector2(-14, -3), Vector2(1, -3), Vector2(8, 3), Vector2(8, 12)], color)
			line([Vector2(-6, -11), Vector2(-14, -3), Vector2(-6, 5)], color)
		"restart":
			draw_arc(Vector2.ZERO, 12, -PI * 0.5, PI * 1.35, 28, color, 2.4, true)
			line([Vector2(-12, -9), Vector2(-5, -11), Vector2(-3, -4)], color)

	draw_set_transform(Vector2.ZERO)

func line(points: Array[Vector2], color: Color) -> void:
	draw_polyline(PackedVector2Array(points), color, 2.4, true)

static func make(kind: String, label: String, node_name: String) -> OpticalIconButton:
	var button: OpticalIconButton = OpticalIconButton.new()
	button.glyph = kind
	button.name = node_name
	button.set_label(label)
	button.custom_minimum_size = Vector2(96, 96)
	return button
