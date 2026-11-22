extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const Metrics = preload("res://scripts/tile_metrics.gd")
const DRAGON_ART = preload("res://assets/effects/chinese_dragon.svg")
const KINDS := ["dragon", "heaven", "pure", "dandiao", "sparrow", "goldGap", "three", "grab", "pengpeng", "idle"]
const DURATION := 2.0
const INK := Color("#101b18")
const PAPER := Color("#fff1d2")
const LIGHT := Color("#ffe29a")

var groups: Array = []
var kind := ""
var gold := -1
var origin := Rect2()


func prepare(view: Dictionary, pattern: String, gold_area: Rect2) -> void:
	kind = pattern
	groups = []
	if kind not in KINDS:
		return
	gold = int(view.get("gold", -1))
	var result: Dictionary = view.result
	var player: Dictionary = view.players[result.winner]
	var hand: Array = player.get("hand", []).duplicate()
	hand.sort()
	var wilds := hand.filter(func(number): return Rules.is_gold(number, gold))
	var winning := int(result.get("tile", -1))
	origin = gold_area
	match kind:
		"dragon", "three":
			groups = [wilds.slice(0, 3)]
		"sparrow":
			groups = [wilds.slice(0, 2)]
		"heaven":
			groups = [hand]
		"pure":
			groups = player.melds.map(func(meld): return meld.tiles.duplicate())
			if not hand.is_empty():
				groups.append(hand)
		"dandiao":
			groups = [hand]
		"goldGap":
			var gap: Array = player.get("gold_gap", []).duplicate()
			if gap.size() == 2 and winning >= 0:
				gap.sort()
				gap.insert(1, winning)
				groups = [gap]
		"grab":
			groups = [[winning]] if winning >= 0 else []
		"pengpeng":
			groups = triplet_groups(hand, player.melds, wilds)
		"idle":
			if not wilds.is_empty() and winning >= 0:
				groups = [[wilds[0], winning]]
	groups = groups.filter(func(group): return not group.is_empty())


func triplet_groups(hand: Array, melds: Array, wilds: Array) -> Array:
	var open := melds.map(func(meld): return meld.tiles.duplicate())
	var counts := Rules.counts(hand.filter(func(number): return not Rules.is_gold(number, gold)))
	var memo := {}
	if wilds.size() >= 2 and Rules.triplets_fit(counts, wilds.size() - 2, memo):
		return complete_triplets(open, counts, wilds.slice(2), wilds.slice(0, 2), memo)
	for number in range(Rules.NUMBERED):
		for used in range(mini(2, counts[number]), maxi(1, 2 - wilds.size()) - 1, -1):
			counts[number] -= used
			var pair_wilds := 2 - used
			if Rules.triplets_fit(counts, wilds.size() - pair_wilds, memo):
				var pair := wilds.slice(0, pair_wilds)
				for index in range(used):
					pair.push_front(number)
				return complete_triplets(open, counts, wilds.slice(pair_wilds), pair, memo)
			counts[number] += used
	return open


func complete_triplets(open: Array, counts: Array, wilds: Array, pair: Array, memo: Dictionary) -> Array:
	var groups_out := open.duplicate()
	for number in range(Rules.NUMBERED):
		while counts[number] > 0:
			for used in range(mini(3, counts[number]), maxi(1, 3 - wilds.size()) - 1, -1):
				counts[number] -= used
				if Rules.triplets_fit(counts, wilds.size() - (3 - used), memo):
					var group := []
					for index in range(used):
						group.append(number)
					for index in range(3 - used):
						group.append(wilds.pop_front())
					groups_out.append(group)
					break
				counts[number] += used
	for index in range(0, wilds.size(), 3):
		groups_out.append(wilds.slice(index, index + 3))
	groups_out.append(pair)
	return groups_out


func paint(canvas: CanvasItem, center: Vector2, faces: Array, color: Color,
		elapsed: float, alpha: float, full: bool, target: Rect2) -> void:
	var stage := smoothstep(0.25, 0.58, elapsed) * alpha
	if stage <= 0:
		return
	if full:
		draw_ink(canvas, center, color, elapsed, stage, target)
	draw_formation(canvas, center, faces, elapsed, stage, target)


