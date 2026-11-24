extends SceneTree

const Layout = preload("res://scripts/table_layout_3d.gd")
const Scene3D = preload("res://scripts/table_scene_3d.gd")
const Atlas = preload("res://scripts/table_tile_atlas.gd")

var failures := 0


func _initialize() -> void:
	test_uniform_thickness()
	test_high_res_pipeline()
	test_zero_occlusion_full_wall()
	if failures == 0:
		print("v1.3.3d thickness, high-res scaling and zero-occlusion checks passed")
	quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func test_uniform_thickness() -> void:
	check(is_equal_approx(Layout.WALL_THICKNESS, Layout.RIVER_THICKNESS)
		and is_equal_approx(Layout.MELD_THICKNESS, Layout.RIVER_THICKNESS),
		"wall, river and meld share one uniform thickness scale")
	var wall_pose := Layout.wall_pose(0, 0)
	var river_pose := Layout.river_pose(0, 0, 6)
	var melds := [
		{"type": "chow", "tiles": [0, 1, 2], "from": 3, "claimed": 1},
		{"type": "pong", "tiles": [9, 9, 9], "from": 2, "claimed": 9},
		{"type": "kong", "tiles": [18, 18, 18, 18], "from": 1, "claimed": 18},
		{"type": "concealedKong", "tiles": [-1, 5, 5, -1], "from": 0},
		{"type": "addedKong", "tiles": [12, 12, 12, 12], "from": 3, "claimed": 12},
	]
	check(is_equal_approx(wall_pose.basis.y.length(), river_pose.basis.y.length()),
		"full-scale wall and river tiles have identical thickness")
	for seat in range(4):
		var group: Dictionary = Layout.hand_group(2, true, melds) if seat == 0 else \
			Layout.side_group(seat, 2, melds, true)
		var base_scale: float = group.melds[0][0].basis.x.length()
		for meld_poses: Array in group.melds:
			for pose: Transform3D in meld_poses:
				check(is_equal_approx(pose.basis.y.length(), base_scale * Layout.MELD_THICKNESS),
					"every meld tile uses the shared thickness scale")
		var support: Transform3D = group.melds[4][0]
		var added: Transform3D = group.melds[4][3]
		var vertical_gap := added.origin.y - support.origin.y
		check(vertical_gap >= Layout.WALL_STOREY * base_scale * Layout.MELD_THICKNESS - 0.001,
			"added kong stacks cleanly atop the thickened claimed tile")
		if seat > 0:
			var revealed_tile: Transform3D = group.hand[0]
			check(is_equal_approx(revealed_tile.basis.y.length(), base_scale * Layout.MELD_THICKNESS),
				"revealed opponent tiles match meld thickness")


func test_high_res_pipeline() -> void:
	check(Atlas.INK_SIZE.x >= 240 and Atlas.INK_SIZE.y >= 320,
		"tile face atlas cell is sized for sharp 2K rendering")
	var scene := Scene3D.new()
	var center_before := scene.project_point(Vector3.ZERO)
	scene.set_render_scale(1.8)
	check(scene.target_viewport_size() == Vector2i(2304, 1440),
		"2K fullscreen targets native 2304x1440 subviewport resolution")
	check(scene.project_point(Vector3.ZERO).is_equal_approx(center_before),
		"changing render scale preserves 1280x800 logical projection coordinates")
	scene.set_appearance(null, "off")
	check(scene.target_viewport_size() == Vector2i(1920, 1200),
		"effects-off mode caps subviewport scale for low-end stability")
	scene.free()


func test_zero_occlusion_full_wall() -> void:
	var scene := Scene3D.new()
	var wall_top_min_y := INF
	var near_wall_min_y := INF
	var left_wall_rects: Array[Rect2] = []
	var right_wall_rects: Array[Rect2] = []
	for slot in range(0, 144, 2):
		var pose := Layout.wall_pose(slot, 0)
		var rect := scene.project_rect(pose)
		var side := int(floori(float(slot) / 36.0))
		match side:
			0:
				near_wall_min_y = minf(near_wall_min_y, rect.position.y)
			1:
				right_wall_rects.append(rect)
			2:
				wall_top_min_y = minf(wall_top_min_y, rect.position.y)
			3:
				left_wall_rects.append(rect)

	var melds := [
		{"type": "chow", "tiles": [0, 1, 2], "from": 3, "claimed": 1},
		{"type": "pong", "tiles": [9, 9, 9], "from": 2, "claimed": 9},
		{"type": "addedKong", "tiles": [12, 12, 12, 12], "from": 3, "claimed": 12},
	]
	# Far seat (seat 2): melds and revealed hand stay strictly above the far wall top edge
	# and below the top avatar badge (y = 88).
	var far_group := Layout.side_group(2, 7, melds, true)
	for pose: Transform3D in _flatten(far_group):
		var face := _face_bounds(scene, pose)
		check(face.end.y < wall_top_min_y,
			"far seat melds and revealed hand clear the top of a full far wall (%.1f < %.1f)" % [face.end.y, wall_top_min_y])
		check(face.position.y > 88.0,
			"far seat melds and revealed hand stay below the top avatar badge")

	# Left seat (seat 3): melds and revealed hand do not overlap any left wall stack in screen space.
	var left_group := Layout.side_group(3, 7, melds, true)
	for pose: Transform3D in _flatten(left_group):
		var quad := scene.project_face(pose, false)
		for wall_rect in left_wall_rects:
			check(Geometry2D.intersect_polygons(quad, _rect_poly(wall_rect)).is_empty(),
				"left seat meld/revealed face does not overlap full left wall")

	# Right seat (seat 1): melds and revealed hand do not overlap any right wall stack in screen space.
	var right_group := Layout.side_group(1, 7, melds, true)
	for pose: Transform3D in _flatten(right_group):
		var quad := scene.project_face(pose, false)
		for wall_rect in right_wall_rects:
			check(Geometry2D.intersect_polygons(quad, _rect_poly(wall_rect)).is_empty(),
				"right seat meld/revealed face does not overlap full right wall")

	# Near river (seat 0): all 6..36 discards stay above the near wall top edge.
	for count in [6, 12, 18, 24, 36]:
		for index in range(count):
			var face := _face_bounds(scene, Layout.river_pose(0, index, count))
			check(face.end.y < near_wall_min_y,
				"near river (%d tiles) stays clear of the full near wall" % count)

	scene.free()


func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _flatten(group: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for pose: Transform3D in group.hand:
		result.append(pose)
	for meld: Array in group.melds:
		for pose: Transform3D in meld:
			result.append(pose)
	return result


func _face_bounds(scene: Scene3D, pose: Transform3D) -> Rect2:
	var quad := scene.project_face(pose, false)
	var bounds := Rect2(quad[0], Vector2.ZERO)
	for point in quad:
		bounds = bounds.expand(point)
	return bounds
