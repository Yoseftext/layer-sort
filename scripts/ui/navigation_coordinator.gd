class_name NavigationCoordinator
extends Control

const SPLASH_SCENE: PackedScene = preload("res://scenes/navigation/splash.tscn")
const HOME_SCENE: PackedScene = preload("res://scenes/navigation/home.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/navigation/settings.tscn")
const ABOUT_SCENE: PackedScene = preload("res://scenes/navigation/about.tscn")
const MAP_SCENE: PackedScene = preload("res://scenes/navigation/level_map.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/navigation/pause.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/game/classic_game.tscn")

var _state: NavigationState = NavigationState.new()
var _settings: AppSettings = AppSettings.new()
var _catalog: LevelCatalog
var _progression: Progression
var _saves: SaveRepository = SaveRepository.new()
var _save_sequence: int = 0
var _save_blocked: bool = false
var _save_failed: bool = false
var _save_status: String = ""
var _save_dialog: ConfirmationDialog
var _active: Dictionary = {}
var _win_dialog: AcceptDialog
var _surface: MarginContainer
var _screen: Control
var _exit_dialog: ConfirmationDialog
var _restart_dialog: ConfirmationDialog
var _pause_screen: PauseScreen
var _pause_settings: SettingsScreen
var _leave_to_map: bool = false
var _leave_dialog: ConfirmationDialog


func _ready() -> void:
	var loaded: Dictionary = LevelCatalog.load_catalog()
	if loaded.ok:
		_catalog = loaded.catalog
		_progression = Progression.new(_catalog)
		var saved: Dictionary = _saves.load_latest(_catalog)
		if saved.ok:
			_progression.load_records(saved.completed)
			_save_sequence = saved.sequence
			_active = saved.active
			_save_status = String(saved.status)
			_save_blocked = bool(saved.get("write_blocked", false))
		elif saved.status != "NO_SAVE":
			_save_blocked = true
			_save_status = String(saved.status)
			push_error("G3B_SAVE_RECOVERY_FAILED")
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
	_close_pause()
	if _state.route == NavigationState.Route.GAME:
		_clear_active_attempt()
	_state.open_home()
	_show(HOME_SCENE)


func show_map() -> void:
	if _catalog == null:
		return
	_state.open_map()
	var level_map: LevelMapScreen = MAP_SCENE.instantiate() as LevelMapScreen
	level_map.language = _settings.language
	level_map.catalog = _catalog
	level_map.progression = _progression
	_replace_screen(level_map)
	level_map.level_requested.connect(open_level)
	level_map.home_requested.connect(go_home)


func continue_game() -> void:
	if not _active.is_empty():
		open_level(String(_active.level_id), true)


func show_settings() -> void:
	_state.open_settings()
	_show(SETTINGS_SCENE)


func show_about() -> void:
	_state.open_about()
	_show(ABOUT_SCENE)


func open_level(level_id: String, restore: bool = false) -> bool:
	if _catalog == null or _save_blocked:
		return false
	var path: String = _catalog.path_for(level_id)
	if path.is_empty() or not _progression.is_unlocked(level_id):
		return false
	var loaded: Dictionary = LevelLoader.read_file(path)
	if not loaded.ok:
		push_error("G3_LEVEL_ERROR " + String(loaded.error))
		return false
	if String(loaded.state.level_id) != level_id:
		return false
	_state.open_game(level_id)
	var game: ClassicGame = GAME_SCENE.instantiate() as ClassicGame
	game.level_path = path
	game.language = _settings.language
	if restore and _active.get("level_id") == level_id:
		game.restored_state = _active.duplicate(true)
	else:
		_active = _snapshot_data(loaded.state)
		_persist()
	_replace_screen(game)
	game.home_requested.connect(request_home)
	game.pause_requested.connect(_open_pause)
	game.state_committed.connect(_on_game_commit)
	print("LAYER_SORT_G3_GAME_READY " + level_id)
	return true