func draw_ink(canvas: CanvasItem, center: Vector2, tone: Color, elapsed: float, alpha: float, target: Rect2) -> void:
	var sweep := smoothstep(0.28, 1.34, elapsed)
	var ink := Color(INK, alpha * 0.75)
	var glow := Color(tone.lerp(LIGHT, 0.28), alpha * 0.95)
	var left := center + Vector2(-230, 60)
	var right := center + Vector2(215, 60)
	for layer in range(3):
		var arc := PackedVector2Array()
		for segment in range(22):
			var part := segment / 21.0 * sweep
			arc.append(left.lerp(right, part) + Vector2(0, sin(part * TAU + layer) * (15 + 12 * layer)))
		canvas.draw_polyline(arc, Color(ink, alpha * (0.45 - layer * 0.09)), 38 - layer * 8, true)

	match kind:
		"dragon":
			draw_dragon(canvas, center, sweep, ink, glow)
		"heaven":
			var top := center + Vector2(0, -229)
			canvas.draw_polygon(PackedVector2Array([top + Vector2(-25, 0), top + Vector2(25, 0),
				center + Vector2(133, 123), center + Vector2(-133, 123)]),
				PackedColorArray([glow, glow, Color(glow, 0), Color(glow, 0)]))
			draw_seal(canvas, center + Vector2(155, -80), glow, sweep)
		"pure":
			canvas.draw_line(left, left.lerp(right, sweep), Color("#72d6ad", alpha), 10, true)
			canvas.draw_line(left + Vector2(0, 10), left.lerp(right, sweep) + Vector2(0, 10), glow, 2, true)
		"dandiao":
			canvas.draw_circle(center + Vector2(0, 117), 5 + sweep * 7, glow)
			canvas.draw_arc(center + Vector2(0, 117), 32 + sweep * 13, 0, TAU, 40, glow, 3, true)
		"sparrow":
			for side in [-1, 1]:
				draw_feather(canvas, center + Vector2(side * lerpf(210.0, 105.0, sweep), 15), side, ink, glow)
		"goldGap":
			for side in [-1, 1]:
				var x := float(side) * 75.0
				canvas.draw_polyline(PackedVector2Array([center + Vector2(x + side * 45, 26),
					center + Vector2(x, 73), center + Vector2(x, 124)]), glow, 5, true)
			canvas.draw_line(center + Vector2(0, 27), center + Vector2(0, 27 + sweep * 91), glow, 4, true)
		"three":
			for index in range(3):
				var progress := smoothstep(0.37 + index * 0.17, 0.56 + index * 0.17, elapsed)
				draw_seal(canvas, center + Vector2((index - 1) * 76, 34), glow, progress)
		"grab":
			var start := origin.get_center()
			var end := target.get_center() if target.has_area() else center + Vector2(0, 104)
			var progress := smoothstep(0.46, 1.17, elapsed)
			var point := start.lerp(end, progress)
			if progress > 0.0 and progress < 1.0:
				canvas.draw_line(start.lerp(end, maxf(0, progress - 0.3)), point, glow, 5, true)
		"pengpeng":
			for index in range(5):
				var progress := smoothstep(0.42 + index * 0.12, 0.56 + index * 0.12, elapsed)
				draw_seal(canvas, center + Vector2((index - 2) * 64, 27), glow, progress)
		"idle":
			var ring := center + Vector2(0, 117)
			canvas.draw_arc(ring, 47, -PI * 0.5, -PI * 0.5 + TAU * sweep, 38, glow, 4, true)


func draw_dragon(canvas: CanvasItem, center: Vector2, sweep: float, ink: Color, gold_light: Color) -> void:
	var rise := smoothstep(0.0, 0.52, sweep)
	var settle := smoothstep(0.52, 1.0, sweep)
	var position := center + Vector2(lerpf(-220.0, 135.0, sweep), lerpf(64.0, 14.0, rise))
	position.y += sin(settle * PI) * 12.0
	var size := DRAGON_ART.get_size() * lerpf(0.45, 0.64, rise)
	var bounds := Rect2(position - size * 0.5, size)
	var tail := PackedVector2Array()
	for index in range(20):
		var fraction := index / 19.0
		tail.append(position + Vector2(lerpf(-255.0, -65.0, fraction),
			49.0 + sin(fraction * PI) * 24.0))
	canvas.draw_polyline(tail, Color(ink, gold_light.a * 0.55), 24.0, true)
	canvas.draw_polyline(tail, Color(gold_light, gold_light.a * 0.48), 2.5, true)
	canvas.draw_texture_rect(DRAGON_ART, Rect2(bounds.position + Vector2(0, 9), bounds.size), false,
		Color(0.42, 0.43, 0.34, gold_light.a * 0.36))
	canvas.draw_texture_rect(DRAGON_ART, bounds, false, Color(1, 1, 1, gold_light.a))


