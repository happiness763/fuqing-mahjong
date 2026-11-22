extends Control

const Art = preload("res://scripts/table_art.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const STACKS_PER_SIDE := 18
const SLOTS_PER_SIDE := STACKS_PER_SIDE * 2

# Near, right, far, left. The step follows the original physical draw order.
const WALL_CENTERS := [Vector2(640, 650), Vector2(960, 398), Vector2(640, 183), Vector2(320, 398)]
const STACK_STEPS := [Vector2(28.5, 0), Vector2(-2, -21), Vector2(-25.1, 0), Vector2(-2, 21)]
const TILE_SIZES := [Vector2(26.5, 43), Vector2(34, 20.3), Vector2(24, 38), Vector2(34, 20.3)]
const BODY_EDGES := [Vector2(0, 7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)]
const STACK_OFFSETS := [Vector2(0, -9), Vector2(-9, 0), Vector2(0, -9), Vector2(9, 0)]

var slots: Array = []
var sea_slots: Array = []
var dealer := 0
var back_index := 0


func set_back(index: int) -> void:
	if back_index != index:
		back_index = index
		queue_redraw()
var _bodies := [Art.box(Color("#e8d9bb"), Color("#766a4b"), 3),
	Art.box(Color("#c8b891"), Color("#655840"), 3)]
var _backs := [Art.box(Color("#609267"), Color("#28593f"), 3),
	Art.box(Color("#497655"), Color("#254d36"), 3)]


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
	var side := wall_side(slot, dealer_seat)
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var along := stack - (STACKS_PER_SIDE - 1) * 0.5
	var center: Vector2 = WALL_CENTERS[side] + STACK_STEPS[side] * along
	var depth_scale := slot_scale(slot, dealer_seat)
	if slot % 2 == 0:
		center += STACK_OFFSETS[side] * depth_scale
	var dimensions: Vector2 = TILE_SIZES[side] * depth_scale
	return Rect2(center - dimensions * 0.5, dimensions)


static func slot_scale(slot: int, dealer_seat: int) -> float:
	var side := wall_side(slot, dealer_seat)
	if side % 2 == 0:
		return 1.0
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var depth := float(stack) / (STACKS_PER_SIDE - 1)
	if side == 1:
		depth = 1.0 - depth
	return lerpf(0.94, 1.03, depth)


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
	ordered.sort()
	# Draw the lower tile first so a half-stack keeps its original height.
	for layer in [1, 0]:
		for slot in ordered:
			if int(slot) % 2 != layer:
				continue
			var rect := slot_rect(int(slot), dealer)
			var edge: Vector2 = BODY_EDGES[wall_side(int(slot), dealer)] * slot_scale(int(slot), dealer)
			var back := Rect2(rect.position - edge.min(Vector2.ZERO), rect.size - edge.abs())
			draw_style_box(_bodies[layer], rect)
			draw_style_box(_backs[layer], back)
			var angle: float = [0.0, -PI / 2.0, PI, PI / 2.0][wall_side(int(slot), dealer)]
			Backs.draw_on(self, back.grow(-1), back_index, angle)
			draw_line(back.position + Vector2(3, 2), Vector2(back.end.x - 3, back.position.y + 2),
				Color(0.82, 0.91, 0.71, 0.34), 1.0, true)
			if sea_slots.has(slot):
				# Mark the physical layer while drawing it: an upper tile must
				# occlude the hidden part of the lower reserve outline too.
				draw_style_box(Art.box(Color.TRANSPARENT, Color("#efd793"), 4, 2), rect.grow(2))
