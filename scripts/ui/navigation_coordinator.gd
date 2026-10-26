class_name NavigationCoordinator
extends Control

const SPLASH_SCENE: PackedScene = preload("res://scenes/navigation/splash.tscn")
const HOME_SCENE: PackedScene = preload("res://scenes/navigation/home.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/navigation/settings.tscn")
const ABOUT_SCENE: PackedScene = preload("res://scenes/navigation/about.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/game/classic_game.tscn")

var _state: NavigationState = NavigationState.new()
var _settings: AppSettings = AppSettings.new()
var _catalog: LevelCatalog
var _surface: MarginContainer
var _screen: Control
var _exit_dialog: ConfirmationDialog
var _leave_dialog: ConfirmationDialog


func _ready() -> void:
	var loaded: Dictionary = LevelCatalog.load_catalog()
	if loaded.ok:
		_catalog = loaded.catalog
	else:
		push_error("G3_CATALOG_ERROR " + String(loaded.error))
	_surface = MarginContainer.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_tree().auto_accept_quit = false
	get_window().go_back_requested.connect(go_back)
	_show_splash()


func current_route() -> int:
	return _state.route


func current_screen() -> Control:
	return _screen


func go_home() -> void:
	if _leave_dialog != null and is_instance_valid(_leave_dialog):
		_leave_dialog.hide()
	_state.open_home()
	_show(HOME_SCENE)


func show_settings() -> void:
	_state.open_settings()
	_show(SETTINGS_SCENE)


func show_about() -> void:
	_state.open_about()
	_show(ABOUT_SCENE)


func open_level(level_id: String) -> bool:
	if _catalog == null:
		return false
	var path: String = _catalog.path_for(level_id)
	if path.is_empty():
		return false
	var loaded: Dictionary = LevelLoader.read_file(path)
	if not loaded.ok:
		push_error("G3_LEVEL_ERROR " + String(loaded.error))
		return false
	_state.open_game(level_id)
	var game: ClassicGame = GAME_SCENE.instantiate() as ClassicGame
	game.level_path = path
	game.language = _settings.language
	_replace_screen(game)
	game.home_requested.connect(request_home)
	print("LAYER_SORT_G3_GAME_READY " + level_id)
	return true


func go_back() -> void:
	if _leave_dialog != null and is_instance_valid(_leave_dialog) and _leave_dialog.visible:
		_leave_dialog.hide()
		return
	if _exit_dialog != null and is_instance_valid(_exit_dialog) and _exit_dialog.visible:
		_exit_dialog.hide()
		return
	if _state.route == NavigationState.Route.GAME:
		request_home()
		return
	if _state.back():
		go_home()
	else:
		_confirm_exit()


func _show_splash() -> void:
	_show(SPLASH_SCENE)
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree() and _state.route == NavigationState.Route.SPLASH:
		go_home()


func _show(scene: PackedScene) -> void:
	var next: Control = scene.instantiate() as Control
	next.set("language", _settings.language)
	if next is HomeScreen:
		(next as HomeScreen).play_enabled = _catalog != null
	_replace_screen(next)
	if next is HomeScreen:
		(next as HomeScreen).play_requested.connect(_on_play)
		(next as HomeScreen).settings_requested.connect(show_settings)
		(next as HomeScreen).about_requested.connect(show_about)
	elif next is SettingsScreen:
		(next as SettingsScreen).language_selected.connect(_on_language_selected)
		(next as SettingsScreen).home_requested.connect(go_home)
	elif next is AboutScreen:
		(next as AboutScreen).home_requested.connect(go_home)


func _replace_screen(next: Control) -> void:
	if _screen != null:
		_surface.remove_child(_screen)
		_screen.queue_free()
	_screen = next
	_surface.add_child(next)
	next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _on_play() -> void:
	if _catalog != null and not open_level(_catalog.entry_level_id):
		push_error("G3_ENTRY_LEVEL_UNAVAILABLE")


func _on_language_selected(code: String) -> void:
	if _settings.set_language(code):
		_show(SETTINGS_SCENE)


func request_home() -> void:
	var game: ClassicGame = _screen as ClassicGame
	if game == null or not game.has_unsaved_move():
		go_home()
		return
	if _leave_dialog == null:
		_leave_dialog = ConfirmationDialog.new()
		add_child(_leave_dialog)
		_leave_dialog.confirmed.connect(go_home)
	_leave_dialog.title = UiText.get_text("leave_title", _settings.language)
	_leave_dialog.dialog_text = UiText.get_text("leave_message", _settings.language)
	_leave_dialog.ok_button_text = UiText.get_text("leave_confirm", _settings.language)
	_leave_dialog.cancel_button_text = UiText.get_text("cancel", _settings.language)
	_leave_dialog.popup_centered()


func _confirm_exit() -> void:
	if _exit_dialog == null:
		_exit_dialog = ConfirmationDialog.new()
		add_child(_exit_dialog)
		_exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	_exit_dialog.title = UiText.get_text("exit_title", _settings.language)
	_exit_dialog.ok_button_text = UiText.get_text("exit_confirm", _settings.language)
	_exit_dialog.cancel_button_text = UiText.get_text("cancel", _settings.language)
	_exit_dialog.popup_centered()


func _apply_safe_area() -> void:
	if _surface == null:
		return
	var physical: Vector2i = DisplayServer.screen_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var viewport: Vector2 = get_viewport_rect().size
	var scale_x: float = viewport.x / float(maxi(physical.x, 1))
	var scale_y: float = viewport.y / float(maxi(physical.y, 1))
	var left: int = maxi(24, ceili(float(safe.position.x) * scale_x))
	var top: int = maxi(32, ceili(float(safe.position.y) * scale_y))
	var right: int = maxi(24, ceili(float(physical.x - safe.end.x) * scale_x))
	var bottom: int = maxi(32, ceili(float(physical.y - safe.end.y) * scale_y))
	_surface.add_theme_constant_override("margin_left", left)
	_surface.add_theme_constant_override("margin_top", top)
	_surface.add_theme_constant_override("margin_right", right)
	_surface.add_theme_constant_override("margin_bottom", bottom)
