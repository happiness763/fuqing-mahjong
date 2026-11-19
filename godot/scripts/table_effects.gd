extends Control

const Art = preload("res://scripts/table_art.gd")
const BigWinEffect = preload("res://scripts/big_win_effect.gd")

const STYLES := {
	"dragon": {"color": Color("#f4c85f"), "accent": Color("#b64736"), "tier": "top", "motif": "dragon", "sound": "win_heaven"},
	"heaven": {"color": Color("#fff2cd"), "accent": Color("#e7bf72"), "tier": "top", "motif": "heaven", "sound": "win_heaven"},
	"pure": {"color": Color("#93d8bb"), "accent": Color("#2d6f5a"), "tier": "big", "motif": "ribbon", "sound": "win_jade"},
	"dandiao": {"color": Color("#f4f0e2"), "accent": Color("#c9a15a"), "tier": "big", "motif": "spotlight", "sound": "win"},
	"sparrow": {"color": Color("#f6d88a"), "accent": Color("#b8863a"), "tier": "big", "motif": "feathers", "sound": "win_gold"},
	"goldGap": {"color": Color("#f0cf7a"), "accent": Color("#5a8e70"), "tier": "mid", "motif": "bridge", "sound": "win_gold"},
	"three": {"color": Color("#f5c95d"), "accent": Color("#9b6a22"), "tier": "mid", "motif": "coins", "sound": "win_coin"},
	"grab": {"color": Color("#ffd77a"), "accent": Color("#c04535"), "tier": "mid", "motif": "streak", "sound": "win_coin"},
	"pengpeng": {"color": Color("#e07a63"), "accent": Color("#8f342a"), "tier": "mid", "motif": "seals", "sound": "win_stamp"},
	"idle": {"color": Color("#e8d29a"), "accent": Color("#9a7a3a"), "tier": "small", "motif": "coin", "sound": "win_coin"},
	"rob": {"color": Color("#e07a5f"), "accent": Color("#a93d30"), "tier": "mid", "motif": "impact", "sound": "win_stamp"},
	"self": {"color": Color("#f0e6c8"), "accent": Color("#c9a15a"), "tier": "small", "motif": "", "sound": "win"},
	"discard": {"color": Color("#e8dfcf"), "accent": Color("#aeb6a8"), "tier": "small", "motif": "", "sound": "win"},
}
const DURATIONS := {"top": 1.8, "big": 1.4, "mid": 1.2, "small": 0.9}
const PARTICLES := {"top": 120, "big": 80, "mid": 50, "small": 18}

var desk
var action_font: Font
var body_font: Font
var seat_positions: Array = []
var center := Vector2(640, 400)
var mode := "full"
var time := 0.0
var particles: Array = []
var rings: Array = []
var score_floats: Array = []
var active_seat := -1
var urgent := false
var entrance_start := -1.0
var win_active := false
var win_start := 0.0
var win_duration := 0.0
var win_text := ""
var win_style: Dictionary = {}
var win_tier := "small"
var win_winner := -1
var win_color := Color.WHITE
var win_accent := Color.WHITE
var win_rob := false
var win_source := Rect2()
var win_target := Rect2()
var win_tile_face: Texture2D
var big_win := BigWinEffect.new()
var big_win_active := false
var _rng := RandomNumberGenerator.new()


func setup(table, action: Font, body: Font, positions: Array, dial_center: Vector2) -> void:
	desk = table
	action_font = action
	body_font = body
	seat_positions = positions
	center = dial_center
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	_rng.randomize()
	set_process(true)


func set_mode(value: String) -> void:
	mode = value if value in ["full", "simple", "off"] else "full"
	if mode == "off":
		particles.clear()
		rings.clear()
		score_floats.clear()
		win_active = false
		active_seat = -1
		urgent = false
	queue_redraw()


func full() -> bool:
	return mode == "full"


func style_for(result: Dictionary) -> Dictionary:
	var kind := str(result.get("kind", ""))
	var method := str(result.get("method", kind))
	if STYLES.has(kind):
		return STYLES[kind]
	if STYLES.has(method):
		return STYLES[method]
	return STYLES.self


