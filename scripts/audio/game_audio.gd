class_name GameAudio
extends Node

## Four reusable voices. No global audio state, queue or resume replay.
const CUES: Dictionary = {
	"select": preload("res://content/audio/select.wav"),
	"pour": preload("res://content/audio/pour.wav"),
	"invalid": preload("res://content/audio/invalid.wav"),
	"complete": preload("res://content/audio/complete.wav"),
	"win": preload("res://content/audio/win.wav"),
	"ui": preload("res://content/audio/ui.wav")
}
var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			stop_all()
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _has_focus: bool = true
var _application_paused: bool = false

func _ready() -> void:
	for index: int in range(4):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.volume_db = -5.0
		add_child(voice)
		_voices.append(voice)

func play(cue: String) -> void:
	if not enabled or not _has_focus or _application_paused or _voices.is_empty() or not CUES.has(cue):
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stop()
	voice.stream = CUES[cue] as AudioStream
	voice.play()

func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()

func _exit_tree() -> void:
	stop_all()
	for voice: AudioStreamPlayer in _voices:
		voice.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_focus = false
		stop_all()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_application_paused = true
		stop_all()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_has_focus = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_paused = false
