class_name HomeScreen
extends Control

signal play_requested
signal map_requested
signal continue_requested
signal retry_save_requested
signal settings_requested

var language: String = "en"
var play_enabled: bool = true
var continue_enabled: bool = false
var campaign_complete: bool = false
var primary_label: String = ""
var save_error: bool = false
var save_status: String = ""


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	theme = OpticalTheme.create()
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label("LAYER SORT", 42))
	column.add_child(ScreenWidgets.label(UiText.get_text("subtitle", language), 23, true))
	if save_error:
		column.add_child(ScreenWidgets.label(UiText.get_text("save_recovered", language) if save_status == "RECOVERED" else (UiText.get_text("save_error", language) if save_status == "CORRUPT" or save_status == "UNSUPPORTED_VERSION" else UiText.get_text("save_write_error", language)), 23, true))
		if save_status == "WRITE_FAILED" or save_status == "REPLACE_FAILED":
			var retry: Button = ScreenWidgets.button(UiText.get_text("retry_save", language))
			column.add_child(retry)
			retry.pressed.connect(func() -> void: retry_save_requested.emit())
	if campaign_complete:
		column.add_child(ScreenWidgets.label("اكتملت الحملة! اختر مستوى لإعادته." if language == "ar" else "Campaign complete! Choose a level to replay.", 24, true))
	column.add_child(HomeGlassHero.new())
	var play: Button = ScreenWidgets.button(primary_label if not primary_label.is_empty() else UiText.get_text("play", language), true)
	play.name = "PlayButton"
	play.disabled = not play_enabled
	column.add_child(play)
	play.pressed.connect(func() -> void: play_requested.emit())
	var secondary: HBoxContainer = HBoxContainer.new()
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 48)
	column.add_child(secondary)
	var map_button: OpticalIconButton = OpticalIconButton.make("map", UiText.get_text("level_map", language), "MapButton")
	secondary.add_child(map_button)
	map_button.pressed.connect(func() -> void: map_requested.emit())
	var settings: OpticalIconButton = OpticalIconButton.make("settings", UiText.get_text("settings", language), "SettingsButton")
	secondary.add_child(settings)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	print("LAYER_SORT_G3_HOME_READY")
