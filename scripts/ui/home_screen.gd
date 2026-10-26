class_name HomeScreen
extends Control

signal play_requested
signal map_requested
signal continue_requested
signal settings_requested
signal about_requested

var language: String = "en"
var play_enabled: bool = true
var continue_enabled: bool = false
var save_error: bool = false


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label("LAYER SORT", 58))
	column.add_child(ScreenWidgets.label(UiText.get_text("subtitle", language), 26, true))
	if save_error:
		column.add_child(ScreenWidgets.label(UiText.get_text("save_error", language), 23, true))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 70
	column.add_child(spacer)
	var play: Button = ScreenWidgets.button(UiText.get_text("play", language), true)
	play.name = "PlayButton"
	play.disabled = not play_enabled
	column.add_child(play)
	play.pressed.connect(func() -> void: play_requested.emit())
	var continue_button: Button = ScreenWidgets.button(UiText.get_text("continue", language))
	continue_button.name = "ContinueButton"
	continue_button.disabled = not continue_enabled
	column.add_child(continue_button)
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	var map_button: Button = ScreenWidgets.button(UiText.get_text("level_map", language))
	map_button.name = "MapButton"
	column.add_child(map_button)
	map_button.pressed.connect(func() -> void: map_requested.emit())
	var settings: Button = ScreenWidgets.button(UiText.get_text("settings", language))
	settings.name = "SettingsButton"
	column.add_child(settings)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	var about: Button = ScreenWidgets.button(UiText.get_text("about", language))
	about.name = "AboutButton"
	column.add_child(about)
	about.pressed.connect(func() -> void: about_requested.emit())
	print("LAYER_SORT_G3_HOME_READY")
