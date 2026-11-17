extends SceneTree

const Game = preload("res://scripts/game.gd")
const WAITING := [0, 1, 2, 9, 10, 11, 12, 13, 14, 18, 19, 20, 24, 25, 26, 4]
var failures := 0


func _initialize() -> void:
	for online in [false, true]:
		test_redeal(online)
		test_broken_cycle(online)
	if failures == 0:
		print("v1.2.8 first-cycle redeal rules passed")
	quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func fixture(online: bool):
	var game = Game.new(114, 1, "normal", online, 2)
	game.phase = "turn"
	game.gold = 33
	game.wall.resize(42)
	game.wall.fill(8)
	for player in game.players:
		player.hand = [4, 7]
		player.river = []
		player.melds = []
	return game


func act(game, seat: int, kind: String, tile := -1) -> bool:
	for move in game.actions(seat):
		if move.type == kind and (tile < 0 or move.get("tile", -1) == tile):
			return game.act(seat, move.id)
	return false


func pass_claims(game) -> void:
	while game.phase == "reaction":
		var passed := false
		for seat in range(4):
			if act(game, seat, "pass"):
				passed = true
				break
		check(passed, "reaction can be passed")
		if not passed:
			break


func test_redeal(online: bool) -> void:
	var game = fixture(online)
	game.scores = [9, -4, -4, -1]
	game.players[2].hand += [1, 1, 1, 1]
	game.players[3].hand += [2, 3]
	game.wall[0] = 27
	var old: String = game.actions(2).filter(func(move): return move.type == "discard" and move.tile == 4)[0].id
	check(act(game, 2, "concealedKong", 1), "concealed kong may precede the first discard")
	check(act(game, 2, "discard", 4), "dealer makes the first discard")
	check(game.phase == "reaction", "the first discard still offers chow")
	pass_claims(game)
	check(game.players[3].flowers.has(27) and game.drawn == 8, "flower is replaced before the next matching discard")
	check(game.view(0).get("first_cycle", {}) == {"tile": 4, "count": 1, "next_seat": 3},
		"the public first discard is available to AI")
	for seat in [3, 0]:
		check(act(game, seat, "discard", 4), "next seat matches the face")
		pass_claims(game)
	game.players[2].hand = WAITING.slice(3)
	check(game.reaction_actions(2, 1, 4).any(func(move): return move.type == "win"), "fourth discard could otherwise win")
	check(act(game, 1, "discard", 4), "fourth seat matches the face")
	check(game.phase == "redeal" and game.result.get("kind") == "firstCycleDraw", "fourth matching discard aborts before claims")
	check(game.actions(2).is_empty() and not game.view(0).players[2].has("hand"), "redeal has no moves and hides hands")
	if not game.has_method("restart_after_draw"):
		check(false, "game supports redeal")
		return
	var hand_id: int = game.view(0).hand_id
	check(not game.is_table_finished() and not game.next_round(), "last configured round remains open")
	check(game.restart_after_draw(), "redeal starts a fresh hand")
	check(game.view(0).hand_id == hand_id + 1 and game.round_number == 1 and game.dealer == 2, "redeal keeps round and dealer")
	check(game.scores == [9, -4, -4, -1] and game.view(0).first_cycle.is_empty(), "redeal keeps scores and resets tracking")
	game.phase = "turn"
	game.players[2].hand = [4]
	check(not game.act(2, old) and not game.restart_after_draw(), "old moves and repeated restart are rejected")


func test_broken_cycle(online: bool) -> void:
	var game = fixture(online)
	for seat in [2, 3, 0, 1, 2, 3, 0, 1]:
		var target := 7 if seat == 2 and game.players[2].river.is_empty() else 4
		game.players[seat].hand = [target]
		check(act(game, seat, "discard", target), "normal play continues after the first mismatch")
		pass_claims(game)
	check(game.phase == "turn" and game.view(0).get("first_cycle", {}).is_empty(), "second circuit cannot redeal")
	for claim in ["chow", "pong", "kong"]:
		game = fixture(online)
		game.players[3].hand = [2, 3, 7] if claim == "chow" else ([4, 4, 7] if claim == "pong" else [4, 4, 4, 7])
		act(game, 2, "discard", 4)
		check(act(game, 3, claim), "fixture executes " + claim)
		check(game.view(0).get("first_cycle", {}).is_empty(), "accepted " + claim + " cancels first cycle")
