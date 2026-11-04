class_name TutorialGuide
extends Control

## Nonblocking presentation only: no moves, persistence or history ownership.
var game: ClassicGame
var _idle: float = 0.0
var _dismissed: bool = false
var _target: int = -1
var _toggle: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toggle = ScreenWidgets.button("")
	_toggle.name = "TutorialToggle"
	_toggle.custom_minimum_size.y = 64
	_toggle.add_theme_font_size_override("font_size", 20)
	_toggle.pressed.connect(func() -> void:
		_dismissed = not _dismissed
		_idle = 0.0)
	var help: Label = game.find_child("GameHelp", true, false) as Label
	# Reserve this slot when the hint disappears; never shift a pouring board.
	var slot: Control = Control.new()
	slot.custom_minimum_size.y = 64
	help.get_parent().add_child(slot)
	slot.add_child(_toggle)
	_toggle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_idle += delta
	var state: GameState = game.committed_snapshot()
	var selected: int = game.get("_selected_source")
	if state.move_count > 0:
		_dismissed = true
		_target = -1
		_toggle.hide()
		(game.find_child("GameHelp", true, false) as Label).text = UiText.get_text("game_help", game.language)
		queue_redraw()
		set_process(false)
		return
	_toggle.text = ("إظهار التلميح" if _dismissed else "إخفاء التلميح") if game.language == "ar" else ("Show hint" if _dismissed else "Hide hint")
	_toggle.visible = state.move_count == 0
	_target = -1
	var session: GameSession = game.get("_session")
	if not _dismissed and not game.get("_suspended") and not session.animation_locked:
		for source: int in range(state.tubes.size()):
			if selected >= 0 and source != selected:
				continue
			for destination: int in range(state.tubes.size()):
				if MoveRules.validate(state, source, destination).is_empty():
					_target = destination if selected >= 0 else source
					break
			if _target >= 0:
				break
		var help: Label = game.find_child("GameHelp", true, false) as Label
		var lessons: Array[String] = ["Select a tube, then an empty tube.", "Match the top colour or use an empty tube.", "A matching top block pours together.", "Use Undo to explore; Restart begins again.", "Fill each colour into one complete tube."]
		var arabic: Array[String] = ["اختر أنبوبًا ثم أنبوبًا فارغًا.", "طابق اللون العلوي أو اختر أنبوبًا فارغًا.", "تنتقل الطبقات العلوية المتطابقة معًا.", "جرّب التراجع؛ إعادة البدء تعيد اللغز.", "اجمع كل لون في أنبوب كامل."]
		var index: int = state.level_id.trim_prefix("level_").to_int() - 1
		help.text = (arabic if game.language == "ar" else lessons)[index]
	else:
		(game.find_child("GameHelp", true, false) as Label).text = UiText.get_text("game_help", game.language)
	queue_redraw()

func _draw() -> void:
	if _target < 0 or _idle < 3.0:
		return
	var views: Array = game.get("_views")
	var tube: Control = views[_target]
	var box: Rect2 = Rect2(tube.global_position - global_position, tube.size).grow(4)
	draw_rect(box, ScreenWidgets.ACCENT, false, 3)
	# Original static finger silhouette; no motion when Reduced Motion is enabled.
	var point: Vector2 = box.position + Vector2(box.size.x * 0.5, box.size.y + 16)
	draw_line(point + Vector2(0, 24), point, ScreenWidgets.TEXT, 9, true)
	draw_circle(point, 4.5, ScreenWidgets.TEXT)
	draw_circle(point + Vector2(5, 25), 10, ScreenWidgets.TEXT)
