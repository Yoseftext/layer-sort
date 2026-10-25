extends Control

## G2 test scene only; future G3 navigation may instantiate this scene.
const LEVEL_PATH: String = "res://content/levels/level_001.json"
const MOVE_MARKER: String = "LAYER_SORT_G2_MOVE"
const READY_MARKER: String = "LAYER_SORT_G2_READY"

var _session: GameSession
var _selected_source: int = -1
var _animation_token: int = 0
var _views: Array[TubeView] = []
var _status: Label
var _moves: Label


func _ready() -> void:
	var loaded: Dictionary = LevelLoader.read_file(LEVEL_PATH)
	if not loaded.ok:
		push_error("G2_LEVEL_ERROR " + String(loaded.error))
		return
	_session = GameSession.new(loaded.state)
	_build_ui()
	_refresh()
	print(READY_MARKER)


func _build_ui() -> void:
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 24)
	margins.add_theme_constant_override("margin_right", 24)
	margins.add_theme_constant_override("margin_top", 90)
	margins.add_theme_constant_override("margin_bottom", 130)
	add_child(margins)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margins.add_child(layout)
	var title: Label = _make_label("LAYER SORT  •  CLASSIC", 38)
	layout.add_child(title)
	_moves = _make_label("Moves: 0", 29)
	layout.add_child(_moves)
	_status = _make_label("Choose a source tube", 26)
	layout.add_child(_status)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	var state: GameState = _session.snapshot()
	for index: int in range(state.tubes.size()):
		var tube: TubeView = TubeView.new()
		tube.custom_minimum_size = Vector2(100, 440)
		row.add_child(tube)
		tube.pressed.connect(_on_tube_pressed.bind(index))
		_views.append(tube)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(buttons)
	var undo: Button = _make_button("Undo")
	buttons.add_child(undo)
	undo.pressed.connect(_on_undo)
	var restart: Button = _make_button("Restart")
	buttons.add_child(restart)
	restart.pressed.connect(_on_restart)
	layout.add_child(_make_label("Tap a tube, then a destination. Test level 001", 22))


func _make_label(value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_button(value: String) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(170, 92)
	button.add_theme_font_size_override("font_size", 30)
	return button


func _refresh() -> void:
	var state: GameState = _session.snapshot()
	_moves.text = "Moves: %d" % state.move_count
	for index: int in range(_views.size()):
		_views[index].show_tube(state.tubes[index], state.capacity, index == _selected_source)


func _on_tube_pressed(index: int) -> void:
	if _session.animation_locked:
		_status.text = "Pour in progress"
		return
	var state: GameState = _session.snapshot()
	if WinRules.is_won(state):
		_status.text = "Puzzle complete! Undo or Restart."
		return
	if _selected_source < 0:
		if state.tubes[index].layers.is_empty():
			_status.text = "That tube is empty"
			print("LAYER_SORT_G2_REJECT EMPTY_SOURCE")
			return
		_selected_source = index
		_status.text = "Source %d selected — choose a destination" % (index + 1)
		_refresh()
		return
	if _selected_source == index:
		_selected_source = -1
		_status.text = "Selection cleared"
		_refresh()
		return
	var source: int = _selected_source
	var result: Dictionary = _session.submit(source, index)
	if not result.ok:
		_status.text = "Cannot pour: " + String(result.reason).replace("_", " ").to_lower()
		print("LAYER_SORT_G2_REJECT %s" % result.reason)
		return
	_selected_source = -1
	_status.text = "Solved!" if result.won else "Moved %d layer(s)" % result.moved
	_refresh()
	print("%s %d %d %d" % [MOVE_MARKER, source, index, result.moved])
	if result.won:
		print("LAYER_SORT_G2_WIN")
	_animation_token += 1
	_unlock_after_delay(_animation_token)


func _unlock_after_delay(token: int) -> void:
	await get_tree().create_timer(0.28).timeout
	if token == _animation_token:
		_session.finish_animation()


func _on_undo() -> void:
	_animation_token += 1
	_selected_source = -1
	_status.text = "Undo" if _session.undo() else "Nothing to undo"
	_refresh()
	print("LAYER_SORT_G2_UNDO %s" % _session.snapshot().identity())


func _on_restart() -> void:
	_animation_token += 1
	_selected_source = -1
	_session.restart()
	_status.text = "Restarted — choose a source tube"
	_refresh()
	print("LAYER_SORT_G2_RESTART %s" % _session.snapshot().identity())
