class_name ScreenWidgets
extends RefCounted

const INK: Color = Color("#111b2c")
const CARD: Color = Color("#1c2a40")
const TEXT: Color = Color("#f4f7fc")
const MUTED: Color = Color("#aabbd0")
const ACCENT: Color = Color("#75d7ea")


static func background(parent: Control) -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backdrop)


static func stack(parent: Control) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 24
	column.offset_bottom = -24
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	parent.add_child(column)
	return column


static func label(value: String, size: int, muted: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", MUTED if muted else TEXT)
	return node


static func button(value: String, primary: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = value
	style_button(node, primary)
	return node


static func style_button(node: Button, primary: bool = false) -> void:
	node.accessibility_name = node.text
	node.custom_minimum_size = Vector2(0, 96)
	node.add_theme_font_size_override("font_size", 28)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, INK if primary else TEXT)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = ACCENT if primary else CARD
	normal.set_corner_radius_all(24)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	node.add_theme_stylebox_override("normal", normal)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#55b9cf") if primary else Color("#29415d")
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("hover", normal)
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = ACCENT
	focus.set_border_width_all(4)
	node.add_theme_stylebox_override("focus", focus)


static func show_dialog(dialog: AcceptDialog) -> void:
	var theme: Theme = Theme.new()
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = CARD
	panel.border_color = ACCENT
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(20)
	panel.set_content_margin_all(24)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_stylebox("panel", "ConfirmationDialog", panel)
	theme.set_color("font_color", "Label", TEXT)
	theme.default_font_size = 26
	theme.set_color("title_color", "Window", TEXT)
	theme.set_font_size("title_font_size", "Window", 26)
	var border: StyleBoxFlat = panel.duplicate()
	border.expand_margin_top = 42
	border.expand_margin_left = 6
	border.expand_margin_right = 6
	border.expand_margin_bottom = 6
	theme.set_stylebox("embedded_border", "Window", border)
	theme.set_stylebox("embedded_unfocused_border", "Window", border)
	theme.set_constant("title_height", "Window", 40)
	dialog.theme = theme
	dialog.dialog_autowrap = true
	style_button(dialog.get_ok_button(), true)
	if dialog is ConfirmationDialog:
		style_button((dialog as ConfirmationDialog).get_cancel_button())
	dialog.min_size = Vector2i(520, 240)
	dialog.popup_centered(Vector2i(600, 300))
