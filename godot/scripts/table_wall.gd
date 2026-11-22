extends Control

const Art = preload("res://scripts/table_art.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const STACKS_PER_SIDE := 18
const SLOTS_PER_SIDE := STACKS_PER_SIDE * 2

# The near rim is wider and the top of each side runs inward toward it
# in perspective. Slot numbers keep their original physical draw order.
const NEAR_BASE := 611.0
const FAR_BASE := 137.0

var slots: Array = []
var sea_slots: Array = []
var dealer := 0
var back_index := 0


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
	var bounds := Rect2(top[0], Vector2.ZERO)
	for point in top:
		bounds = bounds.expand(point)
	return Rect2(bounds.position, bounds.size + Vector2(0, layer_height(slot, dealer_seat)))


static func face_quad(slot: int, dealer_seat: int) -> PackedVector2Array:
	var side := wall_side(slot, dealer_seat)
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var layer := layer_height(slot, dealer_seat)
	var lift := layer if slot % 2 == 0 else 0.0
	if side in [0, 2]:
		var band := 52.0 if side == 0 else 42.0
		var left := 640.0 - band * STACKS_PER_SIDE * 0.5
		var column := stack if side == 0 else STACKS_PER_SIDE - 1 - stack
		var x := left + band * column
		var end := (NEAR_BASE if side == 0 else FAR_BASE) - layer - lift
		var length := 38.0 if side == 0 else 29.0
		var shear := (640.0 - (x + band * 0.5)) * (0.029 if side == 0 else 0.023)
		return PackedVector2Array([Vector2(x + shear + 1, end - length),
			Vector2(x + band + shear - 1, end - length), Vector2(x + band - 1, end), Vector2(x + 1, end)])
	var row := stack if side == 3 else STACKS_PER_SIDE - 1 - stack
	var start := float(row) / STACKS_PER_SIDE
	var end := float(row + 1) / STACKS_PER_SIDE
	var a := side_edge(start, side)
	var b := side_edge(end, side)
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
	return 13.0 * slot_scale(slot, dealer_seat)


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
	ordered.sort_custom(func(a: int, b: int):
		# Stable painter's order from the far side of the table to the viewer.
		# The two layers of a stack share their depth; draw the bottom first.
		var y_a := slot_rect(a | 1, dealer).end.y
		var y_b := slot_rect(b | 1, dealer).end.y
		if is_equal_approx(y_a, y_b):
			return (a ^ 1) < (b ^ 1)
		return y_a < y_b)
	for slot in ordered:
		draw_tile(slot)


func draw_tile(slot: int) -> void:
	var face := face_quad(slot, dealer)
	var depth := Vector2(0, layer_height(slot, dealer))
	var front := PackedVector2Array([face[3], face[2], face[2] + depth, face[3] + depth])
	var side := wall_side(slot, dealer)
	var left_edge := side in [0, 2] and face[0].x > 640.0 or side == 3
	var edge_start := face[0] if left_edge else face[1]
	var edge_end := face[3] if left_edge else face[2]
	if slot % 2 == 1 or not slots.has(slot + 1):
		draw_colored_polygon(PackedVector2Array([front[0] + depth, front[1] + depth,
			front[1] + depth + Vector2(3, 5), front[0] + depth + Vector2(-2, 4)]),
			Color(0.025, 0.07, 0.045, 0.45))
	draw_colored_polygon(PackedVector2Array([edge_start, edge_end, edge_end + depth, edge_start + depth]),
		Color("#b1a482"))
	draw_polygon(front, PackedColorArray([Color("#e2d5b0"), Color("#e2d5b0"), Color("#9e906e"), Color("#9e906e")]))
	draw_colored_polygon(PackedVector2Array([front[0], front[1], front[1] + depth * 0.24, front[0] + depth * 0.24]),
		Color("#294b2b"))
	var bevel := Art.bevel_polygon(face, 2.5)
	var colors := PackedColorArray()
	for index in range(bevel.size()):
		colors.append(Color("#608247") if index < 4 else Color("#426632"))
	draw_polygon(bevel, colors)
	draw_polyline(Art.closed_polygon(bevel), Color("#34492a"), 1, true)
	draw_line(face[0].lerp(face[1], 0.09) + Vector2(0, 1), face[0].lerp(face[1], 0.91) + Vector2(0, 1),
		Color("#8eab6c"), 1.2, true)
	draw_line(front[0].lerp(front[3], 0.94), front[1].lerp(front[2], 0.94),
		Color("#796d4f"), 1.2, true)
	var center := (face[0] + face[1] + face[2] + face[3]) * 0.25
	var art_size := 18.0 * slot_scale(slot, dealer)
	Backs.draw_on(self, Rect2(center - Vector2.ONE * art_size * 0.5, Vector2.ONE * art_size),
		back_index, [0.0, -PI / 2.0, PI, PI / 2.0][side], Color(1, 0.95, 0.71, 0.82))
	if sea_slots.has(slot):
		draw_polyline(Art.closed_polygon(bevel), Color("#efd793"), 2, true)
