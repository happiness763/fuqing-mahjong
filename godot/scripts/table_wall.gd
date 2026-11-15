extends Control

const Art = preload("res://scripts/table_art.gd")
const STACKS_PER_SIDE := 18
const SLOTS_PER_SIDE := STACKS_PER_SIDE * 2
const STACK_DEPTH := 4

var slots: Array = []
var dealer := 0
var _lower := Art.box(Color("#50695c"), Color("#304b41"), 2)
var _upper := Art.box(Color("#849985"), Color("#536e5e"), 2)


func set_slots(values: Array, dealer_seat: int) -> void:
	if slots == values and dealer == dealer_seat:
		return
	slots = values
	dealer = dealer_seat
	queue_redraw()


static func slot_rect(slot: int, dealer_seat: int) -> Rect2:
	var side := posmod(floori(float(slot) / SLOTS_PER_SIDE) + dealer_seat, 4)
	var stack := floori(float(slot % SLOTS_PER_SIDE) / 2)
	var along := stack - (STACKS_PER_SIDE - 1) * 0.5
	var center: Vector2 = Art.CENTER
	var dimensions := Vector2(8.2, 22.0)
	match side:
		0:
			center += Vector2(8.8 * along, 85)
		1:
			center += Vector2(84, -7.8 * along)
			dimensions = Vector2(21.0, 7.0)
		2:
			center += Vector2(-8.8 * along, -91)
		3:
			center += Vector2(-84, 7.8 * along)
			dimensions = Vector2(21.0, 7.0)
	if slot % 2 == 0:
		if side in [1, 3]:
			center.x += -STACK_DEPTH if side == 1 else STACK_DEPTH
		else:
			center.y -= STACK_DEPTH
	return Rect2(center - dimensions * 0.5, dimensions)


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
			draw_style_box(_lower if layer == 1 else _upper, rect)
			if layer == 0:
				draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2),
					Color("#9aaa92"), 1.0)
