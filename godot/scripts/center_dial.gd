extends Control

const Art = preload("res://scripts/table_art.gd")

const PANEL = preload("res://assets/effects/center_panel.png")
const FRAME_SIZE := Vector2(184, 184)
const MIDPOINT := FRAME_SIZE * 0.5
const TAB_CENTERS := [Vector2(21, 163), Vector2(163, 163), Vector2(163, 21), Vector2(21, 21)]
const TAB_SIZE := Vector2(34, 30)
const WIND_ROTATIONS := [0, -90, 180, 90]
const SCORE_SIZE := Vector2(58, 20)
const SCORE_CENTERS := [Vector2(92, 136), Vector2(139, 92), Vector2(92, 44), Vector2(45, 92)]
const SCORE_ROTATIONS := [0, 90, 180, 270]
const INK := Color("#c9cedb")
const ACTIVE_INK := Color("#fff0c9")
const CYAN := Color("#7fe6d8")
const GOLD := Color("#e8c15a")

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


func setup(font: Font, score_font: Font = null) -> void:
	name = "CenterDial"
	wind_font = font
	size = FRAME_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	number_font = FontVariation.new()
	number_font.base_font = score_font if score_font != null else font
	number_font.variation_embolden = 0.8
	var text_font: Font = number_font
	for seat in range(TAB_CENTERS.size()):
		var center: Vector2 = TAB_CENTERS[seat]
		var direction := _label(font, Rect2(center - TAB_SIZE * 0.5, TAB_SIZE), 24, INK)
		direction.pivot_offset = TAB_SIZE * 0.5
		direction.rotation_degrees = WIND_ROTATIONS[seat]
		direction.hide()
		_labels.append(direction)
	for seat in range(SCORE_CENTERS.size()):
		var center: Vector2 = SCORE_CENTERS[seat]
		var score := _label(text_font, Rect2(center - SCORE_SIZE * 0.5, SCORE_SIZE), 20, INK)
		score.add_theme_color_override("font_outline_color", Color("#101820"))
		score.add_theme_constant_override("outline_size", 3)
		score.pivot_offset = score.size * 0.5
		score.rotation_degrees = SCORE_ROTATIONS[seat]
		score.modulate.a = 0.0
		_score_labels.append(score)
	round_label = _label(font, Rect2(65, 65, 54, 24), 12, CYAN)
	round_label.name = "DialRound"
	clock = _label(text_font, Rect2(65, 94, 54, 24), 20, CYAN)
	clock.name = "CenterCountdown"
	clock.modulate.a = 0.0
	clock.add_theme_color_override("font_shadow_color", Color("#0c1c26"))
	clock.add_theme_constant_override("shadow_offset_y", 2)
	fallback = _label(text_font, Rect2(65, 94, 54, 24), 13, CYAN)
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
		var color := Color("#2a2016") if seat == dealer else (ACTIVE_INK if seat == active_seat else INK)
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
	node.size = rect.size.max(node.get_combined_minimum_size())
	node.position = rect.get_center() - node.size * 0.5
	return node


func _draw() -> void:
	draw_texture_rect_region(PANEL, Rect2(Vector2.ZERO, FRAME_SIZE), Rect2(103, 109, 1051, 969))
	if dealer >= 0:
		var center: Vector2 = TAB_CENTERS[dealer]
		var tab := Rect2(center - Vector2(17, 14), Vector2(34, 28))
		draw_style_box(Art.box(Color("#e8c15a"), Color("#8a6a2a"), 6, 2), tab)
		draw_style_box(Art.box(Color(1.0, 0.93, 0.72, 0.18), Color.TRANSPARENT, 5, 0), tab.grow(-2))
	if active_seat >= 0:
		_draw_lamp(active_seat)
	for seat in range(_score_labels.size()):
		var label := _score_labels[seat]
		_draw_number(label.text, SCORE_CENTERS[seat], SCORE_ROTATIONS[seat], 18, label.get_theme_color("font_color"))
	if is_instance_valid(clock):
		_draw_number(clock.text if clock.visible else fallback.text, Vector2(92, 106), 0, 20, clock.get_theme_color("font_color"))
	for seat in range(winds.size()):
		var ink := Color("#2a2016") if seat == dealer else INK
		var text: String = winds[seat]
		var dimensions := wind_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_set_transform(TAB_CENTERS[seat], deg_to_rad(WIND_ROTATIONS[seat]))
		draw_string(wind_font, Vector2(-dimensions.x * 0.5, wind_font.get_ascent(22) - wind_font.get_height(22) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		draw_set_transform(Vector2.ZERO)


func _draw_lamp(seat: int) -> void:
	var centers := [Vector2(92, 155), Vector2(155, 92), Vector2(92, 29), Vector2(29, 92)]
	var angles := [0.0, 90.0, 180.0, 270.0]
	var center: Vector2 = centers[seat]
	var pulse := 0.82 + 0.18 * sin(_time * 4.2)
	draw_set_transform(center, deg_to_rad(angles[seat]), Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, -10), Vector2(34, -10), Vector2(24, 7), Vector2(-24, 7),
	]), Color(1.0, 0.78, 0.28, 0.14 * pulse))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, -7), Vector2(29, -7), Vector2(20, 5), Vector2(-20, 5),
	]), Color(1.0, 0.83, 0.38, 0.34 * pulse))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -4), Vector2(24, -4), Vector2(16, 3), Vector2(-16, 3),
	]), Color(GOLD, 0.95 * pulse))
	draw_set_transform(Vector2.ZERO)


func _draw_number(text: String, center: Vector2, angle: float, point_size: int, ink: Color) -> void:
	# Digits have no descenders. Center their visible cap height rather than the font line box.
	var width := number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	draw_set_transform(center, deg_to_rad(angle))
	draw_string(number_font, Vector2(-width * 0.5, point_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, ink)
	draw_set_transform(Vector2.ZERO)
