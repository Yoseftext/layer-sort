extends SceneTree

class FailingSave extends SaveRepository:
	func _write_temp(_path: String, _contents: String) -> bool:
		return false

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/navigation/root.tscn")
	var nav: NavigationCoordinator = scene.instantiate()
	root.add_child(nav)
	await create_timer(0.65).timeout
	nav.show_settings()
	var settings: SettingsScreen = nav.current_screen() as SettingsScreen
	check(not (settings.find_child("EnglishButton", true, false) as Button).disabled, "selected language stays enabled")
	check((settings.find_child("EnglishButton", true, false) as Button).button_pressed, "selected language marked")
	(settings.find_child("ArabicButton", true, false) as Button).pressed.emit()
	settings = nav.current_screen() as SettingsScreen
	check(settings.language == "ar" and settings.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic RTL")
	check((settings.find_child("ArabicButton", true, false) as Button).button_pressed, "Arabic selected state")
	nav.go_home()
	nav.show_about()
	var about: AboutScreen = nav.current_screen() as AboutScreen
	var version_label: Label = null
	for child: Node in about.find_children("*", "Label", true, false):
		if (child as Label).text.contains("0.3.2-g3b"):
			version_label = child as Label
	check(version_label != null, "About matches APK version")
	nav.go_home()
	nav.set("_saves", FailingSave.new())
	check(nav.open_level("level_001"), "game opens despite save write failure")
	var warning: ConfirmationDialog = nav.get("_save_dialog") as ConfirmationDialog
	check(warning != null and warning.visible, "write failure shown")
	check(warning.dialog_text == UiText.get_text("save_write_error", "ar"), "Arabic save failure text")
	check((nav.current_screen() as ClassicGame) != null, "game retained in memory")
	warning.hide()
	nav.request_home()
	check(nav.current_screen() is HomeScreen, "failed exit reaches Home with warning")
	check((nav.current_screen() as HomeScreen).continue_enabled, "failed exit retains Continue")
	check(not (nav.get("_active") as Dictionary).is_empty(), "failed exit keeps attempt in memory")
	(nav.get("_save_dialog") as ConfirmationDialog).hide()
	var repository: SaveRepository = SaveRepository.new()
	repository.directory = "user://g3br_remediation_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(repository.directory))
	nav.set("_saves", repository)
	nav.call("_retry_save")
	check(not nav.get("_save_failed"), "retry saves current state")
	check(repository.load_latest(LevelCatalog.load_catalog().catalog).ok, "retried save readable")
	nav.queue_free()
	print("G3B_REMEDIATION_TESTS status=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("G3B_REMEDIATION_FAIL " + description)
