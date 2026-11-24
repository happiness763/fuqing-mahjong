extends SceneTree

const LAYOUT_PATH := "res://scripts/table_layout_3d.gd"
const DESIGN_CENTER := Vector2(640.0, 400.0)
const CAMERA := Vector3(0.0, 22.3, 15.5)
const CAMERA_TARGET := Vector3(0.0, 0.0, 0.46)
const CAMERA_FOV := 36.9
const TILE_HALF := Vector3(0.36, 0.158, 0.48)
const RIGHT := [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
const OUTWARD := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]

var layout
var failures := 0


func _initialize() -> void:
	if not ResourceLoader.exists(LAYOUT_PATH):
		check(false, "3D layout is available to the table renderer")
		quit(1)
		return
	layout = load(LAYOUT_PATH)
	test_tile_transform()
	test_wall()
	test_rivers()
	test_groups()
	test_table_rails()
	if failures == 0:
		print("v1.3.3c 3D wall, rivers, hands and meld layout passed")
	quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func test_tile_transform() -> void:
	var point := Vector3(2.0, 3.0, 4.0)
	var pose: Transform3D = layout.tile_pose(point, PI / 2.0, PI / 2.0, 2.0, 1.5)
	check(pose.origin.is_equal_approx(point), "model scale keeps the supplied center")
	check(pose.basis.x.is_equal_approx(Vector3.FORWARD * 2.0), "yaw turns the tile around the table up axis")
	check(pose.basis.y.is_equal_approx(Vector3.RIGHT * 3.0), "tilt and modified thickness are measured on model axes")
	check(pose.basis.z.is_equal_approx(Vector3.DOWN * 2.0), "tile length stays uniformly scaled as it stands upright")


func test_wall() -> void:
	var positions := {}
	for seat in range(4):
		var first: Transform3D = layout.wall_pose(0, seat)
		var last: Transform3D = layout.wall_pose(34, seat)
		var across: Vector3 = RIGHT[seat]
		var outward: Vector3 = OUTWARD[seat]
		check(first.origin.dot(outward) > 5.0 and last.origin.dot(outward) > 5.0,
			"dealer rotates slot zero to the expected wall")
		check((last.origin - first.origin).normalized().is_equal_approx(across),
			"slot indices increase along the old wall draw direction")
		for j in range(36):
			var slot := seat * 36 + j
			var pose: Transform3D = layout.wall_pose(slot, 0)
			positions[pose.origin] = true
			check(pose.is_equal_approx(layout.wall_pose(j, seat)), "rotating the dealer preserves stack and layer")
			check(pose.basis.y.normalized().is_equal_approx(Vector3.DOWN), "the wall displays tile backs")
			if j % 2 == 0:
				var bottom: Transform3D = layout.wall_pose(slot + 1, 0)
				var offset := pose.origin - bottom.origin
				check(offset.normalized().is_equal_approx(Vector3.UP) and offset.y > 0.4,
					"even slot is the upper tile of each thick stack")
	check(positions.size() == 144, "every physical wall slot has a distinct pose")


func test_rivers() -> void:
	var walls: Array[Rect2] = []
	var near_wall_top := INF
	for slot in range(0, 144, 2):
		var pose: Transform3D = layout.wall_pose(slot, 0)
		walls.append(footprint(pose))
		if slot < 36:
			near_wall_top = minf(near_wall_top, screen_bounds(pose).position.y)
	for count in [6, 7, 18, 19, 24, 36, 72]:
		var occupied: Array[Rect2] = []
		for seat in range(4):
			var first: Transform3D = layout.river_pose(seat, 0, count)
			var sixth: Transform3D = layout.river_pose(seat, 5, count)
			var across: Vector3 = RIGHT[seat]
			var outward: Vector3 = OUTWARD[seat]
			check((sixth.origin - first.origin).normalized().is_equal_approx(across),
				"each first row contains six tiles in the seat's reading direction")
			if count >= 7:
				var seventh: Transform3D = layout.river_pose(seat, 6, count)
				check((seventh.origin - first.origin).normalized().is_equal_approx(outward),
					"seventh tile starts the next row outward")
			for index in range(count):
				var pose: Transform3D = layout.river_pose(seat, index, count)
				var bounds := footprint(pose)
				check(pose.basis.y.normalized().is_equal_approx(Vector3.UP), "river tiles lie face up")
				check(is_equal_approx(pose.basis.x.length(), pose.basis.z.length()), "river compresses tile art uniformly")
				check(Rect2(Vector2.ZERO, 2.0 * DESIGN_CENTER).encloses(screen_bounds(pose)), "river tile stays in camera")
				if seat == 0:
					check(screen_bounds(pose, true).end.y < near_wall_top,
						"lower shed rows stay readable behind a full two-storey near wall")
				for previous in occupied:
					check(not bounds.intersects(previous), "same-seat and neighboring rivers occupy distinct footprints")
				for wall in walls:
					check(not bounds.intersects(wall), "river leaves all 144 wall slots available")
				occupied.append(bounds)


