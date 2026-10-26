class_name ClassicGame
extends Control

signal home_requested
signal pause_requested

## G2 test scene only; future G3 navigation may instantiate this scene.
const LEVEL_PATH: String = "res://content/levels/level_001.json"
const MOVE_MARKER: String = "LAYER_SORT_G2_MOVE"
const READY_MARKER: String = "LAYER_SORT_G2_READY"

var level_path: String = LEVEL_PATH
var language: String = "en"
var _session: GameSession
var _selected_source: int = -1
var _animation_token: int = 0
var _views: Array[TubeView] = []
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
	var home: Button = _make_button(UiText.get_text("home", language))
	home.name = "HomeButton"
	layout.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
	var pause: Button = _make_button(UiText.get_text("pause", language))
	pause.name = "PauseButton"
	layout.add_child(pause)
	pause.pressed.connect(func() -> void: pause_requested.emit())
	_moves = _make_label(UiText.get_text("moves", language) % 0, 29)
	layout.add_child(_moves)
	_status = _make_label(UiText.get_text("choose", language), 26)
	layout.add_child(_status)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TubeRow"
	row.add_theme_constant_override("separation", 12)
	# Tube/colour ordering is logical, not mirrored by Android's RTL locale.
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	center.add_child(row)
	var state: GameState = _session.snapshot()
	for index: int in range(state.tubes.size()):
		var tube: TubeView = TubeView.new()
		tube.custom_minimum_size = Vector2(100, 440)
		row.add_child(tube)
		tube.accessibility_name = UiText.get_text("tube", language) % (index + 1)
		tube.pressed.connect(_on_tube_pressed.bind(index))
		_views.append(tube)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(buttons)
	var undo: Button = _make_button(UiText.get_text("undo", language))
	buttons.add_child(undo)
	undo.pressed.connect(_on_undo)
	var restart: Button = _make_button(UiText.get_text("restart", language))
	buttons.add_child(restart)
	restart.pressed.connect(_on_restart)
	layout.add_child(_make_label(UiText.get_text("game_help", language), 22))


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
	button.accessibility_name = value
	button.custom_minimum_size = Vector2(170, 92)
	button.add_theme_font_size_override("font_size", 30)
	return button


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
	var result: Dictionary = _session.submit(source, index)
	if not result.ok:
		_status.text = UiText.get_text("cannot_pour", language) % String(result.reason).replace("_", " ").to_lower()
		print("LAYER_SORT_G2_REJECT %s" % result.reason)
		return
	_selected_source = -1
	_status.text = UiText.get_text("won", language) if result.won else UiText.get_text("moved", language) % result.moved
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
	if _session == null or _suspended or _conflicting_touch:
		return
	_animation_token += 1
	_selected_source = -1
	_status.text = UiText.get_text("undone", language) if _session.undo() else UiText.get_text("nothing_to_undo", language)
	_refresh()
	print("LAYER_SORT_G2_UNDO %s" % _session.snapshot().identity())


func restart_attempt() -> void:
	_on_restart()


func _on_restart() -> void:
	if _session == null or _suspended or _conflicting_touch:
		return
	_animation_token += 1
	_selected_source = -1
	_session.restart()
	_status.text = UiText.get_text("restarted", language)
	_refresh()
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
		if _session != null:
			_session.finish_animation()
			_status.text = UiText.get_text("paused", language)
			_refresh()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_suspended = false
