class_name LevelMapScreen
extends Control

signal level_requested(id: String)
signal home_requested

var language: String = "en"
var catalog: LevelCatalog
var progression: Progression


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("level_map", language), 46))
	for id: String in catalog.available_level_ids:
		var status: String = "completed" if progression.completed.has(id) else ("unlocked" if progression.is_unlocked(id) else "locked")
		var label: String = id.replace("level_", "") + " · " + UiText.get_text(status, language)
		if progression.completed.has(id):
			label += " · " + UiText.get_text("stars", language) % progression.completed[id].stars
		var button: Button = ScreenWidgets.button(label)
		button.name = id
		button.disabled = not progression.is_unlocked(id)
		column.add_child(button)
		button.pressed.connect(func() -> void: level_requested.emit(id))
	var home: Button = ScreenWidgets.button(UiText.get_text("home", language))
	column.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