func test_groups() -> void:
	var melds: Array = []
	for kind in ["chow", "pong", "kong", "concealedKong", "addedKong"]:
		melds.append({"type": kind, "tiles": [9, 10, 11] if kind == "chow" else
			[-1, 9, 9, -1] if kind == "concealedKong" else [9, 9, 9] if kind == "pong" else [9, 9, 9, 9],
			"from": 3, "claimed": 10 if kind == "chow" else 9})
	var plain: Array = layout.hand_group(17, false, []).hand
	var separated: Array = layout.hand_group(17, true, []).hand
	check(separated.size() == 17 and separated[16].origin.x - separated[15].origin.x >
		plain[16].origin.x - plain[15].origin.x + 0.25, "drawn tile is the last tile with a visible gap")
	for pose: Transform3D in separated:
		check(pose.basis.y.normalized().dot(Vector3.BACK) > 0.6, "local hand leans toward the viewer")
		check(Rect2(100.0, 595.0, 1080.0, 205.0).encloses(screen_bounds(pose)), "17-tile hand fits in the lower rail")
	for seat in range(4):
		var across: Vector3 = RIGHT[seat]
		var outward: Vector3 = OUTWARD[seat]
		for meld: Dictionary in melds:
			for distance in [1, 2, 3]:
				meld.from = posmod(seat + distance, 4)
				var expected: int = [2, 1, 0][distance - 1]
				if meld.type == "kong" and distance == 1:
					expected = 3
				if meld.type == "chow":
					expected = 1
				if meld.type == "concealedKong":
					expected = -1
				check(layout.meld_source_index(meld, seat) == expected, "claimed position agrees with legacy tile order")
		var group: Dictionary = layout.hand_group(2, true, melds) if seat == 0 else layout.side_group(seat, 2, melds)
		check(group.hand.size() == 2 and group.melds.size() == 5, "all requested hand tiles and meld groups fit")
		var previous: Transform3D = group.hand.back()
		for meld_index in range(5):
			var poses: Array = group.melds[meld_index]
			var expected: int = [3, 3, 4, 4, 4][meld_index]
			check(poses.size() == expected, "meld array retains tile order and appends the added tile")
			for tile_index in range(expected if meld_index != 4 else 3):
				var pose: Transform3D = poses[tile_index]
				check(not footprint(previous).intersects(footprint(pose)), "hand and adjacent meld tiles do not intersect")
				check(pose.origin.dot(across) > previous.origin.dot(across), "melds continue along the local right axis")
				var sideways: bool = tile_index == [1, 0, 0, -1, 0][meld_index]
				check(pose.basis.x.normalized().is_equal_approx(-outward if sideways else across), "claimed tile lies crosswise")
				var tile: int = melds[meld_index].tiles[tile_index]
				check(pose.basis.y.normalized().is_equal_approx(Vector3.UP if tile >= 0 else Vector3.DOWN),
					"concealed kong only turns hidden tile backs up")
				check(Rect2(Vector2.ZERO, 2.0 * DESIGN_CENTER).encloses(screen_bounds(pose)), "meld stays in camera")
				previous = pose
		var support: Transform3D = group.melds[4][0]
		var added: Transform3D = group.melds[4][3]
		check((added.origin - support.origin).normalized().is_equal_approx(Vector3.UP) and added.basis.is_equal_approx(support.basis),
			"added kong stacks above the crossed tile with the same orientation")
		if seat > 0:
			var concealed: Transform3D = group.hand[0]
			var revealed: Dictionary = layout.side_group(seat, 2, melds, true)
			var public_tile: Transform3D = revealed.hand[0]
			check(concealed.basis.y.normalized().is_equal_approx(outward), "standing backs face the rest of the table")
			check(public_tile.basis.y.normalized().is_equal_approx(Vector3.UP), "revealed opponent tiles lie face up")
			check(revealed.melds == group.melds, "revealing an opponent hand keeps existing meld poses fixed")
			check(not footprint(public_tile).intersects(footprint(revealed.melds[0][0])),
				"revealed opponent tiles stay clear of that seat's melds")


func test_table_rails() -> void:
	# Five four-tile groups put more pressure on each rail than five chows.
	# Check the whole table at once, including opponents' revealed hands.
	var occupied: Array[Rect2] = []
	for slot in range(0, 144, 2):
		occupied.append(footprint(layout.wall_pose(slot, 0)))
	var screen := Rect2(Vector2.ZERO, 2.0 * DESIGN_CENTER)
	for seat in range(4):
		var melds: Array = []
		for index in range(5):
			melds.append({"type": "kong", "tiles": [9, 9, 9, 9], "from": posmod(seat + index % 3 + 1, 4)})
		var group: Dictionary = layout.hand_group(2, true, melds) if seat == 0 else layout.side_group(seat, 2, melds, true)
		var poses: Array = group.hand.duplicate()
		for meld: Array in group.melds:
			poses.append_array(meld)
		for pose: Transform3D in poses:
			check(screen.encloses(screen_bounds(pose)), "five wide melds fit inside all four rails")
			var bounds := footprint(pose)
			for previous in occupied:
				check(not bounds.intersects(previous), "crowded revealed groups fit without colliding at the table corners")
			occupied.append(bounds)


func footprint(pose: Transform3D) -> Rect2:
	var bounds := Rect2(Vector2(pose.origin.x, pose.origin.z), Vector2.ZERO)
	for corner in corners(pose):
		bounds = bounds.expand(Vector2(corner.x, corner.z))
	return bounds


func screen_bounds(pose: Transform3D, face_only := false) -> Rect2:
	var vertices := corners(pose, face_only)
	var bounds := Rect2(project(vertices[0]), Vector2.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(project(vertex))
	return bounds


func corners(pose: Transform3D, face_only := false) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for y in ([1] if face_only else [-1, 1]):
		for x in [-1, 1]:
			for z in [-1, 1]:
				vertices.append(pose * (Vector3(x, y, z) * TILE_HALF))
	return vertices


func project(point: Vector3) -> Vector2:
	var axes := Basis.looking_at(CAMERA_TARGET - CAMERA)
	var local := axes.transposed() * (point - CAMERA)
	return DESIGN_CENTER + Vector2(local.x, -local.y) * (DESIGN_CENTER.y / -local.z / tan(deg_to_rad(CAMERA_FOV) * 0.5))
