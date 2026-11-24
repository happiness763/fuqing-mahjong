extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")
var failures := 0
var capture_path := ""
var small_window := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--small":
			small_window = true
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func make_meld(kind: String, seat: int, source: int) -> Dictionary:
	return {"type": kind, "tiles": [9, 9, 9, 9] if kind in ["kong", "addedKong", "concealedKong"] else ([9, 10, 11] if kind == "chow" else [9, 9, 9]),
		"from": posmod(seat + source, 4), "claimed": 10 if kind == "chow" else 9}

func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-v133-melds-%d" % OS.get_process_id())
	root.add_child(desk)
	if small_window:
		root.size = Vector2i(864, 540)
		await process_frame
		await process_frame
	desk.lobby.hide()
	desk.game = Game.new(43)
	desk.skip_intro()
	desk.ai_timer.stop()
	var kinds := ["chow", "pong", "kong", "concealedKong", "addedKong"]
	var canvas := Rect2(0, 0, 1280, 800)
	# Exhaust every reachable mix of the five meld types, including five kongs.
	for count in range(6):
		for combination in range(int(pow(kinds.size(), count))):
			var melds: Array = []
			var code := combination
			for index in range(count):
				melds.append(make_meld(kinds[code % kinds.size()], 0, index % 3 + 1))
				code = floori(float(code) / kinds.size())
			var layout: Dictionary = desk.TableLayout3D.hand_group(17 - 3 * count, true, melds)
			var first_hand: Rect2 = desk.native_table.project_rect(layout.hand[0])
			var last_hand: Rect2 = desk.native_table.project_rect(layout.hand.back())
			check(first_hand.position.x >= 95 and last_hand.end.x <= 1255,
				"reachable local hand fits inside the lower rail")
			if count > 0:
				var first_meld: Rect2 = desk.native_table.project_rect(layout.melds[0][0])
				var last_meld: Rect2 = desk.native_table.project_rect(layout.melds.back().back())
				check(first_meld.position.x >= last_hand.end.x - 4 and last_meld.end.x <= 1255,
					"melds stay to the right of the whole hand and within the rail")
	# A full 17-tile hand keeps a large click target and a separated draw.
	var game = desk.game
	game.phase = "turn"
	game.current = 0
	game.players[0].hand = range(17)
	game.players[0].melds = []
	game.drawn = 16
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	var start_view: Dictionary = game.view(0)
	desk.draw_hand(start_view, [{"type": "discard", "tile": 16}], false)
	check(desk.human_buttons.size() == 17, "opening hand displays all seventeen cards")
	var drawn = desk.human_buttons.back()
	var previous = desk.human_buttons[-2]
	var prev_step: float = previous.get_rect().get_center().x - desk.human_buttons[-3].get_rect().get_center().x
	var draw_step: float = drawn.get_rect().get_center().x - previous.get_rect().get_center().x
	check(drawn.size.x >= 44.0 and drawn.size.y >= 54.0 and draw_step > prev_step + 12.0,
		"full hand preserves touch target and drawn-tile gap")
	check(drawn.mouse_filter == Control.MOUSE_FILTER_STOP, "drawn tile remains interactive")
	check(desk.human_buttons[0].position.x >= 95 and drawn.get_rect().end.x <= 1255,
		"seventeen tile opening remains within felt")
	desk.dynamic.free()
	desk.human_buttons.clear()
	game.phase = "result"
	game.drawn = -1
	game.result = {"winner": 1, "tile": 8, "from": -1, "kind": "self"}
	for seat in range(4):
		game.players[seat].hand = [4, 8]
		game.players[seat].melds = []
		for kind in kinds:
			game.players[seat].melds.append(make_meld(kind, seat, 3))
	var view: Dictionary = game.view(0)
	# Use the regular board construction without opening the settlement dialog.
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk._refresh_wall(view, false)
	desk.render_board(view, [], false, false)
	for seat in range(4):
		var band = desk.dynamic.get_node_or_null("MeldsSeat%d" % seat)
		check(is_instance_valid(band), "each seat has a single meld strip")
		if is_instance_valid(band):
			for card in band.find_children("*", "Button", true, false):
				check(canvas.encloses(card.get_rect()), "all exposed melds remain on the 3D table canvas")
	# Claimed tiles are horizontal relative to their owner; an added kong
	# places a fourth tile directly above the original claimed tile.
	for seat in range(4):
		var strip = desk.dynamic.get_node("MeldsSeat%d" % seat)
		for index in range(kinds.size()):
			var group = strip.get_node("Meld%d" % index)
			var sideways := 1 if kinds[index] == "chow" else (0 if kinds[index] != "concealedKong" else -1)
			var normal_index := 0 if sideways != 0 else 1
			var normal_face: PackedVector2Array = group.get_node("MeldTile%d" % normal_index).projected_face
			var normal_axis := (normal_face[1] - normal_face[0]).normalized()
			for card_index in range(4 if kinds[index] in ["kong", "concealedKong"] else 3):
				var card = group.get_node("MeldTile%d" % card_index)
				var face: PackedVector2Array = card.projected_face
				var axis := (face[1] - face[0]).normalized()
				var alignment := absf(axis.dot(normal_axis))
				check(alignment < 0.35 if card_index == sideways else alignment > 0.85,
					"claim orientation is relative to the owning seat")
			if kinds[index] == "addedKong":
				var added = group.get_node("AddedTile")
				var claimed = group.get_node("MeldTile0")
				check(added.get_rect().get_center().y < claimed.get_rect().get_center().y,
					"added kong remains stacked above the claimed tile")
	var winner = desk.dynamic.get_node_or_null("RevealedHand1/RevealedTile1_1")
	check(is_instance_valid(winner), "settlement hand is rotated with its seat")
	if is_instance_valid(winner):
		check(desk.winning_tile_rect.is_equal_approx(desk.tile_canvas_rect(winner)),
			"winning effect uses transformed canvas coordinates")
	var local_hand = desk.dynamic.get_node_or_null("HandTile0")
	check(is_instance_valid(local_hand) and local_hand.get_parent() == desk.dynamic
		and local_hand.rotation == 0 and local_hand.scale == Vector2.ONE,
		"interactive hand retains unwarped canvas hitboxes")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path) == OK, "native meld layout captured")
	desk.free()
	if failures == 0:
		print("v1.3.3 meld grouping and seat orientation passed")
	quit(failures)