func winner_center(seat: int) -> Vector2:
	if seat < 0 or seat >= seat_positions.size():
		return center
	var width := 154.0 if seat in [0, 2] else 126.0
	return seat_positions[seat] + Vector2(width * 0.5, 20)


func play_win(view: Dictionary, source := Rect2(), target := Rect2()) -> void:
	if mode == "off":
		return
	var result: Dictionary = view.get("result", {})
	var winner := int(result.get("winner", -1))
	if winner < 0:
		return
	win_style = style_for(result)
	win_tier = str(win_style.get("tier", "small"))
	win_color = win_style.get("color", Color.WHITE)
	win_accent = win_style.get("accent", Color.WHITE)
	win_text = desk.result_caption(result)
	win_winner = winner
	win_source = source
	win_target = target
	var number := int(result.get("tile", -1))
	win_tile_face = desk.faces[number] if number >= 0 and number < desk.faces.size() else null
	win_rob = str(result.get("method", "")) == "rob"
	var pattern := str(result.get("kind", ""))
	var method := str(result.get("method", pattern))
	if pattern not in BigWinEffect.KINDS:
		pattern = method
	big_win_active = pattern in BigWinEffect.KINDS
	win_duration = BigWinEffect.DURATION if big_win_active else float(DURATIONS.get(win_tier, 0.9))
	if big_win_active:
		big_win.prepare(view, pattern, desk.GOLD_AREA)
	win_start = time
	win_active = true
	if full():
		var count := int(PARTICLES.get(win_tier, 20))
		if winner == 0:
			count = int(count * 1.2)
		_spawn(winner_center(winner), count, win_color, win_accent)
	var sound := str(win_style.get("sound", "win"))
	if desk.sounds.has(sound):
		desk.play_sound(sound)
	queue_redraw()


func stop_win() -> void:
	win_active = false
	queue_redraw()


func discard_landing(seat: int, point: Vector2) -> void:
	if mode == "off":
		return
	rings.append({"point": point, "start": time, "color": Color("#e7d39a")})
	if mode == "full":
		for index in range(4):
			var dir := Vector2.from_angle(_rng.randf_range(0, TAU))
			particles.append({"point": point, "velocity": dir * _rng.randf_range(20, 46) + Vector2(0, -12),
				"life": 0.35, "max": 0.35, "size": _rng.randf_range(1.0, 2.0),
				"color": Color(0.91, 0.84, 0.62, 0.55), "shape": 0})
	queue_redraw()


func score_delta(seat: int, delta: int) -> void:
	if mode == "off" or delta == 0:
		return
	score_floats.append({
		"point": seat_positions[seat] + Vector2((154.0 if seat in [0, 2] else 126.0) * 0.5, 68),
		"start": time,
		"text": desk.points(delta),
		"color": desk.score_color(delta),
	})
	queue_redraw()


func set_active(seat: int) -> void:
	if active_seat == seat:
		return
	active_seat = seat
	queue_redraw()


func set_urgent(value: bool) -> void:
	if urgent == value:
		return
	urgent = value
	queue_redraw()


func play_entrance() -> void:
	if mode == "off":
		return
	entrance_start = time
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	var active := false
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle.life = float(particle.life) - delta
		if particle.life <= 0.0:
			particles.remove_at(index)
			continue
		particle.point = particle.point + particle.velocity * delta
		particle.velocity = Vector2(float(particle.velocity.x) * 0.985,
			float(particle.velocity.y) + 130.0 * delta)
		active = true
	for index in range(rings.size() - 1, -1, -1):
		if time - float(rings[index].start) > 0.55:
			rings.remove_at(index)
		else:
			active = true
	for index in range(score_floats.size() - 1, -1, -1):
		if time - float(score_floats[index].start) > 1.0:
			score_floats.remove_at(index)
		else:
			active = true
	if win_active and time - win_start > win_duration + 0.25:
		win_active = false
		queue_redraw()
	if entrance_start >= 0.0 and time - entrance_start > 0.4:
		entrance_start = -1.0
	if active or win_active or urgent or entrance_start >= 0.0 or active_seat >= 0:
		queue_redraw()


