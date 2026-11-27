extends RefCounted

const Wall = preload("res://scripts/table_wall.gd")

# Seat axes and track spacing are adapted from BestGuo2020/lianhuaguangdongmahjong,
# tableLayout.ts and wallLayout.ts, commit 1f1be0079f37a3a5b1a559c29366b23916e1735b (MIT).
const RIGHT := [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
const OUTWARD := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
const SEAT_ANGLES := [0.0, PI / 2.0, PI, -PI / 2.0]
const WIDTH := 0.72
const LENGTH := 0.96
const TILE_LIFT := 0.163

const WALL_DEPTH := [5.12, 8.50, 5.55, 8.50]
const WALL_PITCH := 0.735
const WALL_STOREY := 0.317
const TILE_THICKNESS := 1.42
const WALL_THICKNESS := TILE_THICKNESS

const RIVER_COLUMNS := 6
const RIVER_ROW_PITCH := LENGTH + 0.055
const RIVER_THICKNESS := TILE_THICKNESS
const MELD_THICKNESS := TILE_THICKNESS
# The camera looks over the thick near wall. Keep the last river face clear
# of the far edge of its top storey in screen space at the approved camera.
const NEAR_RIVER_WALL_CLEARANCE := 0.50
const FAR_RIVER_WALL_CLEARANCE := 0.28

const MELD_GAP := 0.18
const MELD_TILE_GAP := 0.035
const DRAW_GAP := 0.38
const LOCAL_HAND_SCALE := 1.22
const LOCAL_MELD_SCALE := 0.8
const SIDE_SCALE := 0.76


static func tile_pose(point: Vector3, yaw: float, tilt := 0.0, model_scale := 1.0, height_scale := 1.0) -> Transform3D:
	var dimensions := Vector3(model_scale, model_scale * height_scale, model_scale)
	var axes := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(dimensions)
	return Transform3D(axes, point)


static func wall_pose(slot: int, dealer: int) -> Transform3D:
	# Fuqing's four 18-stack segments rotate with the dealer. The draw order
	# is the existing table wall mapping, from each seat's left to its right.
	var seat := Wall.wall_side(slot, dealer)
	var stack := (slot % Wall.SLOTS_PER_SIDE) >> 1
	var middle := (Wall.STACKS_PER_SIDE - 1) * 0.5
	var point := _from_seat(seat, (stack - middle) * WALL_PITCH, WALL_DEPTH[seat])
	var storey := WALL_STOREY if slot % 2 == 0 else 0.0
	point.y = (TILE_LIFT + storey) * WALL_THICKNESS
	return tile_pose(point, SEAT_ANGLES[seat], PI, 1.0, WALL_THICKNESS)


static func river_pose(seat: int, index: int, count: int) -> Transform3D:
	var row := floori(float(index) / RIVER_COLUMNS)
	var rows := maxi(row + 1, ceili(float(count) / RIVER_COLUMNS))
	var depth := 2.96 if seat % 2 else 1.86
	var scale := minf(1.0, 3.65 / (rows * LENGTH))
	if seat == 0:
		var available := float(WALL_DEPTH[0]) - LENGTH * 0.5 - NEAR_RIVER_WALL_CLEARANCE - depth
		var far_edge := (rows - 1) * RIVER_ROW_PITCH + LENGTH * 0.5
		scale = minf(scale, available / far_edge)
	elif seat == 2:
		var available := float(WALL_DEPTH[2]) - LENGTH * 0.5 - FAR_RIVER_WALL_CLEARANCE - depth
		var far_edge := (rows - 1) * RIVER_ROW_PITCH + LENGTH * 0.5
		scale = minf(scale, available / far_edge)
	var column := index % RIVER_COLUMNS - (RIVER_COLUMNS - 1) * 0.5
	var point := _from_seat(seat, column * 0.75 * scale, depth + row * RIVER_ROW_PITCH * scale)
	point.y = TILE_LIFT * scale * RIVER_THICKNESS
	return tile_pose(point, SEAT_ANGLES[seat], 0.0, scale, RIVER_THICKNESS)


static func hand_group(count: int, separated: bool, melds: Array) -> Dictionary:
	var draw_gap := DRAW_GAP if separated and count > 1 else 0.0
	var pitch := 0.76 * LOCAL_HAND_SCALE
	var hand_span := count * pitch + draw_gap
	var meld_span := _meld_span(melds, 0) * LOCAL_MELD_SCALE
	var gap := 0.33 if count > 0 and meld_span > 0.0 else 0.0
	var span := hand_span + gap + meld_span
	var fit := 16.0 / maxf(16.0, span)
	var left := -span * fit * 0.5
	var hand: Array[Transform3D] = []
	for index in range(count):
		var offset := (index + 0.5) * pitch
		if index == count - 1:
			offset += draw_gap
		var point := Vector3(left + offset * fit, 0.505 * fit, 7.05)
		hand.append(tile_pose(point, 0.0, deg_to_rad(36.0), LOCAL_HAND_SCALE * fit))
	return {"hand": hand, "melds": _meld_poses(melds, 0, left + (hand_span + gap) * fit, 7.1, LOCAL_MELD_SCALE * fit)}


static func side_group(seat: int, count: int, melds: Array, revealed := false) -> Dictionary:
	var depth := 7.52 if seat == 2 else 10.10
	var hand_span := count * 0.74
	var meld_span := _meld_span(melds, seat)
	var gap := 0.4 / SIDE_SCALE if count > 0 and meld_span > 0.0 else 0.0
	var span := hand_span + gap + meld_span
	var available := 16.2 if seat == 2 else 12.8
	var scale := minf(SIDE_SCALE, available / maxf(available, span))
	var left := -span * scale * 0.5
	var hand: Array[Transform3D] = []
	for index in range(count):
		var point := _from_seat(seat, left + (index + 0.5) * 0.74 * scale, depth)
		var thickness := MELD_THICKNESS if revealed else 1.0
		point.y = (TILE_LIFT * thickness if revealed else LENGTH * 0.5 + 0.0134) * scale
		var tilt := 0.0 if revealed else PI / 2.0
		hand.append(tile_pose(point, SEAT_ANGLES[seat], tilt, scale, thickness))
	return {"hand": hand, "melds": _meld_poses(melds, seat, left + (hand_span + gap) * scale, depth, scale)}


static func meld_source_index(meld: Dictionary, seat: int) -> int:
	var tiles: Array = meld.tiles
	if tiles.is_empty() or meld.type == "concealedKong":
		return -1
	if meld.type == "chow":
		return tiles.find(meld.get("claimed", tiles[0]))
	var relative := posmod(int(meld.get("from", seat)) - seat, 4)
	if relative == 3:
		return 0
	if relative == 2:
		return 1
	return _meld_tile_count(meld) - 1


static func _from_seat(seat: int, lateral: float, outward: float) -> Vector3:
	return RIGHT[seat] * lateral + OUTWARD[seat] * outward


static func _meld_tile_count(meld: Dictionary) -> int:
	return 3 if meld.type == "addedKong" else meld.tiles.size()


static func _meld_span(melds: Array, seat: int) -> float:
	var span := maxf(0.0, melds.size() - 1) * MELD_GAP
	for meld: Dictionary in melds:
		span += _meld_tile_count(meld) * (WIDTH + MELD_TILE_GAP)
		if meld_source_index(meld, seat) >= 0:
			span += LENGTH - WIDTH
	return span


static func _meld_poses(melds: Array, seat: int, lateral: float, depth: float, scale: float) -> Array:
	# Advance along the seat-local meld track by the width of each tile. A
	# claimed tile advances by its long edge and meets the row's outer edge.
	var poses: Array = []
	for meld: Dictionary in melds:
		var group: Array[Transform3D] = []
		var source := meld_source_index(meld, seat)
		var count := _meld_tile_count(meld)
		for index in range(count):
			var sideways := index == source
			var pitch := ((LENGTH if sideways else WIDTH) + MELD_TILE_GAP) * scale
			var alignment := (LENGTH - WIDTH) * 0.5 * scale if sideways else 0.0
			var point := _from_seat(seat, lateral + pitch * 0.5, depth + alignment)
			point.y = TILE_LIFT * scale * MELD_THICKNESS
			var yaw: float = SEAT_ANGLES[seat] + (PI / 2.0 if sideways else 0.0)
			var tilt := PI if meld.tiles[index] < 0 else 0.0
			group.append(tile_pose(point, yaw, tilt, scale, MELD_THICKNESS))
			lateral += pitch
		if meld.type == "addedKong":
			group.append(group[source].translated(Vector3.UP * WALL_STOREY * scale * MELD_THICKNESS))
		poses.append(group)
		lateral += MELD_GAP * scale
	return poses
