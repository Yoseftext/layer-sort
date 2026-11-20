extends SceneTree

## Run: godot --headless --path . --script res://tests/runtime/godot_runtime_test.gd

var checks: int = 0
var failures: int = 0
var _retained_camera_texture: CameraTexture = null


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("RUNTIME_FAIL: " + message)


func _run() -> void:
	_retained_camera_texture = CameraTexture.new()
	_check(_retained_camera_texture != null, "camera texture instantiated")
	_check(_retained_camera_texture is CameraTexture, "texture instance is CameraTexture")
	_check(_retained_camera_texture.camera_feed_id == 0, "default camera_feed_id is 0")
	_check(not _retained_camera_texture.camera_is_active, "camera feed inactive by default")
	_check(_retained_camera_texture.which_feed == CameraServer.FEED_RGBA_IMAGE, "default feed image is RGBA")

	# Give background discovery a bounded survival window; this does not attest thread completion.
	await create_timer(1.2).timeout
	await process_frame

	_check(_retained_camera_texture != null, "retained camera texture survived discovery period")
	_check(_retained_camera_texture is CameraTexture, "retained instance remains valid CameraTexture")
	_check(_retained_camera_texture.camera_feed_id == 0, "camera_feed_id unchanged after discovery")
	_check(not _retained_camera_texture.camera_is_active, "camera feed remains inactive")

	var ld_preload: String = OS.get_environment("LD_PRELOAD")
	var compatibility_active: bool = ld_preload.contains("libgodot-scandir-guard.so")

	var status: String = "PASS" if failures == 0 else "FAIL"
	print("GODOT_RUNTIME_TESTS %s checks=%d failures=%d compatibility_active=%s" % [
		status,
		checks,
		failures,
		"true" if compatibility_active else "false",
	])

	if failures > 0:
		printerr("GODOT_RUNTIME_TESTS failed with %d error(s)" % failures)
		quit(1)
	else:
		quit(0)
