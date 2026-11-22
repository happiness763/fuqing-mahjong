extends Control

const DIAL_SURFACE = preload("res://assets/effects/compass_dial.gdshader")
const FRAME_SIZE := Vector2(174, 152)
const MIDPOINT := FRAME_SIZE * 0.5
const TAB_CENTERS := [Vector2(87, 123), Vector2(146, 71), Vector2(87, 25), Vector2(28, 71)]
const TAB_SIZE := Vector2(34, 30)
const SCORE_SIZE := Vector2(58, 20)
const SCORE_CENTERS := [Vector2(87, 108), Vector2(147, 91), Vector2(87, 43), Vector2(27, 91)]
const INK := Color("#e9c47a")
const ACTIVE_INK := Color("#fff0c9")
const CYAN := Color("#72f4ed")

var winds: Array = []
var active_seat := -1
var dealer := -1
var scores: Array = []
var clock: Label
var fallback: Label
var round_label: Label
var _labels: Array[Label] = []
var _score_labels: Array[Label] = []
var _time := 0.0
var wind_font: Font
var number_font: FontVariation
var surface_material: ShaderMaterial


func setup(font: Font, score_font: Font = null) -> void:
	name = "CenterDial"
	wind_font = font
	size = FRAME_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	var surface := ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = true
	surface.size = Vector2(192, 174)
	surface.position = MIDPOINT - surface.size * 0.5
	surface_material = ShaderMaterial.new()
	surface_material.shader = DIAL_SURFACE
	surface.material = surface_material
	add_child(surface)
	number_font = FontVariation.new()
	number_font.base_font = score_font if score_font != null else font
	number_font.variation_embolden = 0.8
	var text_font: Font = number_font
	for seat in range(TAB_CENTERS.size()):
		var center: Vector2 = TAB_CENTERS[seat]
		var direction := _label(font, Rect2(center - TAB_SIZE * 0.5, TAB_SIZE), 24, INK)
		direction.pivot_offset = TAB_SIZE * 0.5
		direction.hide()
		_labels.append(direction)
	for seat in range(SCORE_CENTERS.size()):
		var center: Vector2 = SCORE_CENTERS[seat]
		var score := _label(text_font, Rect2(center - SCORE_SIZE * 0.5, SCORE_SIZE), 20, INK)
		score.add_theme_color_override("font_outline_color", Color("#101820"))
		score.add_theme_constant_override("outline_size", 3)
		score.pivot_offset = score.size * 0.5
		score.modulate.a = 0.0
		_score_labels.append(score)
	round_label = _label(font, Rect2(51, 77, 72, 24), 11, CYAN)
	round_label.name = "DialRound"
	round_label.hide()
	clock = _label(text_font, Rect2(51, 54, 72, 36), 36, CYAN)
	clock.name = "CenterCountdown"
	clock.modulate.a = 0.0
	clock.add_theme_color_override("font_shadow_color", Color("#0c1c26"))
	clock.add_theme_constant_override("shadow_offset_y", 2)
	fallback = _label(text_font, Rect2(51, 60, 72, 22), 21, CYAN)
	fallback.name = "DialRemaining"
	fallback.modulate.a = 0.0
	set_countdown("")
	set_remaining("余 38")
	set_round("第 1 局")
	set_scores([0, 0, 0, 0])


func set_round(text: String) -> void:
	if is_instance_valid(round_label):
		round_label.text = text


func set_remaining(text: String) -> void:
	if is_instance_valid(fallback):
		fallback.text = text


func set_countdown(text: String) -> void:
	if not is_instance_valid(clock):
		return
	clock.text = text
	clock.visible = not text.is_empty()
	if is_instance_valid(fallback):
		fallback.visible = text.is_empty()
	queue_redraw()


func set_seats(directions: Array, active: int) -> void:
	if directions == winds and active == active_seat:
		return
	winds = directions
	active_seat = active
	var directions_on_screen := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	surface_material.set_shader_parameter("active_direction",
		directions_on_screen[active] if active in range(4) else Vector2.ZERO)
	for seat in range(_labels.size()):
		_labels[seat].text = winds[seat]
	_refresh_colors()
	queue_redraw()


func set_dealer(seat: int) -> void:
	if dealer == seat:
		return
	dealer = seat
	_refresh_colors()
	queue_redraw()


func _refresh_colors() -> void:
	for seat in range(_labels.size()):
		var color := CYAN if seat == active_seat else (ACTIVE_INK if seat == dealer else INK)
		_labels[seat].add_theme_color_override("font_color", color)


func set_scores(values: Array) -> void:
	if values == scores:
		return
	scores = values.duplicate()
	for seat in range(_score_labels.size()):
		var value: int = int(values[seat]) if seat < values.size() else 0
		_score_labels[seat].text = format_score(value)
		_score_labels[seat].add_theme_color_override("font_color",
			Color("#add3a0") if value > 0 else (Color("#ec9a83") if value < 0 else INK))
	queue_redraw()


static func format_score(value: int) -> String:
	if value > 0:
		return "+%d" % value
	if value < 0:
		return "-%d" % absi(value)
	return "0"


func _process(delta: float) -> void:
	if active_seat < 0:
		return
	_time += delta
	surface_material.set_shader_parameter("light_phase", 0.86 + 0.14 * sin(_time * 4.2))


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
	node.size = rect.size.max(node.get_combined_minimum_size())
	node.position = rect.get_center() - node.size * 0.5
	return node


func _draw() -> void:
	for seat in range(_score_labels.size()):
		var label := _score_labels[seat]
		_draw_number(label.text, SCORE_CENTERS[seat], 0, 11,
			Color("#a1c3ac") if label.text == "0" else label.get_theme_color("font_color"))
	if is_instance_valid(clock):
		_draw_number(clock.text if clock.visible else fallback.text, MIDPOINT - Vector2(0, 2), 0,
			36 if clock.visible else 23, CYAN)
	for seat in range(winds.size()):
		var ink := _labels[seat].get_theme_color("font_color")
		var text: String = winds[seat]
		var dimensions := wind_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23)
		var at: Vector2 = TAB_CENTERS[seat] + Vector2(-dimensions.x * 0.5,
			wind_font.get_ascent(23) - wind_font.get_height(23) * 0.5)
		draw_string(wind_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, ink)


func _draw_number(text: String, center: Vector2, angle: float, point_size: int, ink: Color) -> void:
	# Digits have no descenders. Center their visible cap height rather than the font line box.
	var width := number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	draw_set_transform(center, deg_to_rad(angle))
	draw_string(number_font, Vector2(-width * 0.5, point_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, ink)
	draw_set_transform(Vector2.ZERO)
