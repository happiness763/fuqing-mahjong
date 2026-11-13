extends Control

const FRAME := Rect2(28, 16, 1042, 768)
const FELT := Rect2(41, 29, 1016, 742)
const CENTER := Vector2(549, 400)
const RIVERS := [
	Rect2(352, 505, 394, 101), Rect2(647, 330, 250, 132),
	Rect2(352, 150, 394, 101), Rect2(201, 330, 250, 132),
]
const BRASS := Color("#c49a61")
const DIE_PIPS := [
	[Vector2(0, 0)],
	[Vector2(-12, -12), Vector2(12, 12)],
	[Vector2(-12, -12), Vector2(0, 0), Vector2(12, 12)],
	[Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12)],
	[Vector2(-12, -12), Vector2(12, -12), Vector2(0, 0), Vector2(-12, 12), Vector2(12, 12)],
	[Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 0), Vector2(12, 0), Vector2(-12, 12), Vector2(12, 12)],
]

var dice := Vector2i.ZERO
var table_texture: Texture2D
var _flecks := PackedVector2Array()


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
	var grain := RandomNumberGenerator.new()
	grain.seed = 811
	for index in range(3300):
		_flecks.append(FELT.position + Vector2(grain.randf_range(6, FELT.size.x - 6), grain.randf_range(6, FELT.size.y - 6)))


func set_dice(faces: Vector2i) -> void:
	dice = faces
	queue_redraw()


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
	draw_circle(center, 82, Color("#1d4938"), true, -1.0, true)
	draw_arc(center, 82, 0, TAU, 100, Color("#799067"), 1.0, true)
	draw_arc(center, 73, 0, TAU, 100, Color("#58745a"), 1.0, true)
	for index in range(32):
		var angle := TAU * index / 32.0
		var vector := Vector2.from_angle(angle)
		var length := 8 if index % 8 == 0 else 3
		draw_line(center + vector * (78 - length), center + vector * 78, Color("#82906c"), 1.0, true)
	if dice.x > 0:
		draw_die(center + Vector2(-27, 2), -0.15, dice.x)
		draw_die(center + Vector2(28, -5), 0.18, dice.y)
	draw_style_box(box(Color("#102c23"), Color("#496451"), 10), Rect2(53, 690, 992, 90))
	draw_line(Vector2(62, 694), Vector2(1036, 694), Color("#314e3c"), 1.0)
	for panel in [Rect2(1083, 72, 169, 272), Rect2(1083, 360, 169, 188), Rect2(1083, 564, 169, 220)]:
		draw_style_box(box(Color("#1d3329"), Color("#4b624e"), 11), panel)


func draw_die(center: Vector2, tilt: float, face: int) -> void:
	draw_set_transform(center, tilt)
	var side := box(Color("#ac9879"), Color("#786b55"), 9)
	side.shadow_color = Color(0.02, 0.09, 0.06, 0.58)
	side.shadow_size = 6
	side.shadow_offset = Vector2(1, 4)
	draw_style_box(side, Rect2(-23, -18, 46, 46))
	draw_style_box(box(Color("#f7edda"), Color("#fff6e4"), 9), Rect2(-23, -23, 46, 46))
	draw_line(Vector2(-14, -20), Vector2(13, -20), Color("#fffcf1"), 1.0, true)
	var pip_color := Color("#a6352b") if face in [1, 4] else Color("#303c34")
	var radius := 6.5 if face == 1 else 3.8
	for pip in DIE_PIPS[face - 1]:
		draw_circle(pip + Vector2(0.5, 0.9), radius + 0.6, Color("#d5c5a9"), true, -1.0, true)
		draw_circle(pip, radius, pip_color, true, -1.0, true)
		draw_circle(pip + Vector2(0, -0.8), radius * 0.62, pip_color.lightened(0.15), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
