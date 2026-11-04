extends Control

## G1 native Android smoke scene.
##
## This is deliberately not gameplay. It proves that the pinned Godot Standard
## build starts in portrait, renders the GDScript scene, stays alive, and
## produces a visible/logged response to one real Appium touch.

const READY_MARKER: String = "LAYER_SORT_G1_READY"
const TAP_MARKER: String = "LAYER_SORT_G1_TAP"
const TICK_MARKER: String = "LAYER_SORT_G1_TICK"
const HEARTBEAT_SECONDS: int = 5

@onready var _tap_button: Button = %TapButton
@onready var _status_label: Label = %StatusLabel
@onready var _tap_count_label: Label = %TapCountLabel

var _tap_count: int = 0
var _elapsed_seconds: float = 0.0
var _last_heartbeat: int = -1


func _ready() -> void:
	_tap_button.pressed.connect(_on_tap_button_pressed)
	_status_label.text = "GDScript scene ready"
	_tap_count_label.text = "Taps: 0"
	print(READY_MARKER)


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	var whole_seconds: int = int(_elapsed_seconds)
	if whole_seconds < HEARTBEAT_SECONDS:
		return
	if whole_seconds % HEARTBEAT_SECONDS != 0 or whole_seconds == _last_heartbeat:
		return
	_last_heartbeat = whole_seconds
	print("%s %d" % [TICK_MARKER, whole_seconds])


func _on_tap_button_pressed() -> void:
	_tap_count += 1
	_status_label.text = "Touch verified"
	_tap_count_label.text = "Taps: %d" % _tap_count
	print("%s %d" % [TAP_MARKER, _tap_count])