func go_back() -> void:
	if _save_dialog != null and _save_dialog.visible:
		_save_dialog.hide()
		return
	if _win_dialog != null and _win_dialog.visible:
		_win_dialog.hide()
		show_map()
		return
	if _leave_dialog != null and is_instance_valid(_leave_dialog) and _leave_dialog.visible:
		_leave_dialog.hide()
		return
	if _exit_dialog != null and is_instance_valid(_exit_dialog) and _exit_dialog.visible:
		_exit_dialog.hide()
		return
	if _pause_settings != null:
		_close_pause_settings()
		return
	if _restart_dialog != null and _restart_dialog.visible:
		_restart_dialog.hide()
		return
	if _pause_screen != null:
		_close_pause()
		return
	if _state.route == NavigationState.Route.GAME:
		_open_pause()
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
		(next as HomeScreen).play_enabled = _catalog != null and not _save_blocked
		(next as HomeScreen).continue_enabled = not _active.is_empty() and not _save_blocked
		(next as HomeScreen).save_error = _save_blocked or _save_failed or _save_status == "RECOVERED"
		(next as HomeScreen).save_status = _save_status
	_replace_screen(next)
	if next is HomeScreen:
		(next as HomeScreen).play_requested.connect(_on_play)
		(next as HomeScreen).map_requested.connect(show_map)
		(next as HomeScreen).continue_requested.connect(continue_game)
		(next as HomeScreen).retry_save_requested.connect(_retry_save)
		(next as HomeScreen).settings_requested.connect(show_settings)
		(next as HomeScreen).about_requested.connect(show_about)
	elif next is SettingsScreen:
		(next as SettingsScreen).language_selected.connect(_on_language_selected)
		(next as SettingsScreen).home_requested.connect(go_home)
	elif next is AboutScreen:
		(next as AboutScreen).home_requested.connect(go_home)


func _replace_screen(next: Control) -> void:
	_close_pause()
	if _screen != null:
		_surface.remove_child(_screen)
		_screen.queue_free()
	_screen = next
	_surface.add_child(next)
	next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _snapshot_data(state: GameState) -> Dictionary:
	var tubes: Array = []
	for tube: TubeModel in state.tubes:
		tubes.append(tube.layers.duplicate())
	return {"level_id": state.level_id, "content_version": state.content_version, "move_count": state.move_count, "tubes": tubes}


func _clear_active_attempt() -> void:
	var previous: Dictionary = _active.duplicate(true)
	_active = {}
	if not _persist():
		_active = previous


func _persist() -> bool:
	if _progression == null or _save_blocked:
		return false
	var result: Dictionary = _saves.write_result(_save_sequence + 1, _progression.completed, _active)
	if result.ok:
		_save_sequence += 1
		_save_failed = false
		_save_status = ""
		return true
	_save_failed = true
	_save_status = String(result.status)
	push_error("G3B_SAVE_" + _save_status)
	_show_save_warning()
	return false


func _retry_save() -> void:
	var succeeded: bool = _persist()
	if succeeded and _state.route == NavigationState.Route.HOME:
		_show(HOME_SCENE)


func _show_save_warning() -> void:
	if _save_dialog == null:
		_save_dialog = ConfirmationDialog.new()
		add_child(_save_dialog)
		_save_dialog.confirmed.connect(_retry_save)
	_save_dialog.title = UiText.get_text("save_warning_title", _settings.language)
	_save_dialog.dialog_text = UiText.get_text("save_write_error", _settings.language)
	_save_dialog.ok_button_text = UiText.get_text("retry_save", _settings.language)
	_save_dialog.cancel_button_text = UiText.get_text("continue_unsaved", _settings.language)
	ScreenWidgets.show_dialog(_save_dialog)


func _on_game_commit(state: GameState, won: bool) -> void:
	_active = _snapshot_data(state)
	if won:
		_progression.record_win(state.level_id, state.move_count)
		_active = {}
	_persist()
	if won:
		if _win_dialog == null:
			_win_dialog = AcceptDialog.new()
			add_child(_win_dialog)
			_win_dialog.confirmed.connect(show_map)
		_win_dialog.title = UiText.get_text("completed", _settings.language)
		_win_dialog.dialog_text = UiText.get_text("completed", _settings.language) + ("\n" + UiText.get_text("save_write_error", _settings.language) if _save_failed else "")
		ScreenWidgets.show_dialog(_win_dialog)


func _on_play() -> void:
	if _catalog != null and not open_level(_catalog.entry_level_id):
		push_error("G3_ENTRY_LEVEL_UNAVAILABLE")


