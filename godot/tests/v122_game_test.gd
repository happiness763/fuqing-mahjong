extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const GROUPS := [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25]
var failures := 0


func _initialize() -> void:
	test_flower_gold_deal()
	for online in [false, true]:
		test_opening(online)
		test_restricted_pong(online)
		test_rob(online)
		test_rob_all_pass(online)
		test_gap(online)
		test_locked_best_score(online)
		test_locked_kong_notice(online)
	if failures == 0:
		print("v1.2.2 game rules passed in single-player and online modes")
	quit(failures)


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func fixture(online: bool):
	var game = Game.new(43, 15, "normal", online)
	game.phase = "turn"
	game.pending = {}
	game.gold = 26
	game.indicator = 26
	game.wall.resize(30)
	game.wall.fill(17)
	game.dealer = 0
	game.current = 0
	game.can_self_win = true
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
		player.flowers.clear()
		player.river.clear()
	return game


func find_move(game, seat: int, kind: String, tile := -1) -> Dictionary:
	for move in game.actions(seat):
		if move.type == kind and (tile < 0 or move.get("tile", -1) == tile):
			return move
	return {}


func play(game, seat: int, kind: String, tile := -1) -> bool:
	var move := find_move(game, seat, kind, tile)
	var accepted: bool = not move.is_empty() and game.act(seat, move.id)
	check(accepted, "applied %s for seat %d" % [kind, seat])
	return accepted


func test_flower_gold_deal() -> void:
	var game = fixture(true)
	var deck := []
	deck.resize(100)
	deck.fill(10)
	deck[0] = 35
	deck[1] = 38
	deck[98] = 36
	deck[99] = 34
	game.deal(deck)
	check(game.gold == 34 and game.indicator == 34, "flip happens before replacement flowers")
	check(35 in game.players[0].hand and 35 not in game.players[0].flowers, "dealt summer stays in hand")
	check(36 in game.players[1].hand and game.players[1].flowers == [38], "winter group replacement is playable")


func test_opening(online: bool) -> void:
	var game = fixture(online)
	game.players[0].hand = GROUPS + [14, 14]
	game.players[1].hand = GROUPS + [14]
	game.players[2].hand = GROUPS + [14]
	game.open_claims("heaven")
	check(find_move(game, 0, "win").get("kind") == "heaven", "dealer can take heaven before grab")
	check(game.view(1).opening == "", "opening opportunity is private")
	if not play(game, 0, "pass"):
		return
	check(game.actions(0).is_empty() and game.actions(2).is_empty(), "nearest idle seat is offered grab first")
	if not play(game, 1, "pass") or not play(game, 2, "pass"):
		return
	check(find_move(game, 0, "win").get("kind") == "grab", "dealer can grab after idle seats pass")
	if play(game, 0, "pass"):
		check(game.phase == "turn" and find_move(game, 0, "win").is_empty(), "passed opening win does not repeat before a draw")


func test_restricted_pong(online: bool) -> void:
	var game = fixture(online)
	game.players[3].hand = [11, 11, 11, 2]
	check(game.reaction_actions(3, 0, 11).is_empty(), "dealer's upstream seat cannot claim distant pong or kong without gold")
	check(game.reaction_actions(3, 2, 11).any(func(move): return move.type == "kong"), "own upstream seat may provide a kong")
	game.players[3].hand.append(26)
	check(game.reaction_actions(3, 0, 11).any(func(move): return move.type == "kong"), "holding gold restores all-table claims")
	game.players[3].hand = [11, 11, 0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 14, 15]
	check(Rules.winning(game.players[3].hand + [13], 0, 26), "exception pong fixture is already listening")
	game.players[0].hand = [11]
	if not play(game, 0, "discard", 11) or not play(game, 3, "pong"):
		return
	check(find_move(game, 3, "discard", 15).get("tile") == 15 and find_move(game, 3, "discard", 19).is_empty(),
		"exception pong limits first discard to listening outcomes")
	if not play(game, 3, "discard", 15):
		return
	game.wall[0] = 26
	game.draw_tile(3, false)
	check(game.phase == "result" and game.result.get("method") == "self" and game.result.get("winner") == 3,
		"locked gold draw settles without a choice")


