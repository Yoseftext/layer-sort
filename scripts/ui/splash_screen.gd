class_name SplashScreen
extends Control

var language: String = "en"


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label("LAYER SORT", 58))
	column.add_child(ScreenWidgets.label(UiText.get_text("loading", language), 25, true))
