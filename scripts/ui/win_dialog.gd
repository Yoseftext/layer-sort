class_name WinDialog
extends AcceptDialog

signal replay_requested
signal map_requested

var _content: VBoxContainer
var _heading: Label
var _summary: Label
var _record: Label
var _warning: Label
var _badge: VictoryBadge
var _celebration: Tween
var _replay_button: Button
var _map_button: Button

func present(language: String, level_id: String, moves: int, save_failed: bool, reduce_motion: bool, stars: int = 1, next_level_id: String = "") -> void:
	if _content == null:
		_build_content()
	title = UiText.get_text("completed", language)
	_content.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ok_button_text = UiText.get_text("next_level", language) % next_level_id.trim_prefix("level_") if not next_level_id.is_empty() else UiText.get_text("level_map", language)
	_replay_button.text = UiText.get_text("replay_level", language)
	_map_button.text = UiText.get_text("level_map", language)
	_map_button.visible = not next_level_id.is_empty()
	_heading.text = UiText.get_text("puzzle_complete", language)
	_summary.text = UiText.get_text("level_number", language) % level_id.trim_prefix("level_") + "  ·  " + UiText.get_text("moves", language) % moves
	_record.text = UiText.get_text("single_star", language) if stars == 1 else UiText.get_text("stars", language) % stars
	_warning.text = UiText.get_text("save_write_error", language) if save_failed else ""
	_warning.visible = save_failed
	ScreenWidgets.show_dialog(self)
	popup_centered(Vector2i(600, 840))
	if _celebration != null:
		_celebration.kill()
	_badge.modulate.a = 0.4
	_celebration = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_celebration.tween_property(_badge, "modulate:a", 1.0, 0.1 if reduce_motion else 0.9)

func _build_content() -> void:
	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = 28
	_content.offset_right = -28
	_content.offset_top = 12
	_content.offset_bottom = -150
	_content.add_theme_constant_override("separation", 16)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_badge = VictoryBadge.new()
	_content.add_child(_badge)
	_heading = ScreenWidgets.label("", 38)
	_content.add_child(_heading)
	_summary = ScreenWidgets.label("", 25, true)
	_content.add_child(_summary)
	_record = ScreenWidgets.label("", 26)
	_record.add_theme_color_override("font_color", Color("f5c65a"))
	_content.add_child(_record)
	_warning = ScreenWidgets.label("", 24)
	_warning.add_theme_color_override("font_color", Color("f3bf77"))
	_content.add_child(_warning)
	_replay_button = ScreenWidgets.button("")
	_replay_button.name = "ReplayButton"
	_style_secondary(_replay_button)
	_content.add_child(_replay_button)
	_replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_map_button = ScreenWidgets.button("")
	_map_button.name = "MapButton"
	_style_secondary(_map_button)
	_content.add_child(_map_button)
	_map_button.pressed.connect(func() -> void: map_requested.emit())


func _style_secondary(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color = Color("253850") if state != "pressed" else Color("29415d")
		style.border_color = Color("3b5d73")
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
