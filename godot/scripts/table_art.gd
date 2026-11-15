extends Control

const DiceRoll = preload("res://scripts/dice_roll.gd")
const FRAME := Rect2(28, 16, 1042, 768)
const FELT := Rect2(41, 29, 1016, 742)
const CENTER := Vector2(549, 400)
const RIVERS := [
	Rect2(307, 482, 484, 72), Rect2(641, 319, 174, 162),
	Rect2(307, 205, 484, 113), Rect2(283, 319, 174, 162),
]
const BRASS := Color("#c49a61")
const DICE_RING_RADIUS := 62.0

var dice := Vector2i.ZERO
var table_texture: Texture2D
var _flecks := PackedVector2Array()
var _dice_roll: DiceRoll
var _dice_rolling := false


static func box(fill: Color, border: Color, radius := 8, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_roll = DiceRoll.new()
	_dice_roll.position = CENTER - DiceRoll.DISPLAY_SIZE * 0.5
	add_child(_dice_roll)
	_dice_roll.set_faces(dice)
	var grain := RandomNumberGenerator.new()
	grain.seed = 811
	for index in range(3300):
		_flecks.append(FELT.position + Vector2(grain.randf_range(6, FELT.size.x - 6), grain.randf_range(6, FELT.size.y - 6)))


func set_dice(faces: Vector2i) -> void:
	if dice == faces and not _dice_rolling:
		return
	dice = faces
	_dice_rolling = false
	if is_instance_valid(_dice_roll):
		_dice_roll.set_faces(dice)


func animate_dice(faces: Vector2i, on_landed: Callable) -> void:
	_dice_rolling = true
	_dice_roll.roll_to(faces, func():
		dice = faces
		_dice_rolling = false
		if on_landed.is_valid():
			on_landed.call())


func cancel_dice_roll() -> void:
	set_dice(dice)


func set_table_texture(texture: Texture2D) -> void:
	table_texture = texture
	queue_redraw()


func _draw() -> void:
	gradient(Rect2(0, 0, 1280, 800), Color("#253a30"), Color("#10231d"))
	draw_style_box(box(Color("#0c1814"), Color("#0c1814"), 24), Rect2(FRAME.position + Vector2(0, 7), FRAME.size).grow(3))
	draw_style_box(box(Color("#784830"), Color("#9d6946"), 23, 2), FRAME)
	draw_style_box(box(Color("#815137"), Color("#b18151"), 20), FRAME.grow(-4))
	draw_style_box(box(Color("#5b3829"), Color("#3e271e"), 17, 2), FRAME.grow(-8))
	draw_style_box(box(Color("#23523f"), Color("#112c22"), 15, 2), FELT)
	if table_texture:
		var area := FELT.grow(-7)
		var image_size := table_texture.get_size()
		var scale := maxf(area.size.x / image_size.x, area.size.y / image_size.y)
		var crop_size := area.size / scale
		draw_texture_rect_region(table_texture, area, Rect2((image_size - crop_size) * 0.5, crop_size), Color(0.83, 0.83, 0.83))
	else:
		for ring in range(9, 0, -1):
			var scale := ring / 9.0
			draw_circle(CENTER, 270 * scale, Color(0.18, 0.46, 0.32, 0.045), true, -1.0, true)
		for point in _flecks:
			draw_line(point, point + Vector2(2, -1), Color(0.81, 0.86, 0.68, 0.08), 1.0)
	draw_style_box(box(Color.TRANSPARENT, Color("#638064"), 11), FELT.grow(-6))
	for corner in [Vector2(57, 45), Vector2(1041, 45), Vector2(57, 755), Vector2(1041, 755)]:
		var horizontal := -1.0 if corner.x > 500 else 1.0
		var vertical := -1.0 if corner.y > 400 else 1.0
		var points := PackedVector2Array()
		for offset in [Vector2(0, 31), Vector2(0, 0), Vector2(31, 0), Vector2(31, 6), Vector2(7, 6), Vector2(7, 23)]:
			points.append(corner + offset * Vector2(horizontal, vertical))
		draw_polyline(points, Color("#a38d5d"), 1.0, true)

	var center := CENTER
	draw_circle(center, DICE_RING_RADIUS, Color("#1d4938"), true, -1.0, true)
	draw_arc(center, DICE_RING_RADIUS, 0, TAU, 90, Color("#799067"), 1.0, true)
	draw_arc(center, DICE_RING_RADIUS - 7, 0, TAU, 90, Color("#58745a"), 1.0, true)
	for index in range(32):
		var angle := TAU * index / 32.0
		var vector := Vector2.from_angle(angle)
		var length := 6 if index % 8 == 0 else 2
		draw_line(center + vector * (DICE_RING_RADIUS - 3 - length),
			center + vector * (DICE_RING_RADIUS - 3), Color("#82906c"), 1.0, true)
	draw_style_box(box(Color("#102c23"), Color("#496451"), 10), Rect2(53, 690, 992, 90))
	draw_line(Vector2(62, 694), Vector2(1036, 694), Color("#314e3c"), 1.0)
	for panel in [Rect2(1083, 72, 169, 272), Rect2(1083, 360, 169, 188), Rect2(1083, 564, 169, 220)]:
		draw_style_box(box(Color("#1d3329"), Color("#4b624e"), 11), panel)


func gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