func test_rob(online: bool) -> void:
	var game = fixture(online)
	game.players[0].hand = [14]
	game.players[0].melds = [{"type": "pong", "tiles": [14, 14, 14], "from": 3}]
	game.players[1].hand = GROUPS + [14]
	game.players[2].hand = GROUPS + [14]
	var wall_size: int = game.wall.size()
	if not play(game, 0, "addedKong", 14):
		return
	check(game.phase == "robKong" and game.players[0].melds[0].tiles.size() == 3 and game.wall.size() == wall_size,
		"potential robbed kong leaves the pong and wall intact")
	check(game.view(0).get("rob_tile", -1) == -1 and game.view(1).get("rob_tile") == 14,
		"only current robber sees the candidate tile")
	if not play(game, 1, "pass") or not play(game, 2, "win"):
		return
	check(game.result.get("method") == "rob" and game.result.get("payers") == [0], "robbed kong is paid by the declarer only")
	check(game.players[0].hand.is_empty() and game.players[0].melds[0].type == "pong" and game.wall.size() == wall_size,
		"successful rob transfers the fourth tile and cancels supplement")


func test_rob_all_pass(online: bool) -> void:
	var game = fixture(online)
	game.players[0].hand = [14]
	game.players[0].melds = [{"type": "pong", "tiles": [14, 14, 14], "from": 3}]
	game.players[1].hand = GROUPS + [14]
	game.players[2].hand = GROUPS + [14]
	game.players[2].discarded_gold = true
	game.players[3].hand = GROUPS + [26]
	game.wall[-1] = 22
	var wall_size: int = game.wall.size()
	if not play(game, 0, "addedKong", 14) or not play(game, 1, "pass"):
		return
	check(game.phase == "turn" and game.current == 0 and game.drawn == 22 and game.wall.size() == wall_size - 1,
		"passing bypasses blocked robbers and draws exactly one supplement")
	check(game.players[0].melds[0].type == "addedKong" and game.players[0].melds[0].tiles == [14, 14, 14, 14],
		"all passed commits the previously pending fourth tile")


func test_gap(online: bool) -> void:
	var game = fixture(online)
	game.gold = 4
	game.indicator = 4
	game.players[0].hand = [3, 5, 0, 1, 2, 9, 10, 11, 12, 13, 14, 18, 19, 20, 24, 24, 26]
	game.players[1].hand = []
	var move := find_move(game, 0, "declareGoldGap", 26)
	check(move.get("tiles") == [3, 5], "declare uses two physical gap tiles and a matching discard")
	if not play(game, 0, "declareGoldGap", 26):
		return
	check(game.view(2).players[0].get("gold_gap") == [3, 5] and not game.view(2).players[0].has("hand"),
		"gap is public but remaining hand is private")
	game.wall[0] = 15
	game.draw_tile(0, false)
	check(game.actions(0).size() == 1 and find_move(game, 0, "discard", 15).get("tile") == 15,
		"declared gap permits only ordinary draw-discard")
	if not play(game, 0, "discard", 15):
		return
	game.wall[0] = 4
	game.draw_tile(0, false)
	check(game.phase == "result" and game.result.get("kind") == "goldGap", "declared gap ends when the matching gold is drawn")


func test_locked_best_score(online: bool) -> void:
	var game = fixture(online)
	game.players[0].locked = true
	game.players[0].hand = [0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 6, 7, 8, 1]
	game.wall[0] = 26
	game.draw_tile(0, false)
	check(game.result.get("method") == "self" and game.result.get("kind") == "pure" and game.result.get("offset") == 50,
		"locked auto-draw uses highest scoring pattern")


func test_locked_kong_notice(online: bool) -> void:
	var game = fixture(online)
	game.players[0].locked = true
	game.players[0].hand = [3, 3, 3, 3, 8]
	game.drawn = 3
	game.wall[-1] = 26
	if not play(game, 0, "concealedKong", 3):
		return
	var preceding: Dictionary = game.latest.get("previous", {})
	check(game.result.get("method") == "self" and game.players[0].melds[0].type == "concealedKong",
		"locked concealed kong with a gold supplement settles as self-draw")
	check(preceding.get("type") == "concealedKong" and preceding.get("tile") == -1,
		"same-action win preserves the preceding public kong notice without its concealed tile")
