extends Control

const COOLDOWN_MS := 2000
const PROPS := {
	"egg": ["丢鸡蛋", Color("#fff0c9")],
	"flower": ["送鲜花", Color("#e58f9f")],
	"water": ["倒水桶", Color("#8bc6e0")],
	"bomb": ["丢炸弹", Color("#e7ad63")],
	"tomato": ["丢番茄", Color("#de6257")],
}

var desk
var menu: Panel
var selected := -1
var effects: Control
var next_send := 0
var portrait_rects := {}


func setup(table) -> void:
	desk = table
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 7
	set_process(false)
	effects = Control.new()
	effects.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(effects)


func reset() -> void:
	close()
	portrait_rects.clear()
	for child in effects.get_children():
		effects.remove_child(child)
		child.queue_free()


func can_send(target: int) -> bool:
	var view: Dictionary = desk.board_view()
	return target in range(1, 4) and portrait_rects.has(target) and not view.is_empty() \
		and view.phase != "result" and not is_instance_valid(desk.modal) and not desk.menu_open() \
		and not desk.intro_active() and not desk.online_reconnecting


func open(target: int) -> void:
	var previous := selected
	close()
	if previous == target or not can_send(target):
		return
	selected = target
	var anchor: Rect2 = portrait_rects[target]
	var width := 357
	var y := anchor.end.y + 10 if anchor.end.y + 81 < 640 else anchor.position.y - 81
	var x := clampf(anchor.get_center().x - width * 0.5, 36, 1048 - width)
	menu = desk.panel(self, Rect2(x, y, width, 71), Color("#21382e"), Color("#b8945a"), 12)
	menu.mouse_filter = MOUSE_FILTER_STOP
	for id: String in PROPS:
		var offset := 6 + menu.get_child_count() * 69
		var button: Button = desk.button(menu, "", Rect2(offset, 6, 64, 59), send.bind(target, id))
		button.tooltip_text = PROPS[id][0]
		button.disabled = Time.get_ticks_msec() < next_send
		var prop := Prop.new()
		prop.kind = id
		prop.position = Vector2(32, 21)
		prop.scale = Vector2.ONE * 0.72
		prop.mouse_filter = MOUSE_FILTER_IGNORE
		button.add_child(prop)
		desk.label(button, PROPS[id][0], Rect2(0, 35, 64, 19), 12, Color("#f3e5cb"), HORIZONTAL_ALIGNMENT_CENTER)
	set_process(Time.get_ticks_msec() < next_send)


func close() -> void:
	set_process(false)
	if is_instance_valid(menu):
		remove_child(menu)
		menu.queue_free()
		menu = null
	selected = -1


func _process(_delta: float) -> void:
	if is_instance_valid(menu) and Time.get_ticks_msec() >= next_send:
		for button: Button in menu.get_children():
			button.disabled = false
		set_process(false)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(menu):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var point: Vector2 = event.position
		if not menu.get_global_rect().has_point(point) and not portrait_rects.get(selected, Rect2()).has_point(point):
			close()


func send(target: int, kind: String) -> void:
	close()
	var now := Time.get_ticks_msec()
	if now < next_send or not can_send(target) or not PROPS.has(kind):
		return
	next_send = now + COOLDOWN_MS
	if desk.online_view.is_empty():
		play(0, target, kind)
	else:
		desk.room.request("interaction", {"target": posmod(desk.room.state.my_seat + target, 4), "kind": kind})


func play(source: int, target: int, kind: String) -> void:
	if not desk.preferences.values.interaction_effects or not PROPS.has(kind) \
			or not portrait_rects.has(source) or not portrait_rects.has(target):
		return
	var prop := Prop.new()
	prop.kind = kind
	prop.mouse_filter = MOUSE_FILTER_IGNORE
	prop.scale = Vector2.ONE * 0.95
	effects.add_child(prop)
	var start: Vector2 = portrait_rects[source].get_center()
	prop.position = start
	var end: Vector2 = portrait_rects[target].get_center()
	var center := Vector2(548, 382)
	end += Vector2(8, -24) if kind == "water" else (center - end).normalized() * 37.0
	var curve := create_tween().bind_node(prop)
	curve.tween_method(func(progress: float):
		prop.position = start.lerp(end, progress) + Vector2(0, -50 * sin(PI * progress))
		prop.rotation = sin(PI * progress) * 0.30
		prop.queue_redraw(), 0.0, 1.0, 0.42)
	if kind == "bomb":
		curve.tween_method(func(progress: float):
			prop.position = end + Vector2(10 * progress, -14 * sin(PI * progress))
			prop.rotation = progress * 0.55, 0.0, 1.0, 0.18)
	curve.tween_callback(func():
		prop.rotation = 0.0
		desk.play_sound("interaction"))
	curve.tween_method(func(progress: float):
		prop.impact = progress
		prop.queue_redraw(), 0.0, 1.0, 0.56)
	curve.tween_callback(prop.queue_free)


