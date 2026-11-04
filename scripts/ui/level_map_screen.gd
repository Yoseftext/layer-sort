class_name LevelMapScreen
extends Control

signal level_requested(id: String)
signal home_requested
var language: String = "en"
var catalog: LevelCatalog
var progression: Progression
var selected_level: String = ""
const PAGE_SIZE: int = 60
var _page: int = 0
var _grid: GridContainer
var _scroll: TouchLevelScroll

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	ScreenWidgets.background(self)
	var column: VBoxContainer = ScreenWidgets.stack(self)
	column.add_child(ScreenWidgets.label(UiText.get_text("level_map", language), 46))
	_scroll = TouchLevelScroll.new()
	_scroll.name = "LevelScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_scroll.add_child(_grid)
	if catalog.available_level_ids.size() > PAGE_SIZE:
		var pages: HBoxContainer = HBoxContainer.new()
		column.add_child(pages)
		for direction: int in [-1, 1]:
			var page: Button = ScreenWidgets.button(("السابق" if direction < 0 else "التالي") if language == "ar" else ("Previous" if direction < 0 else "Next"))
			pages.add_child(page)
			page.pressed.connect(func() -> void:
				_page = clampi(_page + direction, 0, (catalog.available_level_ids.size() - 1) / PAGE_SIZE)
				_populate())
	var home: Button = ScreenWidgets.button(UiText.get_text("home", language))
	column.add_child(home)
	home.pressed.connect(func() -> void: home_requested.emit())
	resized.connect(_resize_grid)
	_populate()

func _resize_grid() -> void:
	_grid.columns = clampi(int((size.x - 48.0) / 160.0), 1, 3)

func _populate() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for index: int in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, catalog.available_level_ids.size())):
		var id: String = catalog.available_level_ids[index]
		var done: bool = progression.completed.has(id)
		var unlocked: bool = progression.is_unlocked(id)
		var status: String = "completed" if done else ("unlocked" if unlocked else "locked")
		var label: String = id.trim_prefix("level_") + ("  ★" if done else "") + "\n" + UiText.get_text(status, language)
		if id == selected_level:
			label += "\n" + ("الحالي" if language == "ar" else "Current")
		var button: Button = ScreenWidgets.button(label, id == selected_level)
		button.name = id
		button.custom_minimum_size = Vector2(140, 240)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 24)
		button.disabled = not unlocked
		if not unlocked:
			var locked_style: StyleBoxFlat = StyleBoxFlat.new()
			locked_style.bg_color = Color("1b2a40")
			locked_style.border_color = Color("40546c")
			locked_style.set_border_width_all(1)
			locked_style.set_corner_radius_all(24)
			button.add_theme_stylebox_override("disabled", locked_style)
			button.add_theme_color_override("font_disabled_color", Color("a8b8cf"))
		_grid.add_child(button)
		button.pressed.connect(func() -> void:
			if _scroll.allows_activation():
				level_requested.emit(id))
	_scroll.scroll_vertical = 0
	_resize_grid()
