class_name PauseScreen
extends Control

signal resume_requested
signal restart_requested
signal settings_requested
signal home_requested
signal map_requested

var language: String = "en"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("pause", language), 46))
	_add_button(column, "resume", "ResumeButton", resume_requested)
	_add_button(column, "restart", "RestartButton", restart_requested)
	_add_button(column, "settings", "SettingsButton", settings_requested)
	_add_button(column, "level_map", "MapButton", map_requested)
	_add_button(column, "home", "HomeButton", home_requested)


func _add_button(column: VBoxContainer, key: String, node_name: String, action: Signal) -> void:
	var button: Button = ScreenWidgets.button(UiText.get_text(key, language))
	button.name = node_name
	column.add_child(button)
	button.pressed.connect(func() -> void: action.emit())