func _spawn(at: Vector2, count: int, color: Color, accent: Color) -> void:
	for index in range(count):
		var angle := _rng.randf_range(-PI, 0.0) if index % 3 != 0 else _rng.randf_range(0, TAU)
		var speed := _rng.randf_range(40, 210)
		var shade := color.lerp(accent, _rng.randf_range(0.0, 0.55))
		particles.append({
			"point": at + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-10, 10)),
			"velocity": Vector2.from_angle(angle) * speed,
			"life": _rng.randf_range(0.55, 1.15),
			"max": 1.15,
			"size": _rng.randf_range(1.2, 3.2),
			"color": Color(shade.r, shade.g, shade.b, _rng.randf_range(0.55, 0.95)),
			"shape": _rng.randi_range(0, 1),
		})


func _draw() -> void:
	if entrance_start >= 0.0:
		var fade := clampf(1.0 - (time - entrance_start) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.04, fade))
	if mode != "off" and active_seat >= 0:
		_draw_active_ring()
	if mode != "off" and urgent:
		_draw_urgent()
	for ring in rings:
		var progress := clampf((time - float(ring.start)) / 0.55, 0.0, 1.0)
		var alpha := (1.0 - progress) * 0.6
		draw_arc(ring.point, 7.0 + progress * 30.0, 0.0, TAU, 28,
			Color(ring.color.r, ring.color.g, ring.color.b, alpha), 2.0, true)
	if win_active:
		_draw_win()
	for particle in particles:
		var alpha := clampf(float(particle.life) / float(particle.max), 0.0, 1.0)
		var color: Color = particle.color
		color.a *= alpha
		if int(particle.shape) == 0:
			draw_circle(particle.point, float(particle.size), color)
		else:
			draw_line(particle.point, particle.point + Vector2(2, -2), color, maxf(1.0, particle.size * 0.7), true)
	for entry in score_floats:
		var progress := clampf((time - float(entry.start)) / 1.0, 0.0, 1.0)
		var alpha := 1.0 - progress
		var color: Color = entry.color
		color.a = alpha
		draw_string(body_font, Vector2(entry.point.x - progress * 8.0, entry.point.y - progress * 24.0),
			str(entry.text), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 18, color)


func _draw_active_ring() -> void:
	var width := 154.0 if active_seat in [0, 2] else 126.0
	var rect := Rect2(seat_positions[active_seat], Vector2(width, 39)).grow(2)
	var pulse := 0.5 + 0.5 * sin(time * 3.2)
	var color := Color(GOLD_RING.r, GOLD_RING.g, GOLD_RING.b, 0.28 + 0.32 * pulse)
	draw_style_box(Art.box(Color.TRANSPARENT, color, 10, 2), rect)
	draw_style_box(Art.box(Color(GOLD_RING.r, GOLD_RING.g, GOLD_RING.b, 0.05 + 0.05 * pulse),
		Color.TRANSPARENT, 10, 0), rect.grow(3))


const GOLD_RING := Color("#f0cf7a")


func _draw_urgent() -> void:
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	draw_arc(center, 86.0, 0.0, TAU, 64,
		Color(1.0, 0.42, 0.30, 0.22 + 0.35 * pulse), 3.0, true)
	draw_arc(center, 91.0, 0.0, TAU, 64,
		Color(1.0, 0.55, 0.38, 0.10 + 0.18 * pulse), 1.5, true)


