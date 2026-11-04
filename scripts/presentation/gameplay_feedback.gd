class_name GameplayFeedback
extends Label

## Transient overlay: no board relayout, permanent instructions or async callbacks.
var _expiry: Timer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 21)
	add_theme_color_override("font_color", OpticalTheme.MUTED)
	_expiry = Timer.new()
	_expiry.one_shot = true
	_expiry.wait_time = 2.0
	add_child(_expiry)
	_expiry.timeout.connect(hide)
	hide()

func show_message(value: String) -> void:
	text = value
	show()
	_expiry.start()

func dismiss() -> void:
	hide()
	_expiry.stop()