class Prop extends Control:
	var kind := ""
	var impact := -1.0

	func _draw() -> void:
		if impact >= 0:
			if kind == "water":
				_draw_pour()
			else:
				_draw_impact()
			return
		var edge := Color("#202a24")
		match kind:
			"egg":
				var oval := PackedVector2Array()
				for index in range(30):
					var radial := Vector2.from_angle(TAU * index / 30)
					oval.append(Vector2(radial.x * (12 + radial.y * 2), radial.y * 17))
				draw_colored_polygon(oval, Color("#fbdfad"))
				draw_polyline(oval + PackedVector2Array([oval[0]]), Color("#9a6b44"), 1.4, true)
				draw_circle(Vector2(-4, -7), 3, Color("#fff0d0"), true, -1, true)
			"flower":
				for tip in [Vector2(-10, -8), Vector2(1, -14), Vector2(11, -7)]:
					draw_line(Vector2(0, 15), tip, Color("#54844f"), 3, true)
					for index in range(5):
						draw_circle(tip + Vector2.from_angle(TAU * index / 5) * 4, 3.5, Color("#e288a0"), true, -1, true)
					draw_circle(tip, 2.5, Color("#fff0ab"), true, -1, true)
				draw_colored_polygon(PackedVector2Array([Vector2(-10, 1), Vector2(0, 17), Vector2(9, 3)]), Color("#e6c48b"))
			"water":
				_draw_bucket(1.0)
			"bomb":
				draw_circle(Vector2(0, 3), 13, edge, true, -1, true)
				draw_circle(Vector2(-4, -1), 4, Color("#627063"), true, -1, true)
				draw_polyline(PackedVector2Array([Vector2(6, -8), Vector2(8, -15), Vector2(14, -15)]), Color("#c59958"), 2, true)
				draw_circle(Vector2(16, -15), 3.4, Color("#f1bd72"), true, -1, true)
			"tomato":
				draw_circle(Vector2(-4, 3), 11, Color("#c44b42"), true, -1, true)
				draw_circle(Vector2(5, 3), 11, Color("#d75b4a"), true, -1, true)
				draw_line(Vector2(-8, -7), Vector2(7, -9), Color("#6d8b54"), 4, true)
				draw_line(Vector2(0, -6), Vector2(2, -13), Color("#6d8b54"), 3, true)

	func _draw_bucket(alpha: float) -> void:
		draw_arc(Vector2(0, -7), 11, PI, TAU, 16, Color(0.89, 0.90, 0.83, alpha), 2, true)
		var rim := PackedVector2Array([Vector2(-15, -7), Vector2(15, -7), Vector2(10, 13), Vector2(-10, 13)])
		draw_colored_polygon(rim, Color(0.40, 0.57, 0.64, alpha))
		draw_line(rim[0], rim[1], Color(0.83, 0.91, 0.91, alpha), 3, true)
		draw_line(Vector2(-12, 1), Vector2(12, 1), Color(0.64, 0.83, 0.91, alpha), 2, true)

	func _draw_pour() -> void:
		draw_set_transform(Vector2.ZERO, -1.75 * smoothstep(0.0, 0.35, impact))
		_draw_bucket(1.0 - smoothstep(0.68, 1.0, impact))
		draw_set_transform(Vector2.ZERO)
		for index in range(9):
			var drop := clampf((impact - 0.14 - 0.024 * (index % 4)) * 1.7, 0, 1)
			if drop <= 0.0 or drop >= 1.0:
				continue
			var spread := float(index - 4)
			var point := Vector2(-8 + spread * 7.0 * drop, 7 + 38.0 * drop * drop)
			var color := Color(0.56, 0.83, 0.94, 1.0 - drop)
			draw_line(point, point + Vector2(spread * 0.9, 7), color, 3.0, true)

	func _draw_impact() -> void:
		var color: Color = PROPS[kind][1]
		color.a = 1.0 - impact
		var radius := 9.0 + impact * 24.0
		if kind == "bomb":
			var star := PackedVector2Array()
			for index in range(10):
				star.append(Vector2.from_angle(TAU * index / 10 - PI / 2) * radius * (1.0 if index % 2 == 0 else 0.45))
			draw_colored_polygon(star, color)
		for index in range(9):
			var direction := Vector2.from_angle(index * TAU / 9.0)
			var pos := direction * radius
			match kind:
				"egg":
					draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-3, 5), pos + Vector2(4, 5)]), color)
				"flower":
					draw_circle(pos + Vector2(0, impact * 14), 3.7, color, true, -1, true)
				"bomb":
					draw_line(pos - direction * 5, pos + direction * 6, color, 3, true)
					draw_circle(pos * 0.55, 7.0, Color(0.43, 0.46, 0.42, color.a * 0.71), true, -1, true)
				"tomato":
					draw_circle(pos * (0.8 + (index % 3) * 0.16), 4, color, true, -1, true)
