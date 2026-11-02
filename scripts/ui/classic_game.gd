class_name ClassicGame
extends Control

signal home_requested
signal pause_requested
signal restart_requested
signal state_committed(state: GameState, won: bool)
signal presentation_complete(won: bool)
var restored_state: Dictionary = {}

## G2 test scene only; future G3 navigation may instantiate this scene.
const LEVEL_PATH: String = "res://content/levels/level_001.json"
const MOVE_MARKER: String = "LAYER_SORT_G2_MOVE"
const READY_MARKER: String = "LAYER_SORT_G2_READY"

var level_path: String = LEVEL_PATH
var language: String = "en"
var reduce_motion: bool = false
var _session: GameSession
var _selected_source: int = -1
var _animation_token: int = 0
var _pending_win: bool = false
var _views: Array[TubeView] = []
var _trail: PourTrail
var _board_row: HBoxContainer
var _status: Label
var _moves: Label
var _contacts: Array[int] = []
var _suspended: bool = false
var _conflicting_touch: bool = false


func has_unsaved_move() -> bool:
	return _session != null and _session.snapshot().move_count > 0


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	var loaded: Dictionary = LevelLoader.read_file(level_path)
	if not loaded.ok:
		push_error("G2_LEVEL_ERROR " + String(loaded.error))
		var error_label: Label = _make_label(UiText.get_text("content_error", language), 28)
		error_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(error_label)
		return
	_session = GameSession.new(loaded.state)
	if not restored_state.is_empty():
		_session.restore_committed(restored_state)
	_build_ui()
	_refresh()
	print(READY_MARKER)


func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("111b2c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	margins.add_theme_constant_override("margin_top", 40)
	margins.add_theme_constant_override("margin_bottom", 40)
	add_child(margins)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margins.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)
	var home: Button = _make_button(UiText.get_text("home", language))
	home.name = "HomeButton"
	home.custom_minimum_size = Vector2(112, 76)
	header.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
	var title: Label = _make_label(UiText.get_text("game_title", language), 30)
	title.name = "GameTitle"
	title.custom_minimum_size.y = 56
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_space: Control = Control.new()
	header_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_space)
	var pause: Button = _make_button(UiText.get_text("pause", language))
	pause.name = "PauseButton"
	pause.custom_minimum_size = Vector2(112, 76)
	header.add_child(pause)
	pause.pressed.connect(func() -> void: pause_requested.emit())
	layout.add_child(title)
	_moves = _make_label(UiText.get_text("moves", language) % 0, 28)
	layout.add_child(_moves)
	_status = _make_label(UiText.get_text("choose", language), 25)
	layout.add_child(_status)
	var board: PanelContainer = PanelContainer.new()
	board.name = "BoardPanel"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("1b2a40")
	panel.border_color = Color("3b5d73")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(28)
	panel.set_content_margin_all(20)
	board.add_theme_stylebox_override("panel", panel)
	layout.add_child(board)
	var center: CenterContainer = CenterContainer.new()
	board.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TubeRow"
	row.add_theme_constant_override("separation", 12)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	center.add_child(row)
	_board_row = row
	var state: GameState = _session.snapshot()
	for index: int in range(state.tubes.size()):
		var tube: TubeView = TubeView.new()
		tube.custom_minimum_size = Vector2(100, 400)
		row.add_child(tube)
		tube.accessibility_name = UiText.get_text("tube", language) % (index + 1)
		tube.pressed.connect(_on_tube_pressed.bind(index))
		_views.append(tube)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(buttons)
	var undo: Button = _make_button(UiText.get_text("undo", language))
	undo.name = "UndoButton"
	buttons.add_child(undo)
	undo.pressed.connect(_on_undo)
	var restart: Button = _make_button(UiText.get_text("restart", language))
	restart.name = "RestartButton"
	buttons.add_child(restart)
	restart.pressed.connect(func() -> void:
		if restart_requested.has_connections():
			restart_requested.emit()
		else:
			_on_restart())
	var help: Label = _make_label(UiText.get_text("game_help", language), 21)
	help.name = "GameHelp"
	help.custom_minimum_size.y = 72
	layout.add_child(help)
	_trail = PourTrail.new()
	_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_trail)
	resized.connect(_update_tube_layout)
	_update_tube_layout()


