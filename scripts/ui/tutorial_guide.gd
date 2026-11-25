class_name TutorialGuide
extends Control

## One brief contextual cue after inactivity, never a permanent instruction bar.
var game: ClassicGame
var _dismissed: bool = false
var _target: int = -1
var _timer: Timer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 3.0
	add_child(_timer)
	_timer.timeout.connect(_hint)
	game.state_committed.connect(_committed)
	_timer.start()

func _committed(_state: GameState, _won: bool) -> void:
	_dismissed = true
	_target = -1
	_timer.stop()
	game._status.dismiss()
	queue_redraw()

func _hint() -> void:
	if _target >= 0:
		_target = -1
		queue_redraw()
		return
	if _dismissed or game._suspended or not game.is_visible_in_tree() or game._session.animation_locked:
		return
	var state: GameState = game.committed_snapshot()
	if state.move_count > 0:
		return
	for source: int in range(state.tubes.size()):
		if game._selected_source >= 0 and source != game._selected_source:
			continue
		for destination: int in range(state.tubes.size()):
			if MoveRules.validate(state, source, destination).is_empty():
				_target = destination if game._selected_source >= 0 else source
				break
		if _target >= 0:
			break
	_dismissed = true
	game._status.show_message(UiText.get_text("choose_destination", game.language) % (game._selected_source + 1) if game._selected_source >= 0 else UiText.get_text("choose", game.language))
	_timer.start()
	queue_redraw()

func _draw() -> void:
	if _target < 0 or game._suspended:
		return
	var tube: Control = game._views[_target]
	var box: Rect2 = Rect2(tube.global_position - global_position, tube.size).grow(4)
	draw_rect(box, ScreenWidgets.ACCENT, false, 3)
	var point: Vector2 = box.position + Vector2(box.size.x * 0.5, box.size.y + 16)
	draw_line(point + Vector2(0, 24), point, ScreenWidgets.TEXT, 9, true)
	draw_circle(point, 4.5, ScreenWidgets.TEXT)
	draw_circle(point + Vector2(5, 25), 10, ScreenWidgets.TEXT)
