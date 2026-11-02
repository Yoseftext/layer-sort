class_name TouchLevelScroll
extends ScrollContainer

## Own a single raw touch before buttons consume GUI input. Mouse/wheel remain native.
var _finger: int = -1
var _start: Vector2
var _last: Vector2
var _dragging: bool = false
var _cancelled: bool = false
var _last_touch_ms: int = -1000
var _touch_activation: bool = false
var _button: Button

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouse and event.device == -1 and (_finger >= 0 or get_global_rect().has_point(event.position)):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _finger >= 0:
				_cancelled = true
				return
			if not get_global_rect().has_point(touch.position):
				return
			_finger = touch.index
			_start = touch.position
			_last = _start
			_dragging = false
			_cancelled = false
			_button = null
			for node: Node in find_children("*", "Button", true, false):
				var button: Button = node as Button
				if button.get_global_rect().has_point(_start):
					_button = button
			get_viewport().set_input_as_handled()
		elif touch.index == _finger:
			get_viewport().set_input_as_handled()
			var chosen: Button = _button
			_finger = -1
			_button = null
			if not _cancelled and not _dragging and is_instance_valid(chosen) and not chosen.disabled and chosen.get_global_rect().has_point(touch.position):
				_touch_activation = true
				chosen.pressed.emit()
				_touch_activation = false
	elif event is InputEventScreenDrag and event.index == _finger:
		_last_touch_ms = Time.get_ticks_msec()
		var drag: InputEventScreenDrag = event
		if drag.position.distance_to(_start) > 12.0:
			_dragging = true
		if _dragging and not _cancelled:
			scroll_vertical -= roundi(drag.position.y - _last.y)
		_last = drag.position
		get_viewport().set_input_as_handled()


func allows_activation() -> bool:
	return _touch_activation or Time.get_ticks_msec() - _last_touch_ms > 250
