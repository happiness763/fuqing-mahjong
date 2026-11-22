extends Control

const Backs = preload("res://scripts/tile_backs.gd")
const STACKS_PER_SIDE := 18
const SLOTS_PER_SIDE := STACKS_PER_SIDE * 2

# The near rim is wider and the top of each side runs inward toward it
# in perspective. Slot numbers keep their original physical draw order.
const NEAR_BASE := 615.0
const FAR_BASE := 137.0

var slots: Array = []
var sea_slots: Array = []
var dealer := 0
var back_index := 0
static var _shadow: Texture2D


func set_back(index: int) -> void:
	if back_index != index:
		back_index = index
		queue_redraw()


func set_slots(values: Array, dealer_seat: int) -> void:
	if slots == values and dealer == dealer_seat:
		return
	slots = values
	dealer = dealer_seat
	queue_redraw()


func set_sea_slots(values: Array) -> void:
	if sea_slots == values:
		return
	sea_slots = values
	queue_redraw()


static func slot_rect(slot: int, dealer_seat: int) -> Rect2:
	var top := face_quad(slot, dealer_seat)
	var extrusion := layer_extrusion(slot, dealer_seat)
	var bounds := Rect2(top[0], Vector2.ZERO)
	for point in top:
		bounds = bounds.expand(point).expand(point + extrusion)
	return bounds


static func face_quad(slot: int, dealer_seat: int) -> PackedVector2Array:
	var side := wall_side(slot, dealer_seat)
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var layer := layer_height(slot, dealer_seat)
	var lift := layer if slot % 2 == 0 else 0.0
	var top_x := -layer_extrusion(slot, dealer_seat).x * (2 if slot % 2 == 0 else 1)
	if side in [0, 2]:
		var band := 52.0 if side == 0 else 42.0
		var left := 640.0 - band * STACKS_PER_SIDE * 0.5
		var column := stack if side == 0 else STACKS_PER_SIDE - 1 - stack
		var ground_x := left + band * column
		var x := ground_x + top_x
		var end := (NEAR_BASE if side == 0 else FAR_BASE) - layer - lift
		var length := 36.0 if side == 0 else 29.0
		var shear := (640.0 - (ground_x + band * 0.5)) * (0.029 if side == 0 else 0.023)
		return PackedVector2Array([Vector2(x + shear + 1, end - length),
			Vector2(x + band + shear - 1, end - length), Vector2(x + band - 1, end), Vector2(x + 1, end)])
	var row := stack if side == 3 else STACKS_PER_SIDE - 1 - stack
	var start := float(row) / STACKS_PER_SIDE
	var end := float(row + 1) / STACKS_PER_SIDE
	var a := side_edge(start, side)
	var b := side_edge(end, side)
	a.x += top_x
	b.x += top_x
	var width_a := lerpf(43.0, 62.0, start)
	var width_b := lerpf(43.0, 62.0, end)
	return PackedVector2Array([
		Vector2(a.x - width_a * 0.5, a.y - layer - lift + 1),
		Vector2(a.x + width_a * 0.5, a.y - layer - lift + 1),
		Vector2(b.x + width_b * 0.5, b.y - layer - lift - 1),
		Vector2(b.x - width_b * 0.5, b.y - layer - lift - 1)])


static func side_edge(depth: float, side: int) -> Vector2:
	var t := depth * (0.74 + 0.26 * depth)
	var x := lerpf(200.0, 107.0, t)
	return Vector2(x if side == 3 else 1280.0 - x, lerpf(144.0, 553.0, t))


static func layer_height(slot: int, dealer_seat: int) -> float:
	var height := 13.0 if wall_side(slot, dealer_seat) == 2 else 15.3
	return height * slot_scale(slot, dealer_seat)


static func layer_extrusion(slot: int, dealer_seat: int) -> Vector2:
	# Vertical edges converge below the camera. This exposes the ivory
	# inside face of both long side walls, including their middle stacks.
	var side := wall_side(slot, dealer_seat)
	var along := (float((slot % SLOTS_PER_SIDE) >> 1) + 0.5) / STACKS_PER_SIDE
	var displacement: float
	if side == 0:
		displacement = (0.5 - along) * 936.0
	elif side == 2:
		displacement = (along - 0.5) * 756.0
	else:
		displacement = 640.0 - side_edge(along if side == 3 else 1.0 - along, side).x
	return Vector2(displacement * 0.013, layer_height(slot, dealer_seat))


static func slot_scale(slot: int, dealer_seat: int) -> float:
	var side := wall_side(slot, dealer_seat)
	if side % 2 == 0:
		return 1.15 if side == 0 else 0.89
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var depth := float(stack) / (STACKS_PER_SIDE - 1)
	if side == 1:
		depth = 1.0 - depth
	return lerpf(0.84, 1.16, depth)


static func wall_side(slot: int, dealer_seat: int) -> int:
	return posmod(floori(float(slot) / SLOTS_PER_SIDE) + dealer_seat, 4)