func draw_feather(canvas: CanvasItem, point: Vector2, side: int, ink: Color, light: Color) -> void:
	var tip := point + Vector2(side * 110, -53)
	canvas.draw_colored_polygon(PackedVector2Array([point, point + Vector2(side * 57, -61), tip,
		point + Vector2(side * 73, -22)]), ink)
	canvas.draw_line(point, tip, light, 3, true)
	for index in range(1, 5):
		var spine := point.lerp(tip, index / 5.0)
		canvas.draw_line(spine, spine + Vector2(side * 19, -26), light, 2, true)
		canvas.draw_line(spine, spine + Vector2(side * 24, 5), light, 2, true)


func draw_seal(canvas: CanvasItem, point: Vector2, light: Color, landing: float) -> void:
	if landing <= 0:
		return
	var center := point - Vector2(0, (1.0 - landing) * 28)
	var bounds := Rect2(center - Vector2(16, 16), Vector2(32, 32))
	canvas.draw_rect(bounds, Color("#a74732", light.a * landing))
	canvas.draw_rect(bounds.grow(-3), Color(light, light.a * landing), false, 1.5)
	canvas.draw_line(center - Vector2(8, 0), center + Vector2(8, 0), light, 2, true)
	canvas.draw_line(center - Vector2(0, 8), center + Vector2(0, 8), light, 2, true)


func draw_formation(canvas: CanvasItem, center: Vector2, faces: Array, elapsed: float, alpha: float, target: Rect2) -> void:
	var amount := 0
	for group in groups:
		amount += group.size()
	if amount == 0:
		return
	var span := 450.0
	var spacing := 9.0
	var width := minf(47, (span - spacing * (groups.size() - 1)) / amount - 3)
	var size := Vector2(width, width * 1.36)
	var row := center + Vector2(-(amount * (width + 3) + spacing * (groups.size() - 1) - 3) * 0.5, 102)
	var index := 0
	for group in groups:
		for member in range(group.size()):
			var tile := int(group[member])
			var destination := row + Vector2(size.x * 0.5, size.y * 0.5)
			var from := destination + Vector2((destination.x - center.x) * 0.46, -39)
			var start := 0.46 + (0.64 * index / maxi(1, amount - 1))
			if kind == "goldGap" and member == 1:
				from = destination - Vector2(0, 130)
				start = 1.03
			elif kind == "goldGap":
				start = 0.54
			elif kind == "grab":
				from = origin.get_center()
				if target.has_area():
					destination = target.get_center()
			elif kind in ["idle", "dandiao", "sparrow"]:
				from += Vector2(-62 if member == 0 else 62, 0)
			elif kind == "three":
				from = destination - Vector2(0, 108)
			var enter := smoothstep(start, start + (0.71 if kind == "grab" else 0.34), elapsed)
			if enter > 0:
				var opacity := smoothstep(start, start + 0.10, elapsed) * alpha
				var point := from.lerp(destination, enter)
				if kind not in ["heaven", "grab"]:
					point.y -= sin(enter * PI) * 21
				var tile_size := size.lerp(target.size, enter) if kind == "grab" and target.has_area() else size
				draw_tile(canvas, faces, tile, Rect2(point - tile_size * 0.5, tile_size), opacity)
			row.x += width + 3
			index += 1
		row.x += spacing


func draw_tile(canvas: CanvasItem, faces: Array, number: int, bounds: Rect2, alpha: float) -> void:
	var gilded := Rules.is_gold(number, gold)
	canvas.draw_rect(Rect2(bounds.position + Vector2(0, 3), bounds.size), Color(INK, alpha))
	canvas.draw_rect(bounds.grow(2), Color(LIGHT, 0.40 * alpha))
	canvas.draw_rect(bounds, Color(LIGHT if gilded else PAPER, alpha))
	canvas.draw_rect(bounds, Color("#a4773a", alpha), false, 1.0)
	if number >= 0 and number < faces.size() and faces[number] != null:
		canvas.draw_texture_rect(faces[number], Metrics.fit_art(faces[number].get_size(), bounds.grow(-2)), false, Color(1, 1, 1, alpha))
