extends SceneTree
func _initialize() -> void:
	var checks: int = 0
	for width: float in [22.0, 33.333333, 45.333333, 62.0, 86.0]:
		for height: float in [8.0, 30.0, 72.0, 100.0]:
			var region: Rect2 = Rect2(17, 23, width, height)
			for count: int in range(1, 7):
				var radius: float = TubePainter.marker_radius(region)
				var bounds: Rect2 = Rect2(TubePainter.marker_center(region, count, 0) - Vector2.ONE * radius, Vector2.ONE * radius * 2)
				for index: int in range(count):
					var center: Vector2 = TubePainter.marker_center(region, count, index)
					var circle: Rect2 = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
					assert(region.encloses(circle), "entire circle inside liquid")
					bounds = bounds.merge(circle)
					for other: int in range(index):
						assert(center.distance_to(TubePainter.marker_center(region, count, other)) >= radius * 3 - 0.001)
					checks += 1
				assert(bounds.get_center().distance_to(region.get_center()) < 0.001, "complete marker group centered")
				checks += 1
	print("MARKER_GEOMETRY_PASS checks=%d" % checks)
	quit()
