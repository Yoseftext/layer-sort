class_name AboutScreen
extends Control

signal home_requested

var language: String = "en"


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("about", language), 46))
	column.add_child(ScreenWidgets.label(UiText.get_text("about_intro", language), 25))
	column.add_child(ScreenWidgets.label(UiText.get_text("version", language), 23, true))
	column.add_child(ScreenWidgets.label(UiText.get_text("about_credits", language), 30))
	for entry: Dictionary in AttributionCatalog.entries():
		column.add_child(ScreenWidgets.label("%s · %s" % [entry.name, entry.license], 23))
	column.add_child(ScreenWidgets.label(UiText.get_text("about_note", language), 21, true))
	var home: Button = ScreenWidgets.button(UiText.get_text("home", language))
	home.name = "HomeButton"
	column.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
