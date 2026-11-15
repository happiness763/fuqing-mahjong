extends Control

const FRAME_SIZE := Vector2(164, 144)
const MIDPOINT := FRAME_SIZE * 0.5
const LABEL_SIZE := Vector2(32, 26)
const FACE_MARKERS := [Vector2(82, 116), Vector2(133, 72), Vector2(82, 29), Vector2(31, 72)]
const BORDER_COLORS := [Color("#719553"), Color("#aa6958"), Color("#ab9365"), Color("#557f8c")]
const INK := Color("#ded7b8")
const ACTIVE_INK := Color("#ebf3ca")

var winds: Array = []
var active_seat := -1
var clock: Label
var _labels: Array[Label] = []


func setup(font: Font) -> void:
	name = "CenterDial"
	size = FRAME_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for marker: Vector2 in FACE_MARKERS:
		var direction := _label(font, Rect2(marker - LABEL_SIZE * 0.5, LABEL_SIZE), 19, INK)
		_labels.append(direction)
	clock = _label(font, Rect2(MIDPOINT - Vector2(37, 25), Vector2(74, 50)), 33, Color("#97eafa"))
	clock.name = "CenterCountdown"
	clock.add_theme_color_override("font_shadow_color", Color("#163a47"))
	clock.add_theme_constant_override("shadow_offset_y", 2)


func set_seats(directions: Array, active: int) -> void:
	if directions == winds and active == active_seat:
		return
	winds = directions
	active_seat = active
	for seat in range(_labels.size()):
		_labels[seat].text = winds[seat]
		_labels[seat].add_theme_color_override("font_color", ACTIVE_INK if seat == active_seat else INK)
	queue_redraw()


func _label(font: Font, rect: Rect2, point_size: int, color: Color) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", point_size)
	node.add_theme_color_override("font_color", color)
	add_child(node)
	return node


func _draw() -> void:
	var frame := PackedVector2Array([
		Vector2(17, 0), Vector2(147, 0), Vector2(164, 17), Vector2(164, 127),
		Vector2(147, 144), Vector2(17, 144), Vector2(0, 127), Vector2(0, 17),
	])
	draw_set_transform(Vector2(0, 4))
	draw_colored_polygon(frame, Color(0.04, 0.11, 0.09, 0.74))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(frame, Color("#172c25"))
	draw_polyline(frame + PackedVector2Array([frame[0]]), Color("#b49662"), 1.0, true)

	var sectors := [
		PackedVector2Array([Vector2(23, 132), Vector2(141, 132), Vector2(111, 96), Vector2(53, 96)]),
		PackedVector2Array([Vector2(152, 21), Vector2(152, 123), Vector2(109, 93), Vector2(109, 51)]),
		PackedVector2Array([Vector2(23, 12), Vector2(141, 12), Vector2(111, 48), Vector2(53, 48)]),
		PackedVector2Array([Vector2(12, 21), Vector2(12, 123), Vector2(55, 93), Vector2(55, 51)]),
	]
	for seat in range(sectors.size()):
		var points: PackedVector2Array = sectors[seat]
		var active := seat == active_seat
		draw_colored_polygon(points, Color("#4a683b") if active else Color("#293b32"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color("#859d59") if active else Color("#415348"), 1.0, true)
		draw_line(points[0], points[1], Color("#c3db82") if active else BORDER_COLORS[seat], 3.0, true)
	draw_circle(MIDPOINT, 33.0, Color("#657365"), true, -1.0, true)
	draw_circle(MIDPOINT, 30.5, Color("#142823"), true, -1.0, true)
