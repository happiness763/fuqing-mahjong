extends SceneTree

const Game = preload("res://scripts/game.gd")
const TableView = preload("res://scripts/online_table_view.gd")
const Desk = preload("res://table.tscn")
const TableWall = preload("res://scripts/table_wall.gd")
const Art = preload("res://scripts/table_art.gd")

var failures := 0
var output_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			output_dir = argument.trim_prefix("--qa-dir=")
	run.call_deferred()


func run() -> void:
	test_geometry()
	test_kong_takes()
	await test_table()
	if failures == 0:
		print("Dynamic wall rules and table passed.")
	quit(failures)


func test_geometry() -> void:
	var game := Game.new(43)
	var deck := []
	deck.resize(144)
	deck.fill(10)
	deck[0] = 35
	deck[141] = 26
	deck[143] = 27
	game.gold_dice = [1, 1]
	game.deal(deck)
	var initial: Dictionary = game.view(0).get("wall", {})
	check(initial.get("size", 0) == 144, "a full wall has 144 physical tile slots")
	if initial.is_empty():
		return
	check(initial.opening.size() == 68, "65 dealt tiles, an indicator, and two opening replacements")
	check(initial.opening[0] == {"slot": 0, "seat": 0, "kind": "deal", "end": "head"},
		"dealing starts at the head")
	check(initial.opening[64].slot == 64 and initial.opening[64].kind == "deal",
		"the dealer's extra tile leaves the head")
	check(initial.opening[65] == {"slot": 141, "seat": -1, "kind": "gold", "end": "indicator"},
		"the dice select a slot measured against the original wall")
	check(initial.opening[66].slot == 143 and initial.opening[67].slot == 142,
		"opening flowers are replaced from the tail in order")
	check(initial.slots.front() == 65 and initial.slots.back() == 140 and initial.slots.size() == 76,
		"physical positions survive removals")
	check(initial == game.view(2).wall, "the geometry itself is identical for every recipient")
	game.wall[0] = 28
	game.draw_tile(1, false)
	var next: Dictionary = game.view(0).wall
	check(next.takes == [
		{"slot": 65, "seat": 1, "kind": "flower", "end": "head"},
		{"slot": 140, "seat": 1, "kind": "draw", "end": "tail"},
	], "ordinary flowers remove one head tile before replacement moves to the tail")
	check(next.slots.front() == 66 and next.slots.back() == 139 and next.slots.size() == 74,
		"head and tail moves preserve all intervening positions")
	var rotated := TableView.from_room({"view": game.view(2), "my_seat": 2, "seats": [{}, {}, {}, {}]})
	check(rotated.wall.takes[0].seat == 3 and rotated.wall.takes[0].slot == 65,
		"the receiving player rotates independently of the public slot identifier")
	while game.wall.size() > 18:
		game.draw_tile(1, true)
	var reserve: Dictionary = game.view(0)
	game.draw_tile(1, false)
	check(reserve.remaining == 0 and reserve.wall.slots.size() == 18
		and game.view(0).wall == reserve.wall, "the last 18 slots still render and cannot be drawn")
	game.start_round()
	check(game.view(0).wall.takes.is_empty(), "a new deal resets runtime take events")
	for luck_mode in ["lucky", "unlucky"]:
		var lucky := Game.new(46, 15, luck_mode)
		var chosen: Dictionary = lucky.view(0).wall
		check(chosen.slots.size() == lucky.wall.size() and chosen.opening.size() + chosen.slots.size() == 144
			and chosen.opening.count({"slot": 65 + lucky.gold_index, "seat": -1, "kind": "gold", "end": "indicator"}) == 1,
			"luck selection restores the corresponding slots and indicator")


func test_kong_takes() -> void:
	var waiting_hand := [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25, 14]
	for kind in ["concealedKong", "kong", "addedKong", "robbedKong"]:
		var game := Game.new(43, 15, "normal", true)
		game.phase = "turn"
		game.pending = {}
		game.gold = 26
		game.wall[-1] = 10
		for player in game.players:
			player.hand.clear()
		var before: Dictionary = game.view(0).wall
		match kind:
			"concealedKong":
				game.players[0].hand = [5, 5, 5, 5]
				take_action(game, 0, kind)
			"kong":
				game.players[0].hand = [5]
				game.players[1].hand = [5, 5, 5]
				take_action(game, 0, "discard")
				take_action(game, 1, kind)
			"addedKong", "robbedKong":
				game.players[0].hand = [14]
				game.players[0].melds = [{"type": "pong", "tiles": [14, 14, 14], "from": 3}]
				if kind == "robbedKong":
					game.players[1].hand = waiting_hand
				take_action(game, 0, "addedKong")
				if kind == "robbedKong":
					check(game.view(0).wall == before, "declaring an offered added kong leaves the same slots")
					take_action(game, 1, "win")
		var after: Dictionary = game.view(0).wall
		if kind == "robbedKong":
			check(after == before and game.result.get("method") == "rob", "a successful rob leaves every wall slot intact")
		else:
			check(after.slots == before.slots.slice(0, -1) and after.takes.size() == 1
				and after.takes[0].end == "tail" and after.takes[0].slot == before.slots.back(),
				"%s takes exactly one supplement from the actual tail slot" % kind)