func _on_language_selected(code: String) -> void:
	if _settings.set_language(code):
		if _pause_settings != null:
			_close_pause_settings()
			_open_pause_settings()
		else:
			_show(SETTINGS_SCENE)


func _open_pause() -> void:
	var game: ClassicGame = _screen as ClassicGame
	if game == null or _pause_screen != null:
		return
	game.set_process_input(false)
	_pause_screen = PAUSE_SCENE.instantiate() as PauseScreen
	_pause_screen.language = _settings.language
	_surface.add_child(_pause_screen)
	_pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_screen.resume_requested.connect(_close_pause)
	_pause_screen.restart_requested.connect(_request_restart)
	_pause_screen.settings_requested.connect(_open_pause_settings)
	_pause_screen.home_requested.connect(request_home)
	_pause_screen.map_requested.connect(request_map)


func _close_pause() -> void:
	_close_pause_settings()
	if _pause_screen != null:
		_pause_screen.queue_free()
		_pause_screen = null
	var game: ClassicGame = _screen as ClassicGame
	if game != null:
		game.set_process_input(true)


func _open_pause_settings() -> void:
	if _pause_screen == null:
		return
	_pause_screen.hide()
	_pause_settings = SETTINGS_SCENE.instantiate() as SettingsScreen
	_pause_settings.language = _settings.language
	_pause_settings.return_to_pause = true
	_surface.add_child(_pause_settings)
	_pause_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_settings.language_selected.connect(_on_language_selected)
	_pause_settings.home_requested.connect(_close_pause_settings)


func _close_pause_settings() -> void:
	if _pause_settings != null:
		_pause_settings.queue_free()
		_pause_settings = null
	if _pause_screen != null:
		_pause_screen.show()


func _request_restart() -> void:
	var game: ClassicGame = _screen as ClassicGame
	if game == null:
		return
	if not game.has_unsaved_move():
		_restart_game()
		return
	if _restart_dialog == null:
		_restart_dialog = ConfirmationDialog.new()
		add_child(_restart_dialog)
		_restart_dialog.confirmed.connect(_restart_game)
	_restart_dialog.title = UiText.get_text("restart_title", _settings.language)
	_restart_dialog.dialog_text = UiText.get_text("restart_message", _settings.language)
	_restart_dialog.ok_button_text = UiText.get_text("restart", _settings.language)
	_restart_dialog.cancel_button_text = UiText.get_text("cancel", _settings.language)
	ScreenWidgets.show_dialog(_restart_dialog)


func _restart_game() -> void:
	var game: ClassicGame = _screen as ClassicGame
	if game != null:
		game.restart_attempt()
	_close_pause()


func request_home() -> void:
	_leave_to_map = false
	_request_leave()


func request_map() -> void:
	_leave_to_map = true
	_request_leave()


func _finish_leave() -> void:
	if _leave_to_map:
		_clear_active_attempt()
		show_map()
	else:
		go_home()


func _request_leave() -> void:
	var game: ClassicGame = _screen as ClassicGame
	if game == null or not game.has_unsaved_move():
		_finish_leave()
		return
	if _leave_dialog == null:
		_leave_dialog = ConfirmationDialog.new()
		add_child(_leave_dialog)
		_leave_dialog.confirmed.connect(_finish_leave)
	_leave_dialog.title = UiText.get_text("leave_title", _settings.language)
	_leave_dialog.dialog_text = UiText.get_text("leave_message", _settings.language)
	_leave_dialog.ok_button_text = UiText.get_text("leave_confirm", _settings.language)
	_leave_dialog.cancel_button_text = UiText.get_text("cancel", _settings.language)
	ScreenWidgets.show_dialog(_leave_dialog)


func _confirm_exit() -> void:
	if _exit_dialog == null:
		_exit_dialog = ConfirmationDialog.new()
		add_child(_exit_dialog)
		_exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	_exit_dialog.title = UiText.get_text("exit_title", _settings.language)
	_exit_dialog.ok_button_text = UiText.get_text("exit_confirm", _settings.language)
	_exit_dialog.cancel_button_text = UiText.get_text("cancel", _settings.language)
	ScreenWidgets.show_dialog(_exit_dialog)


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
