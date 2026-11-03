class_name SettingsScreen
extends Control

signal language_selected(code: String)
signal motion_selected(value: bool)
signal sound_selected(value: bool)
signal effects_selected(value: bool)
signal tutorials_requested
signal about_requested
signal home_requested

var language: String = "en"
var return_to_pause: bool = false
var reduce_motion: bool = false
var sound_enabled: bool = true
var rich_effects: bool = false


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("settings", language), 46))
	column.add_child(ScreenWidgets.label(UiText.get_text("language", language), 28, true))
	var english: Button = ScreenWidgets.button(UiText.get_text("english", language))
	english.name = "EnglishButton"
	english.toggle_mode = true
	english.button_pressed = language == "en"
	column.add_child(english)
	english.pressed.connect(func() -> void: language_selected.emit("en"))
	var arabic: Button = ScreenWidgets.button(UiText.get_text("arabic", language))
	arabic.name = "ArabicButton"
	arabic.toggle_mode = true
	arabic.button_pressed = language == "ar"
	column.add_child(arabic)
	arabic.pressed.connect(func() -> void: language_selected.emit("ar"))
	column.add_child(ScreenWidgets.label(UiText.get_text("session_only", language), 21, true))
	var motion: CheckButton = CheckButton.new()
	motion.text = UiText.get_text("reduce_motion", language)
	motion.accessibility_name = motion.text
	motion.custom_minimum_size = Vector2(0, 96)
	motion.add_theme_font_size_override("font_size", 28)
	motion.add_theme_color_override("font_color", ScreenWidgets.TEXT)
	motion.button_pressed = reduce_motion
	column.add_child(motion)
	motion.toggled.connect(func(value: bool) -> void: motion_selected.emit(value))
	_add_toggle(column, "sound", "SoundToggle", sound_enabled, sound_selected)
	_add_toggle(column, "rich_effects", "EffectsToggle", rich_effects, effects_selected)
	if not return_to_pause:
		var tutorials: Button = ScreenWidgets.button("إعادة الدروس" if language == "ar" else "Replay Tutorials")
		tutorials.name = "ReplayTutorials"
		column.add_child(tutorials)
		tutorials.pressed.connect(func() -> void: tutorials_requested.emit())
	var about: Button = ScreenWidgets.button(UiText.get_text("about", language))
	about.name = "AboutButton"
	column.add_child(about)
	about.pressed.connect(func() -> void: about_requested.emit())
	var home: Button = ScreenWidgets.button(UiText.get_text("back", language) if return_to_pause else UiText.get_text("home", language))
	home.name = "HomeButton"
	column.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())


func _add_toggle(column: VBoxContainer, key: String, node_name: String, value: bool, action: Signal) -> void:
	var toggle: CheckButton = CheckButton.new()
	toggle.name = node_name
	toggle.text = UiText.get_text(key, language)
	toggle.accessibility_name = toggle.text
	toggle.custom_minimum_size.y = 96
	toggle.add_theme_font_size_override("font_size", 28)
	toggle.button_pressed = value
	column.add_child(toggle)
	toggle.toggled.connect(func(selected: bool) -> void: action.emit(selected))
