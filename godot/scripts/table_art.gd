extends Control

const DiceRoll = preload("res://scripts/dice_roll.gd")
const FRAME := Rect2(28, 16, 1224, 768)
const FELT := Rect2(41, 29, 1198, 742)
const CENTER := Vector2(640, 400)
const RIVERS := [
	Rect2(360, 486, 560, 126), Rect2(742, 250, 173, 300),
	Rect2(360, 205, 560, 109), Rect2(365, 250, 173, 300),
]
const BRASS := Color("#c49a61")
const DICE_RING_RADIUS := 62.0
const FAR_EDGE_INSET := 66.0

var dice := Vector2i.ZERO
var table_texture: Texture2D
var background_area := Rect2(0, 0, 1280, 800)
var ambience_enabled := true
var _ambience_time := 0.0
var _ambience_accum := 0.0
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
		_flecks.append(surface_point(Vector2(grain.randf_range(6, FELT.size.x - 6),
			grain.randf_range(6, FELT.size.y - 6)) / FELT.size))


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


func set_background_area(area: Rect2) -> void:
	background_area = area
	queue_redraw()


func set_ambience(enabled: bool) -> void:
	ambience_enabled = enabled
	queue_redraw()


func _process(delta: float) -> void:
	if ambience_enabled:
		_ambience_time += delta
		_ambience_accum += delta
		if _ambience_accum >= 0.08:
			_ambience_accum = 0.0
			queue_redraw()


func _draw() -> void:
	gradient(background_area, Color("#253a30"), Color("#10231d"))
	var shadow := table_polygon(Rect2(FRAME.position + Vector2(0, 7), FRAME.size).grow(3))
	draw_colored_polygon(shadow, Color("#0c1814"))
	draw_surface(FRAME, Color("#784830"), Color("#9d6946"), 2.0)
	draw_surface(FRAME.grow(-4), Color("#815137"), Color("#b18151"))
	draw_surface(FRAME.grow(-8), Color("#5b3829"), Color("#3e271e"), 2.0)
	draw_surface(FELT, Color("#23523f"), Color("#112c22"), 2.0)
	if table_texture:
		var image_size := table_texture.get_size()
		var scale := maxf(FELT.size.x / image_size.x, FELT.size.y / image_size.y)
		var crop_size := FELT.size / scale
		var uv_start := (image_size - crop_size) * 0.5 / image_size
		var uv_size := crop_size / image_size
		# Thin horizontal quads map the cropped cloth onto the tapered
		# surface without a diagonal seam across a large custom image.
		for strip in range(32):
			var top := float(strip) / 32.0
			var bottom := float(strip + 1) / 32.0
			var uv := PackedVector2Array([Vector2(0, top), Vector2(1, top),
				Vector2(1, bottom), Vector2(0, bottom)])
			var points := PackedVector2Array()
			var texture_uv := PackedVector2Array()
			for point in uv:
				points.append(surface_point(point))
				texture_uv.append(uv_start + point * uv_size)
			draw_polygon(points, PackedColorArray([Color(0.83, 0.83, 0.83)]),
				texture_uv, table_texture)
	else:
		for ring in range(9, 0, -1):
			var scale := ring / 9.0
			draw_circle(CENTER, 270 * scale, Color(0.18, 0.46, 0.32, 0.045), true, -1.0, true)
		for point in _flecks:
			draw_line(point, point + Vector2(2, -1), Color(0.81, 0.86, 0.68, 0.08), 1.0)
	if ambience_enabled:
		for index in range(16):
			var seed_x := float((index * 137) % 1180)
			var seed_y := float((index * 223) % 700)
			var drift := sin(_ambience_time * 0.32 + index * 1.7)
			var point := surface_point(Vector2(0.04 + seed_x / 1280.0,
				0.04 + fmod(seed_y + _ambience_time * (4.0 + index % 3), 700.0) / 780.0))
			point.x += drift * 9.0
			draw_circle(point, 1.2 + float(index % 3) * 0.5,
				Color(0.84, 0.92, 0.78, 0.035 + 0.025 * (0.5 + 0.5 * drift)))
	draw_polyline(closed_polygon(table_polygon(FELT.grow(-6))), Color("#638064"), 1.0, true)
	for corner in [surface_point(Vector2(0.014, 0.022)), surface_point(Vector2(0.986, 0.022)),
			surface_point(Vector2(0.014, 0.978)), surface_point(Vector2(0.986, 0.978))]:
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


func gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


static func table_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position + Vector2(FAR_EDGE_INSET, 0),
		Vector2(rect.end.x - FAR_EDGE_INSET, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])


static func surface_point(uv: Vector2) -> Vector2:
	var inset := FAR_EDGE_INSET * (1.0 - uv.y)
	return FELT.position + Vector2(inset + uv.x * (FELT.size.x - inset * 2.0), uv.y * FELT.size.y)


static func closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


func draw_surface(rect: Rect2, fill: Color, edge: Color, width := 1.0) -> void:
	var points := table_polygon(rect)
	draw_colored_polygon(points, fill)
	draw_polyline(closed_polygon(points), edge, width, true)
