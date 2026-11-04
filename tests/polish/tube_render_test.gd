extends SceneTree

var output: String
var checks: int = 0
var failures: int = 0
var comparisons: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("TUBE_POLISH_FAIL " + label)

func run() -> void:
	output = OS.get_environment("VISUAL_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for width: int in [600, 720]:
		root.content_scale_size = Vector2i(width, 1600)
		root.size = Vector2i(width, 1600)
		for language: String in ["ar", "en"]:
			for count: int in [3, 6]:
				for batch: int in range(2 if count == 3 else 1):
					for fill: int in [0, 2, 4]:
						for selected: bool in [false, true]:
							await fixture(width, language, count, batch * 3, fill, selected, false)
							if width == 600 and language == "ar" and count == 6 and fill == 4 and not selected:
								await fixture(width, language, count, 0, fill, selected, true)
			var game: ClassicGame = ClassicGame.new()
			game.language = language
			game.level_path = "res://content/levels/level_016.json"
			root.add_child(game)
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await create_timer(0.2).timeout
			await capture("game16-%d-%s" % [width,language], width == 600 and language == "ar")
			game.queue_free()
			await process_frame
	print("TUBE_POLISH_METRICS ", JSON.stringify(comparisons))
	check(comparisons.after.internal < comparisons.before.internal, "internal highlights quieter in actual pixels")
	check(absf(comparisons.after.top - comparisons.before.top) < 0.02, "top priority preserved in actual pixels")
	check(absf(comparisons.after.boundary - comparisons.before.boundary) < 0.02, "inter-colour separation preserved in actual pixels")
	print("TUBE_POLISH_PASS checks=%d" % checks if failures == 0 else "TUBE_POLISH_FAIL failures=%d" % failures)
	call_deferred("quit", 0 if failures == 0 else 1)

func fixture(width: int, language: String, count: int, start: int, fill: int, selected: bool, before: bool) -> void:
	var surface: Control = Control.new()
	surface.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
	surface.theme = OpticalTheme.create()
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = OpticalTheme.NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(background)
	var title: Label = Label.new()
	title.text = "اختبار رسم فعلي — ليس مستوى لعب" if language == "ar" else "Live renderer fixture — not a playable level"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	surface.add_child(title)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	var views: Array[TubeView] = []
	for index: int in range(count):
		var view: TubeView = TubeView.new()
		view.reduce_motion = true
		row.add_child(view)
		view.custom_minimum_size = Vector2(clampf((width - 88.0 - 12.0 * (count-1)) / count, 64, 116), 350)
		if before:
			view._painter.internal_highlight_alpha = 0.30
			view._painter.internal_surface_lightening = 0.10
		var layers: Array[int] = []
		for layer: int in range(fill):
			layers.append((start + index + layer) % 6)
		view.show_tube(TubeModel.new(layers), 4, selected)
		views.append(view)
	await create_timer(0.12).timeout
	var name: String = "%d-%s-%dt-b%d-fill%d-selected%s-%s" % [width, language, count, start, fill, selected, "before" if before else "after"]
	var sample: bool = width == 600 and language == "ar" and count == 6 and fill == 4 and not selected
	var preview: bool = sample or (width == 600 and language == "ar" and count == 3 and start == 0 and not selected and fill < 4) or (width == 600 and language == "ar" and count == 6 and fill == 4 and selected) or (width == 720 and language == "en" and count == 6 and fill == 4 and not selected)
	var rendered: Image = await capture(name, preview)
	for view: TubeView in views:
		var inner: Rect2 = Rect2(Vector2(21, 26 - view._lift), Vector2(view.size.x - 42, view.size.y - 66))
		for layer: int in range(fill):
			var region: Rect2 = Rect2(inner.position.x, inner.end.y - inner.size.y / 4 * (layer + 1), inner.size.x, inner.size.y / 4)
			var palette: int = view.logical_layers[layer]
			for dot: int in range(palette+1):
				var point: Vector2 = TubePainter.marker_center(region, palette+1, dot)
				var radius: float = TubePainter.marker_radius(region)
				check(region.encloses(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2)), "drawn marker geometry stays inside liquid")
	if sample:
		var values: Dictionary = {"top":0.0,"internal":0.0,"boundary":0.0}
		for view: TubeView in views:
			var p: Vector2 = view.global_position + Vector2(21 + (view.size.x-42)*0.85, 26)
			var step: float = (view.size.y-66)/4
			values.top += luminance(rendered,p+Vector2(0,2))-luminance(rendered,p+Vector2(0,8))
			values.internal += luminance(rendered,p+Vector2(0,step+1))-luminance(rendered,p+Vector2(0,step+8))
			values.boundary += absf(luminance(rendered,p+Vector2(0,step-8))-luminance(rendered,p+Vector2(0,step+8)))
		for key: String in values:
			values[key] /= count
		comparisons["before" if before else "after"] = values
	surface.queue_free()
	await process_frame

func luminance(rendered: Image, point: Vector2) -> float:
	var c: Color = rendered.get_pixel(int(point.x),int(point.y))
	return c.r*0.2126+c.g*0.7152+c.b*0.0722

func capture(name: String, log_preview: bool) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	check(rendered.save_png(output.path_join(name+".png")) == OK, "PNG capture saved")
	# Bounded PNG transport through existing job logs for actual visual inspection;
	# artifact storage remains authoritative for the complete screenshot matrix.
	if log_preview:
		var encoded: String = Marshalls.raw_to_base64(rendered.save_png_to_buffer())
		print("POLISH_PNG_BEGIN ",name)
		for offset: int in range(0,encoded.length(),4000):
			print("POLISH_PNG_CHUNK ",encoded.substr(offset,4000))
		print("POLISH_PNG_END ",name)
	return rendered
