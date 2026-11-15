extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const READY := [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25, 14]

var failures := 0


func _initialize() -> void:
	for online in [false, true]:
		test_pass(online)
		test_win_pass(online)
		test_combined_pass(online)
		test_unoffered(online)
	if failures == 0:
		print("v1.2.6 pass rules passed")
	quit(failures)


func check(valid: bool, message: String) -> void:
	if not valid:
		failures += 1
		printerr("FAIL: ", message)


func fixture(online: bool):
	var game = Game.new(43, 15, "normal", online)
	game.phase = "turn"
	game.pending = {}
	game.dealer = 3
	game.current = 1
	game.gold = 26
	game.wall.fill(17)
	for player in game.players:
		player.hand = []
		player.melds = []
		player.flowers = []
		player.river = []
	return game


func has_move(game, seat: int, from: int, tile: int, type: String) -> bool:
	return game.reaction_actions(seat, from, tile).any(func(move): return move.type == type)


func move(game, seat: int, type: String) -> bool:
	for action in game.actions(seat):
		if action.type == type:
			return game.act(seat, action.id)
	return false


func test_pass(online: bool) -> void:
	var game = fixture(online)
	game.players[1].hand = [14]
	game.players[0].hand = [14, 14, 8, 8]
	check(move(game, 1, "discard"), "discard for pass pong")
	if online:
		var timeout: Dictionary = game.online_timeout_action()
		check(timeout.get("type") == "pass" and game.act(0, timeout.id), "timeout submits the same pass")
	else:
		check(move(game, 0, "pass"), "pass pong")
	check(not has_move(game, 0, 3, 14, "pong"), "same face pong blocked from a different discarder")
	check(has_move(game, 0, 3, 8, "pong"), "different face pong still offered")
	game.draw_tile(0, false)
	check(has_move(game, 0, 3, 14, "pong"), "own draw restores pong")


func test_win_pass(online: bool) -> void:
	var game = fixture(online)
	game.players[1].hand = [14]
	game.players[0].hand = READY.duplicate()
	check(move(game, 1, "discard") and move(game, 0, "pass"), "pass discard win")
	check(not has_move(game, 0, 2, 14, "win"), "same face discard win blocked")
	game.wall[0] = 14
	game.draw_tile(0, false)
	check(game.actions(0).any(func(action): return action.type == "win"), "same face self-draw still offered")
	game.players[0].hand.pop_back()
	check(has_move(game, 0, 2, 14, "win"), "draw restores future discard win")


func test_combined_pass(online: bool) -> void:
	var game = fixture(online)
	game.players[1].hand = [14]
	game.players[0].hand = READY.slice(0, 12) + [14, 14, 22, 22]
	check(move(game, 1, "discard"), "discard for a combined claim")
	var offers: Array = game.actions(0).map(func(action): return action.type)
	check("win" in offers and "pong" in offers and move(game, 0, "pass"), "pass on both offered actions")
	check(not has_move(game, 0, 2, 14, "pong") and not has_move(game, 0, 2, 14, "win"),
		"combined pass blocks both claims before this seat draws")
	check(has_move(game, 0, 2, 22, "win"), "different winning face remains available")


func test_unoffered(online: bool) -> void:
	var game = fixture(online)
	game.players[1].hand = [14]
	game.players[0].hand = READY.duplicate()
	game.players[2].hand = READY.duplicate()
	check(move(game, 1, "discard") and game.actions(0).is_empty() and move(game, 2, "win"),
		"nearer winner blocks the farther prompt")
	check(has_move(game, 0, 1, 14, "win"), "an unoffered win isn't recorded as a pass")