func _make_label(value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func apply_language(value: String) -> void:
	language = value
	layout_direction = Control.LAYOUT_DIRECTION_RTL if value == "ar" else Control.LAYOUT_DIRECTION_LTR
	for node_name: String in ["HomeButton", "PauseButton", "UndoButton", "RestartButton"]:
		var button: Button = find_child(node_name, true, false) as Button
		var key: String = node_name.trim_suffix("Button").to_lower()
		button.text = UiText.get_text(key, value)
		button.accessibility_name = button.text
	(find_child("GameTitle", true, false) as Label).text = UiText.get_text("game_title", value)
	(find_child("GameHelp", true, false) as Label).text = UiText.get_text("game_help", value)
	_status.text = UiText.get_text("choose_destination", value) % (_selected_source + 1) if _selected_source >= 0 else UiText.get_text("choose", value)
	for index: int in range(_views.size()):
		_views[index].accessibility_name = UiText.get_text("tube", value) % (index + 1)
	_refresh()


func _make_button(value: String) -> Button:
	var button: Button = ScreenWidgets.button(value)
	button.custom_minimum_size = Vector2(170, 92)
	button.add_theme_font_size_override("font_size", 30)
	return button


func _update_tube_layout() -> void:
	if _board_row == null or _views.is_empty():
		return
	var available: float = size.x - 48.0 - 40.0 - 12.0 * float(_views.size() - 1)
	var width: float = clampf(available / float(_views.size()), 64.0, 100.0)
	var height: float = clampf(size.y * 0.29, 200.0, 400.0)
	for tube: TubeView in _views:
		tube.custom_minimum_size = Vector2(width, height)


func _refresh() -> void:
	var state: GameState = _session.snapshot()
	_moves.text = UiText.get_text("moves", language) % state.move_count
	for index: int in range(_views.size()):
		_views[index].show_tube(state.tubes[index], state.capacity, index == _selected_source)


func _on_tube_pressed(index: int) -> void:
	if _session == null or _suspended or _conflicting_touch:
		return
	if _session.animation_locked:
		# Retain the committed result; a transient rejected tap must not leave
		# a stale "in progress" message after the lock expires.
		return
	var state: GameState = _session.snapshot()
	if WinRules.is_won(state):
		_status.text = UiText.get_text("already_won", language)
		return
	if _selected_source < 0:
		if state.tubes[index].layers.is_empty():
			_status.text = UiText.get_text("empty", language)
			print("LAYER_SORT_G2_REJECT EMPTY_SOURCE")
			return
		_selected_source = index
		_status.text = UiText.get_text("choose_destination", language) % (index + 1)
		_refresh()
		return
	if _selected_source == index:
		_selected_source = -1
		_status.text = UiText.get_text("cleared", language)
		_refresh()
		return
	var source: int = _selected_source
	var moved_colour: int = state.tubes[source].layers.back()
	var result: Dictionary = _session.submit(source, index)
	if not result.ok:
		_status.text = UiText.get_text("reject_" + String(result.reason).to_lower(), language)
		_views[index].flash_invalid()
		print("LAYER_SORT_G2_REJECT %s" % result.reason)
		return
	_selected_source = -1
	_pending_win = bool(result.won)
	_status.text = UiText.get_text("pouring", language)
	state_committed.emit(_session.snapshot(), result.won)
	var duration: float = 0.1 if reduce_motion else 0.62
	if not reduce_motion:
		var from: Vector2 = _views[source].global_position + _views[source].size * Vector2(0.5, 0.25) - global_position
		var to: Vector2 = _views[index].global_position + _views[index].size * Vector2(0.5, 0.30) - global_position
		_trail.play(from, to, TubeView.COLOURS[moved_colour], duration)
	print("%s %d %d %d" % [MOVE_MARKER, source, index, result.moved])
	if result.won:
		print("LAYER_SORT_G2_WIN")
	_animation_token += 1
	_unlock_after_delay(_animation_token, duration, result.won, int(result.moved))


func _unlock_after_delay(token: int, duration: float, won: bool, moved: int) -> void:
	await get_tree().create_timer(duration).timeout
	if token == _animation_token and _session != null:
		_session.finish_animation()
		_status.text = UiText.get_text("won", language) if won else UiText.get_text("moved", language) % moved
		_refresh()
		_pending_win = false
		presentation_complete.emit(won)


func _on_undo() -> void:
	if _session == null or _suspended or _conflicting_touch:
		return
	_animation_token += 1
	_pending_win = false
	if _trail != null:
		_trail.clear()
	_selected_source = -1
	_status.text = UiText.get_text("undone", language) if _session.undo() else UiText.get_text("nothing_to_undo", language)
	_refresh()
	state_committed.emit(_session.snapshot(), false)
	print("LAYER_SORT_G2_UNDO %s" % _session.snapshot().identity())


func restart_attempt() -> void:
	_on_restart()


func _on_restart() -> void:
	if _session == null or _suspended or _conflicting_touch:
		return
	_animation_token += 1
	_pending_win = false
	if _trail != null:
		_trail.clear()
	_selected_source = -1
	_session.restart()
	_status.text = UiText.get_text("restarted", language)
	_refresh()
	state_committed.emit(_session.snapshot(), false)
	print("LAYER_SORT_G2_RESTART %s" % _session.snapshot().identity())


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not _contacts.has(touch.index):
			_contacts.append(touch.index)
		elif not touch.pressed:
			_contacts.erase(touch.index)
		if _contacts.size() > 1:
			_conflicting_touch = true
			_selected_source = -1
			if _session != null:
				_status.text = UiText.get_text("one_finger", language)
				_refresh()
		if _conflicting_touch:
			get_viewport().set_input_as_handled()
			if _contacts.is_empty():
				_conflicting_touch = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		_contacts.clear()
		_conflicting_touch = false
		_selected_source = -1
		_animation_token += 1
		if _trail != null:
			_trail.clear()
		if _session != null:
			_session.finish_animation()
			_status.text = UiText.get_text("paused", language)
			_refresh()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_suspended = false
		if _pending_win and _session != null and WinRules.is_won(_session.snapshot()):
			_pending_win = false
			presentation_complete.emit(true)