func take_action(game: Game, seat: int, kind: String) -> void:
	var wanted: Array = game.actions(seat).filter(func(action): return action.type == kind)
	check(not wanted.is_empty() and game.act(seat, wanted[0].id), "seat %d takes %s" % [seat, kind])


func test_table() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-wall-%d" % OS.get_process_id())
	root.add_child(desk)
	desk.lobby.hide()
	desk.header.show()
	var game := Game.new(43)
	var deck := []
	deck.resize(144)
	deck.fill(10)
	deck[0] = 35
	deck[141] = 26
	deck[143] = 27
	game.gold_dice = [1, 1]
	game.deal(deck)
	desk.game = game
	desk.start_intro()
	desk.intro_timer.stop()
	check(desk.wall_art.slots.size() == 144, "opening renders four sides of 18 two-tile stacks")
	for slot in range(144):
		var rect := TableWall.slot_rect(slot, 0)
		var overlaps_river := Art.RIVERS.any(func(river): return river.intersects(rect))
		var dice_rect := Rect2(Art.CENTER - Vector2(68, 62), Vector2(136, 124))
		var rob_kong_offer := Rect2(480, 322, 138, 88)
		check(not overlaps_river and not dice_rect.intersects(rect) and not rob_kong_offer.intersects(rect),
			"wall slot %d has a clear position" % slot)
	await capture("wall-full.png")
	desk.advance_intro()
	desk.intro_timer.stop()
	check(desk.wall_art.slots.size() == 128 and desk.wall_flights.get_child_count() == 16,
		"the opening takes one batch of 16 backs off the wall")
	for index in range(3):
		desk.intro.advance()
	desk.refresh()
	check(desk.wall_art.slots.size() == 80, "four deal batches leave 80 wall tiles")
	desk.intro.advance()
	desk.refresh()
	check(desk.wall_art.slots.size() == 79 and 141 in desk.wall_art.slots,
		"the dealer takes a tile and the indicator stays covered during dice")
	desk.intro.advance()
	desk.refresh()
	check(desk.wall_art.slots.size() == 78 and 141 not in desk.wall_art.slots and desk.wall_gold_from.is_finite(),
		"the gold reveal removes and flips the exact indicator")
	desk.advance_intro()
	desk.flower_timer.stop()
	desk.advance_flower()
	desk.flower_timer.stop()
	check(desk.wall_art.slots.size() == 78, "exposing an already-dealt flower does not move the wall")
	desk.advance_flower()
	desk.flower_timer.stop()
	check(desk.wall_art.slots.size() == 77 and 143 not in desk.wall_art.slots,
		"opening replacement flower takes its tail slot exactly once")
	desk.skip_intro()
	check(desk.wall_art.slots == game.view(0).wall.slots and desk.wall_flights.get_child_count() == 0,
		"skip jumps to the current synchronized wall")
	await capture("wall-settled.png")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(864, 540)
		await capture("wall-small.png")
	game.wall[0] = 28
	game.draw_tile(1, false)
	desk.refresh(true)
	desk.flower_timer.stop()
	check(desk.wall_art.slots.size() == 76, "the next flower and replacement wait for their turns to animate")
	desk.advance_flower()
	desk.flower_timer.stop()
	check(65 not in desk.wall_art.slots and 140 in desk.wall_art.slots,
		"a normal flower leaves the head and holds its replacement on the tail")
	desk.advance_flower()
	desk.flower_timer.stop()
	check(desk.wall_art.slots == game.view(0).wall.slots and desk.wall_flights.get_child_count() == 1
		and desk.wall_flights.get_child(0).number == -1, "another player's replacement flies as a face-down card")
	desk.skip_intro()
	game.draw_tile(0, false)
	desk.refresh(true)
	check(desk.wall_art.slots == game.view(0).wall.slots and desk.wall_draw_from.is_finite(),
		"the local draw starts at its actual slot and shows the card in hand")
	test_resync(desk)
	desk.queue_free()
	await process_frame


func test_resync(desk) -> void:
	desk.game = null
	desk.show_online()
	var game := Game.new(43, 15, "normal", true)
	var seats: Array = []
	for seat in range(4):
		seats.append({"name": str(seat), "kind": "human", "connected": true})
	desk.room.state = {"phase": "playing", "stage": 1, "owner": 0, "my_seat": 1, "seats": seats,
		"actor": game.current, "view": game.view(1)}
	desk.room_state_changed()
	desk.intro_timer.stop()
	desk.advance_intro()
	desk.intro_timer.stop()
	check(desk.intro_active() and desk.wall_art.slots.size() == 128, "an online opening plays on first entry")
	desk.room.state.reconnecting = true
	desk.room_state_changed()
	check(not desk.intro_active() and desk.wall_art.slots == game.view(1).wall.slots,
		"disconnect during opening restores the authoritative wall")
	game.draw_tile(1, false)
	game.draw_tile(2, false)
	desk.room.state.stage = 3
	desk.room.state.reconnecting = false
	desk.room.state.view = game.view(1)
	desk.room_state_changed()
	check(desk.wall_art.slots == game.view(1).wall.slots and desk.wall_flights.get_child_count() == 0,
		"reconnect replaces the wall with the latest snapshot and drops stale flights")


func capture(filename: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir.path_join(filename)) == OK, "saved " + filename)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
