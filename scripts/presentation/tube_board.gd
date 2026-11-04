class_name TubeBoard
extends VBoxContainer

## Stable row-major tube ownership; layout never changes logical tube indices.
var rows: Array[HBoxContainer] = []

func build(count: int) -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_theme_constant_override("separation", 72)
	for index: int in range(2 if count > 6 else 1):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "TubeRow" if index == 0 else "TubeRow2"
		row.layout_direction = Control.LAYOUT_DIRECTION_LTR
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		rows.append(row)

func add_tube(tube: TubeView, index: int, count: int) -> void:
	var columns: int = ceili(float(count) / rows.size())
	rows[index / columns].add_child(tube)

func fit(views: Array[TubeView], available: Vector2) -> void:
	if views.is_empty():
		return
	var columns: int = ceili(float(views.size()) / rows.size())
	var width: float = clampf((available.x - 12.0 * (columns - 1)) / columns, 64.0, 116.0)
	var height: float = minf(400.0 if rows.size() == 1 else 300.0, (available.y - 72.0 * (rows.size() - 1)) / rows.size())
	for tube: TubeView in views:
		tube.custom_minimum_size = Vector2(width, maxf(120.0, height))
