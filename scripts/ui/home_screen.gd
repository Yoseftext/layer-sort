class_name HomeScreen
extends Control

signal play_requested
signal settings_requested
signal about_requested

var language: String = "en"
var play_enabled: bool = true


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label("LAYER SORT", 58))
	column.add_child(ScreenWidgets.label(UiText.get_text("subtitle", language), 26, true))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 70
	column.add_child(spacer)
	var play: Button = ScreenWidgets.button(UiText.get_text("play", language), true)
	play.name = "PlayButton"
	play.disabled = not play_enabled
	column.add_child(play)
	play.pressed.connect(func() -> void: play_requested.emit())
	var settings: Button = ScreenWidgets.button(UiText.get_text("settings", language))
	settings.name = "SettingsButton"
	column.add_child(settings)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	var about: Button = ScreenWidgets.button(UiText.get_text("about", language))
	about.name = "AboutButton"
	column.add_child(about)
	about.pressed.connect(func() -> void: about_requested.emit())
	print("LAYER_SORT_G3_HOME_READY")
