class_name SettingsScreen
extends Control

signal language_selected(code: String)
signal home_requested

var language: String = "en"


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("settings", language), 46))
	column.add_child(ScreenWidgets.label(UiText.get_text("language", language), 28, true))
	var english: Button = ScreenWidgets.button(UiText.get_text("english", language))
	english.name = "EnglishButton"
	english.disabled = language == "en"
	column.add_child(english)
	english.pressed.connect(func() -> void: language_selected.emit("en"))
	var arabic: Button = ScreenWidgets.button(UiText.get_text("arabic", language))
	arabic.name = "ArabicButton"
	arabic.disabled = language == "ar"
	column.add_child(arabic)
	arabic.pressed.connect(func() -> void: language_selected.emit("ar"))
	column.add_child(ScreenWidgets.label(UiText.get_text("session_only", language), 21, true))
	var home: Button = ScreenWidgets.button(UiText.get_text("home", language))
	home.name = "HomeButton"
	column.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