func _draw_win() -> void:
	var elapsed := time - win_start
	var fade_out := 1.0 - smoothstep(win_duration - 0.23, win_duration + 0.12, elapsed)
	var alpha := smoothstep(0.0, 0.11, elapsed) * fade_out
	if alpha <= 0.0:
		return
	var shine := Color("#ffdf8c")
	if not is_instance_valid(desk.modal):
		draw_rect(Art.FRAME, Color(0.02, 0.06, 0.05, (0.29 if full() else 0.18) * alpha))
		var pulse := smoothstep(0.08, 0.43, elapsed)
		if pulse < 1.0:
			draw_arc(center, lerpf(40.0, 145.0, pulse), 0, TAU, 54,
				Color(shine, (1.0 - pulse) * 0.85 * alpha), 3.0, true)
		_draw_winning_route(elapsed, alpha, shine)
	if big_win_active and not is_instance_valid(desk.modal):
		big_win.paint(self, center, desk.faces, win_color, elapsed, alpha, full(), win_target)
	if full() and win_rob and elapsed < 0.45:
		var impact := smoothstep(0.0, 0.45, elapsed)
		draw_arc(winner_center(win_winner), lerpf(19, 64, impact), 0, TAU, 32,
			Color(win_accent, alpha * (1.0 - impact)), 3.0, true)
	var landing := clampf(elapsed / 0.16, 0, 1)
	var rebound := sin(PI * smoothstep(0.16, 0.29, elapsed)) * 0.07
	var scale_value := lerpf(1.32, 1.0, 1.0 - pow(1.0 - landing, 3.0)) - rebound
	var font_size := 94 if win_tier in ["big", "top"] else 80
	font_size = mini(font_size, floori(570.0 / maxf(1.0, win_text.length())))
	var baseline := 135.0 if is_instance_valid(desk.modal) else center.y - 65.0
	var text_center := Vector2(center.x, baseline - 42.0 * pow(1.0 - landing, 2.0))
	draw_set_transform(text_center, 0.0, Vector2.ONE * scale_value)
	var width := 620.0
	var origin := Vector2(-width * 0.5, 0)
	draw_string_outline(action_font, origin + Vector2(1, 5), win_text,
		HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 15, Color(0.02, 0.05, 0.04, 0.9 * alpha))
	draw_string_outline(action_font, origin, win_text,
		HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 5, Color(win_accent, 0.94 * alpha))
	draw_string(action_font, origin, win_text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size,
		Color(win_color.lerp(shine, 0.34), alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_winning_route(elapsed: float, alpha: float, shine: Color) -> void:
	if not win_target.has_area():
		return
	var target := win_target.get_center()
	var impact_at := 0.10
	if win_source.has_area() and full():
		impact_at = 0.40
		var source := win_source.get_center()
		var bend := source.lerp(target, 0.5) + Vector2(0, -42)
		var progress := smoothstep(0.10, impact_at, elapsed)
		if progress < 1.0:
			draw_rect(win_source.grow(2), Color(shine, alpha * 0.88), false, 2.0)
			var head := source
			if progress > 0.0:
				var trail := PackedVector2Array()
				for index in range(15):
					var step := lerpf(maxf(0.0, progress - 0.4), progress, index / 14.0)
					trail.append(source.lerp(bend, step).lerp(bend.lerp(target, step), step))
				draw_polyline(trail, Color(shine, alpha * 0.32), 14, true)
				draw_polyline(trail, Color("#fff6cc", alpha), 4, true)
				head = trail[-1]
			var dimensions := win_source.size.lerp(win_target.size, progress)
			var card := Rect2(head - dimensions * 0.5, dimensions)
			draw_rect(card.grow(2), Color(shine, 0.72 * alpha))
			draw_rect(card, Color("#fff4d9", alpha))
			if win_tile_face:
				draw_texture_rect(win_tile_face, card.grow(-2), false, Color(1, 1, 1, alpha))
	if big_win_active and big_win.kind == "grab":
		impact_at = 1.17
	if elapsed < impact_at:
		return
	var pulse := clampf((elapsed - impact_at) / 0.38, 0.0, 1.0)
	var bounds := win_target.grow(4)
	draw_rect(bounds.grow(3), Color(shine, 0.21 * alpha), false, 5)
	draw_rect(bounds, Color("#fff0b5", alpha), false, 2.5)
	if pulse < 1.0:
		draw_arc(target, lerpf(win_target.size.length() * 0.5, win_target.size.length() * 0.5 + 29.0, pulse),
			0, TAU, 32, Color(shine, alpha * (1.0 - pulse)), 3.0, true)

