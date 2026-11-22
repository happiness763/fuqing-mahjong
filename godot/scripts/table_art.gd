extends Control

const DiceRoll = preload("res://scripts/dice_roll.gd")
const WALNUT_TABLE = preload("res://assets/table/walnut_table.png")
const FRAME := Rect2(3, 3, 1274, 794)
const FELT := Rect2(14, 20, 1252, 760)
const CENTER := Vector2(640, 325)
const RIVERS := [
	Rect2(220, 403, 840, 139), Rect2(788, 249, 216, 189),
	Rect2(288, 175, 704, 73), Rect2(276, 249, 216, 189),
]
const BRASS := Color("#c49a61")
const DICE_RING_RADIUS := 62.0
const FAR_EDGE_INSET := 105.0

var dice := Vector2i.ZERO
var table_texture: Texture2D
var background_area := Rect2(0, 0, 1280, 800)
var ambience_enabled := true
var _ambience_time := 0.0
var _ambience_accum := 0.0
var _dice_roll: DiceRoll
var _dice_rolling := false
static var _capsules: Dictionary = {}


static func box(fill: Color, border: Color, radius := 8, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


static func capsule(dimensions: Vector2, fill: Color, metal: Color) -> StyleBoxTexture:
	var key := [dimensions, fill, metal]
	if _capsules.has(key):
		return _capsules[key]
	var padding := Vector2.ONE * 7.0
	var pixel_size := Vector2i(dimensions + padding * 2.0)
	var image := Image.create_empty(pixel_size.x, pixel_size.y, false, Image.FORMAT_RGBA8)
	var radius := dimensions.y * 0.5
	var straight := (dimensions.x - dimensions.y) * 0.5
	for y in range(pixel_size.y):
		for x in range(pixel_size.x):
			var point := Vector2(x + 0.5, y + 0.5) - Vector2(pixel_size) * 0.5
			var cross := Vector2(maxf(absf(point.x) - straight, 0), point.y)
			var distance := cross.length() - radius
			var t := clampf(0.5 + point.y / dimensions.y, 0, 1)
			var shade := 0.13 * exp(-pow((t - 0.19) * 5.2, 2.0))
			var surface := fill.darkened(t * 0.23).lightened(shade)
			var foil := metal.darkened(0.45 * t).lightened(0.20 * (1.0 - t))
			var rim := 1.0 - smoothstep(2.0, 2.9, -distance)
			var lip := exp(-pow((distance + 3.3) * 1.2, 2.0)) * lerpf(0.28, 0.05, t)
			var alpha := 1.0 - smoothstep(-0.5, 0.6, distance)
			var shadow_distance := (cross - Vector2(0, 3.6)).length() - radius
			var shadow := 0.61 * (1.0 - smoothstep(-1.0, 5.3, shadow_distance))
			var ink := Color(0.017, 0.036, 0.023, shadow)
			var color := surface.lightened(lip).lerp(foil, rim)
			image.set_pixel(x, y, ink.blend(Color(color, alpha)))
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_expand_margin(side, 7.0)
	_capsules[key] = style
	return style


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_roll = DiceRoll.new()
	_dice_roll.position = CENTER - DiceRoll.DISPLAY_SIZE * 0.5
	add_child(_dice_roll)
	_dice_roll.set_faces(dice)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


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
	if not table_texture:
		draw_texture_rect(WALNUT_TABLE, Rect2(0, 0, 1280, 800), false)
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
	if table_texture:
		draw_frame()

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


func draw_frame() -> void:
	var far_left := Vector2(FELT.position.x + FAR_EDGE_INSET, FELT.position.y)
	var near_left := FELT.position + Vector2(0, FELT.size.y)
	for direction in [1, -1]:
		var origin := Vector2.ZERO if direction == 1 else Vector2(1280, 0)
		draw_set_transform(origin, 0, Vector2(direction, 1))
		draw_polygon(PackedVector2Array([Vector2.ZERO, far_left, near_left, Vector2(0, 780)]),
			PackedColorArray([Color("#40271c"), Color("#6e4127"), Color("#8a5836"), Color("#29170f")]))
		for index in range(14):
			var weight := float(index) / 13.0
			var color := Color("#462719").lerp(Color("#b17045"), sin(weight * PI))
			draw_line(far_left - Vector2(1 + index, 0), near_left - Vector2(1 + index, 0), color, 1.3, true)
		draw_line(far_left, near_left, Color("#d0a26a"), 1.4, true)
	draw_set_transform(Vector2.ZERO)
	for band in range(20):
		var shade := sin(float(band) / 19.0 * PI)
		var color := Color("#3a2015").lerp(Color("#a66b47"), shade)
		draw_line(Vector2(8, band), Vector2(1272, band), color, 1.4)
		draw_line(Vector2(8, 799 - band), Vector2(1272, 799 - band), color, 1.4)
	draw_line(Vector2(14, 780), Vector2(1266, 780), Color("#d5a970"), 2, true)
	draw_line(Vector2(14, 19), Vector2(1266, 19), Color("#d5a970"), 1.4, true)
	var rim := box(Color.TRANSPARENT, Color("#4c2b1c"), 25, 4)
	draw_style_box(rim, FRAME)
