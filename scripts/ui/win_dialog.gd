class_name WinDialog
extends AcceptDialog

var _content: VBoxContainer
var _heading: Label
var _summary: Label
var _record: Label
var _warning: Label
var _badge: VictoryBadge
var _celebration: Tween

func present(language: String, level_id: String, moves: int, save_failed: bool, reduce_motion: bool, stars: int = 1) -> void:
	if _content == null:
		_build_content()
	title = UiText.get_text("completed", language)
	_content.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ok_button_text = UiText.get_text("level_map", language)
	_heading.text = UiText.get_text("puzzle_complete", language)
	_summary.text = UiText.get_text("level_number", language) % level_id.trim_prefix("level_") + "  ·  " + UiText.get_text("moves", language) % moves
	_record.text = UiText.get_text("single_star", language) if stars == 1 else UiText.get_text("stars", language) % stars
	_warning.text = UiText.get_text("save_write_error", language) if save_failed else ""
	_warning.visible = save_failed
	ScreenWidgets.show_dialog(self)
	popup_centered(Vector2i(600, 680))
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
