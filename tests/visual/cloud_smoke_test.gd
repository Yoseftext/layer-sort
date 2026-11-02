extends SceneTree

class FailingSave extends SaveRepository:
	func _write_temp(_path: String, _contents: String) -> bool:
		return false

var checks: int = 0
var failures: int = 0
var captures: Array[Dictionary] = []
var navigation: NavigationCoordinator
var output: String = OS.get_environment("VISUAL_CAPTURE_DIR")
var repository: SaveRepository = SaveRepository.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not output.is_empty() and DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		push_error("CLOUD_VISUAL_FAIL output directory must be empty")
		quit(2)
		return
	repository.directory = "user://cloud_visual_qa_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repository.directory))
	root.size = Vector2i(720, 1600)
	root.gui_embed_subwindows = true
	var scene: PackedScene = load("res://scenes/navigation/root.tscn")
	navigation = scene.instantiate() as NavigationCoordinator
	navigation.set("_saves", repository)
	root.add_child(navigation)
	await create_timer(0.15).timeout
	await capture("01-splash")
	await create_timer(0.5).timeout
	await capture("02-home")
	check(not (navigation.current_screen() as HomeScreen).continue_enabled, "isolated run starts without progress")
	await click_named("MapButton")
	await capture("03-map")
	await click_text(UiText.get_text("home", "en"))
	await click_named("SettingsButton")
	await capture("04-settings-en")
	await click_named("ArabicButton")
	await capture("05-settings-ar")
	await click_named("HomeButton")
	await click_named("AboutButton")
	await capture("06-about-ar")
	await click_named("HomeButton")
	await click_named("SettingsButton")
	await click_named("EnglishButton")
	await click_named("HomeButton")
	await click_named("PlayButton")
	var game: ClassicGame = navigation.current_screen() as ClassicGame
	check(game != null, "real pointer opens Classic")
	if game == null:
		quit(1)
		return
	await capture("07-classic")
	await tap(game._views[0])
	await capture("08-selected")
	var original: String = game._session.snapshot().identity()
	await tap(game._views[1])
	check(game._session.snapshot().identity() == original, "invalid pour has no mutation")
	await capture("09-invalid")
	await tap(game._views[3], 0.02)
	var committed: String = game._session.snapshot().identity()
	await create_timer(0.10).timeout
	await capture("10-pour-early")
	await tap(game._views[2], 0.02)
	check(game._session.snapshot().identity() == committed, "rapid input cannot double commit")
	await capture("11-pour-middle")
	await create_timer(0.4).timeout
	check(not game._session.animation_locked, "pour releases input")
	await capture("12-pour-settled")
	await click_text(UiText.get_text("undo", "en"))
	check(game._session.snapshot().identity() == original, "real Undo restores snapshot")
	await tap(game._views[0])
	await tap(game._views[3])
	await create_timer(0.7).timeout
	await click_text(UiText.get_text("restart", "en"))
	var restart: ConfirmationDialog = navigation.get("_restart_dialog") as ConfirmationDialog
	check(restart != null and restart.visible, "toolbar Restart requires confirmation")
	await capture("13-toolbar-restart")
	if restart != null and restart.visible:
		var preserved: String = game._session.snapshot().identity()
		await tap(restart.get_cancel_button())
		check(game._session.snapshot().identity() == preserved, "cancel Restart preserves state")
	await click_named("PauseButton")
	await capture("14-pause")
	await click_named("SettingsButton")
	await click_named("ArabicButton")
	await capture("15-paused-settings-ar")
	await click_named("HomeButton")
	check((navigation.get("_pause_screen") as PauseScreen).language == "ar", "Pause relocalizes")
	await click_named("ResumeButton")
	check(game.language == "ar", "language applies to preserved gameplay")
	await capture("16-resumed-ar")
	await click_named("PauseButton")
	await click_named("RestartButton")
	restart = navigation.get("_restart_dialog") as ConfirmationDialog
	if restart != null and restart.visible:
		await capture("17-restart-confirm")
		await tap(restart.get_ok_button())
	else:
		navigation._restart_game()
	await click_named("PauseButton")
	await click_named("SettingsButton")
	await click_named("EnglishButton")
	var settings: SettingsScreen = navigation.get("_pause_settings") as SettingsScreen
	var motion: CheckButton = find_check(settings)
	await tap(motion)
	await click_named("HomeButton")
	await click_named("ResumeButton")
	check(game.reduce_motion, "motion toggle applies to live session")
	var solution: Array[Vector2i] = [Vector2i(0,3),Vector2i(2,0),Vector2i(1,2),Vector2i(1,3),Vector2i(0,1),Vector2i(2,0),Vector2i(2,3),Vector2i(1,2),Vector2i(0,1),Vector2i(0,3)]
	for index: int in range(solution.size()):
		await tap(game._views[solution[index].x], 0.01)
		await tap(game._views[solution[index].y], 0.01)
		await create_timer(0.14).timeout
		if index == 7:
			await capture("18-completed-tube-reduced-motion")
	check(WinRules.is_won(game._session.snapshot()), "pointer solution wins")
	await capture("19-win")
	var win: AcceptDialog = navigation.get("_win_dialog") as AcceptDialog
	check(win != null and win.visible, "completion dialog shown")
	if win != null:
		await tap(win.get_ok_button())
	check(navigation.current_screen() is LevelMapScreen, "win acknowledgment opens Map")
	await capture("20-unlocked-map")
	await click_named("level_002")
	game = navigation.current_screen() as ClassicGame
	await tap(game._views[0])
	await tap(game._views[3])
	await create_timer(0.7).timeout
	await click_named("HomeButton")
	await capture("21-exit-confirm")
	var leave: ConfirmationDialog = navigation.get("_leave_dialog") as ConfirmationDialog
	check(leave != null and leave.visible, "exit confirms attempt")
	var protected: String = game._session.snapshot().identity()
	var selected: int = game._selected_source
	await tap(game._views[0])
	check(game._session.snapshot().identity() == protected, "dialog blocks underlying board")
	check(game._selected_source == selected, "dialog blocks underlying selection")
	if leave != null:
		leave.hide()
		leave.canceled.emit()
	navigation.queue_free()
	await process_frame
	navigation = scene.instantiate() as NavigationCoordinator
	navigation.set("_saves", repository)
	root.add_child(navigation)
	await create_timer(0.65).timeout
	await capture("22-continue-home")
	await click_named("ContinueButton")
	check((navigation.current_screen() as ClassicGame).has_unsaved_move(), "new coordinator restores saved Continue")
	await capture("23-continued-board")
	# Isolated failure fixture starts from the certified level-001 solution.
	navigation.open_level("level_001")
	await create_timer(0.2).timeout
	game = navigation.current_screen() as ClassicGame
	game.reduce_motion = true
	for index: int in range(solution.size()):
		if index == solution.size() - 1:
			navigation.set("_saves", FailingSave.new())
		await tap(game._views[solution[index].x], 0.01)
		await tap(game._views[solution[index].y], 0.01)
		await create_timer(0.14).timeout
	var warning: ConfirmationDialog = navigation.get("_save_dialog") as ConfirmationDialog
	win = navigation.get("_win_dialog") as AcceptDialog
	check(WinRules.is_won(game._session.snapshot()), "failure injected on a valid winning move")
	check(warning != null and warning.visible and (win == null or not win.visible), "failed winning save shows only warning")
	await capture("24-win-save-warning")
	if warning != null:
		await tap(warning.get_cancel_button())
	win = navigation.get("_win_dialog") as AcceptDialog
	check(win != null and win.visible and not warning.visible, "warning dismissal resumes deferred win")
	await capture("25-win-after-save-warning")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output.path_join("capture-index.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"source_commit": OS.get_environment("QA_SOURCE_COMMIT"), "engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "viewport": [720,1600], "checks": checks, "failures": failures, "captures": captures}, "\t"))
	navigation.queue_free()
	await process_frame
	print("CLOUD_VISUAL_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func tap(control: Control, settle: float = 0.12) -> void:
	check(control != null, "pointer target exists")
	if control == null:
		return
	var position: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != root:
		position += Vector2(window.position)
	print("QA_POINTER %s %s window=%s" % [control.name, position, window.name])
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await create_timer(settle).timeout

func click_named(node_name: String) -> void:
	var scope: Control = navigation.current_screen()
	if navigation.get("_pause_settings") != null:
		scope = navigation.get("_pause_settings") as Control
	elif navigation.get("_pause_screen") != null:
		scope = navigation.get("_pause_screen") as Control
	var target: Control = scope.find_child(node_name, true, false) as Control
	await tap(target)

func click_text(value: String) -> void:
	for node: Node in navigation.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == value and button.is_visible_in_tree():
			await tap(button)
			return
	check(false, "button text found: " + value)

func find_check(parent: Node) -> CheckButton:
	for child: Node in parent.find_children("*", "CheckButton", true, false):
		return child as CheckButton
	return null

func capture(label: String) -> void:
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label + ".png")
	var rendered: Image = root.get_texture().get_image()
	if label == "02-home":
		check(rendered.get_pixel(0, 0).is_equal_approx(ScreenWidgets.INK), "safe-area exterior uses approved background")
	check(rendered.save_png(path) == OK, "capture: " + label)
	var game: ClassicGame = navigation.current_screen() as ClassicGame
	var progress: float = game._trail.get("_progress") if game != null else -1.0
	captures.append({"name": label, "sha256": FileAccess.get_sha256(path), "width": rendered.get_width(), "height": rendered.get_height(), "pour_progress": progress, "time_ms": Time.get_ticks_msec(), "route": navigation.current_route()})

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CLOUD_VISUAL_FAIL " + label)