static func opening_slots(wall: Dictionary, dealt: int, gold_visible: bool, replacements: int) -> Array:
	var values := range(int(wall.size))
	for event in wall.opening:
		match event.kind:
			"deal":
				if dealt > 0:
					values.erase(event.slot)
				dealt -= 1
			"gold":
				if gold_visible:
					values.erase(event.slot)
			_:
				if replacements > 0:
					values.erase(event.slot)
				replacements -= 1
	return values


func _draw() -> void:
	var ordered := slots.duplicate()
	var depths := {}
	for slot in ordered:
		depths[slot] = slot_rect(int(slot) | 1, dealer).end.y
	if _shadow == null:
		_shadow = make_shadow()
	for slot in ordered:
		if slot % 2 == 1:
			var foot := slot_rect(slot, dealer)
			draw_texture_rect(_shadow, Rect2(foot.position + Vector2(-7, foot.size.y * 0.40),
				Vector2(foot.size.x + 18, foot.size.y * 0.64 + 13)), false)
	ordered.sort_custom(func(a: int, b: int):
		# Stable painter's order from the far side of the table to the viewer.
		# The two layers of a stack share their depth; draw the bottom first.
		var y_a: float = depths[a]
		var y_b: float = depths[b]
		if is_equal_approx(y_a, y_b):
			return (a ^ 1) < (b ^ 1)
		return y_a < y_b)
	for slot in ordered:
		draw_tile(slot)


func draw_tile(slot: int) -> void:
	var face := face_quad(slot, dealer)
	var depth := layer_extrusion(slot, dealer)
	var side := wall_side(slot, dealer)
	var outline := rounded_face(face, 4.4 * slot_scale(slot, dealer))
	var center := (face[0] + face[1] + face[2] + face[3]) * 0.25
	# The body follows the projected vertical axis. Only the edges that face
	# the camera expose their ivory side, including the inner faces of side walls.
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var normal := Vector2(b.y - a.y, a.x - b.x).normalized()
		# Edges parallel to the projection have no visible side. Reject
		# subpixel slivers before the renderer attempts to triangulate them.
		if normal.dot(depth) <= 0.24:
			continue
		var key := 0.64 + 0.36 * maxf(0, normal.dot(Vector2(-0.5, 0.87)))
		var ivory := Color("#ece0bc") * Color(key, key, key)
		draw_polygon(PackedVector2Array([a, b, b + depth, a + depth]), PackedColorArray([
			ivory.darkened(0.14), ivory.darkened(0.14), ivory.darkened(0.33), ivory.darkened(0.33)]))
		draw_polygon(PackedVector2Array([a + depth * 0.24, b + depth * 0.24,
			b + depth * 0.78, a + depth * 0.78]), PackedColorArray([ivory, ivory,
			ivory.darkened(0.19), ivory.darkened(0.19)]))
		draw_polygon(PackedVector2Array([a, b, b + depth * 0.23, a + depth * 0.23]),
			PackedColorArray([Color("#52753f"), Color("#52753f"), Color("#29492d"), Color("#29492d")]))
		draw_line(a + depth * 0.27, b + depth * 0.27, ivory.lightened(0.2), 1.0, true)
	var top := PackedVector2Array()
	var colors := PackedColorArray()
	for point in outline:
		top.append(point.move_toward(center, 1.9))
		var light := clampf(0.55 - (point.y - center.y) * 0.022 - (point.x - center.x) * 0.007, 0, 1)
		colors.append(Color("#466735").lerp(Color("#749259"), light))
	draw_colored_polygon(outline, Color("#8da56a"))
	draw_polygon(top, colors)
	draw_polyline(closed(outline), Color("#405634"), 0.75, true)
	var art_size := 18.0 * slot_scale(slot, dealer)
	Backs.draw_on(self, Rect2(center - Vector2.ONE * art_size * 0.5, Vector2.ONE * art_size),
		back_index, [0.0, -PI / 2.0, PI, PI / 2.0][side], Color(0.95, 0.93, 0.73, 0.77))
	if sea_slots.has(slot):
		draw_polyline(closed(outline), Color("#efd793"), 2, true)


static func rounded_face(quad: PackedVector2Array, radius: float) -> PackedVector2Array:
	var rounded := PackedVector2Array()
	for i in range(quad.size()):
		var corner := quad[i]
		var start := corner.move_toward(quad[posmod(i - 1, quad.size())], radius)
		var end := corner.move_toward(quad[(i + 1) % quad.size()], radius)
		for j in range(4):
			var t := float(j) / 3.0
			rounded.append(start.lerp(corner, t).lerp(corner.lerp(end, t), t))
	return rounded


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var outline := points.duplicate()
	outline.append(points[0])
	return outline


static func make_shadow() -> ImageTexture:
	var image := Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	for y in range(48):
		for x in range(64):
			var delta := (Vector2(x, y) + Vector2.ONE * 0.5) / Vector2(32, 24) - Vector2.ONE
			var distance := Vector2(maxf(absf(delta.x) - 0.34, 0) / 0.66, delta.y).length()
			image.set_pixel(x, y, Color(0.018, 0.04, 0.024, (1.0 - smoothstep(0.13, 0.98, distance)) * 0.34))
	return ImageTexture.create_from_image(image)
