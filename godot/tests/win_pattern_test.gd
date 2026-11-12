extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")

var failures := 0


func _initialize() -> void:
	test_pengpeng_scores_three_p()
	test_pengpeng_uses_gold_wildcards()
	test_dandiao_scores_pure_rate()
	test_dandiao_requires_all_melds()
	test_best_pattern_reports_sparrow()
	test_win_action_carries_pattern()
	test_rob_action_carries_pattern()
	test_big_hand_outranks_plain_local()
	test_big_hand_outranks_plain_online()
	if failures == 0:
		print("Win pattern tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func fixture(online := false):
	var game = Game.new(43, 15, "normal", online)
	game.phase = "turn"
	game.pending = {}
	game.gold = 26
	game.indicator = 26
	game.wall.resize(30)
	game.wall.fill(17)
	game.dealer = 0
	game.current = 0
	game.drawn = -1
	game.last_discard = {}
	game.can_self_win = true
	for player in game.players:
		player.hand = []
		player.melds = []
		player.flowers = []
		player.river = []
	return game


func test_pengpeng_scores_three_p() -> void:
	var hand := [0, 0, 0, 9, 9, 9, 18, 18, 18, 3, 3, 3, 12, 12, 12, 25, 25]
	var result: Dictionary = Rules.score(0, -1, "self", hand, [], [], 26)
	check(result.kind == "pengpeng", "five triplets and a pair is pengpeng")
	check(result.multiplier == 3 and result.per_payer == 9, "pengpeng scores 3P")
	check(result.deltas == [27, -9, -9, -9], "pengpeng self-draw charges three payers")


func test_pengpeng_uses_gold_wildcards() -> void:
	var hand := [0, 0, 26, 9, 9, 9, 18, 18, 18, 3, 3, 3, 12, 12, 12, 25, 25]
	var result: Dictionary = Rules.score(0, -1, "self", hand, [], [], 26)
	check(result.kind == "pengpeng", "gold completes the fifth triplet for pengpeng")


func test_dandiao_scores_pure_rate() -> void:
	var melds := [
		{"type": "pong", "tiles": [0, 0, 0]},
		{"type": "pong", "tiles": [9, 9, 9]},
		{"type": "pong", "tiles": [18, 18, 18]},
		{"type": "chow", "tiles": [3, 4, 5]},
		{"type": "pong", "tiles": [12, 12, 12]},
	]
	var result: Dictionary = Rules.score(0, -1, "self", [8, 8], [], melds, 26)
	check(result.kind == "dandiao", "five exposed groups and a lone pair is dandiao")
	check(result.multiplier == 5 and result.offset == 50, "dandiao scores like a pure suit")
	check(result.per_payer == 65 and result.deltas == [195, -65, -65, -65], "dandiao pays 5P+50")
	var discard: Dictionary = Rules.score(0, 3, "discard", [8, 8], [], melds, 26)
	check(discard.kind == "dandiao" and discard.deltas == [65, 0, 0, -65], "a discard dandiao charges only the discarder")


func test_dandiao_requires_all_melds() -> void:
	var melds := [
		{"type": "pong", "tiles": [0, 0, 0]},
		{"type": "pong", "tiles": [9, 9, 9]},
		{"type": "pong", "tiles": [18, 18, 18]},
		{"type": "pong", "tiles": [12, 12, 12]},
	]
	var result: Dictionary = Rules.score(0, -1, "self", [3, 4, 5, 8, 8], [], melds, 26)
	check(result.kind == "self", "four melds and a concealed group is not dandiao")


func test_best_pattern_reports_sparrow() -> void:
	var hand := [26, 26, 0, 1, 2, 9, 10, 11, 18, 19, 20, 22, 23, 24, 3, 4, 5]
	var base: int = Rules.base_value(hand, [], [], 26, 1, 0).base
	check(Rules.best_pattern(hand, [], 26, "discard", base) == "sparrow", "double gold pair is read as sparrow")


func test_win_action_carries_pattern() -> void:
	var game = fixture()
	game.players[3].hand = [8]
	game.players[0].hand = [26, 26, 0, 1, 2, 9, 10, 11, 18, 19, 20, 22, 23, 24, 3, 4]
	var moves: Array = game.reaction_actions(0, 3, 5)
	var wins := moves.filter(func(move): return move.type == "win")
	check(wins.size() == 1 and wins[0].get("pattern", "") == "sparrow",
		"the win action carries the best pattern for the button")


func test_rob_action_carries_pattern() -> void:
	var game = fixture(true)
	game.players[0].hand = [14]
	game.players[0].melds = [{"type": "pong", "tiles": [14, 14, 14], "from": 3}]
	game.players[1].hand = [26, 26, 9, 10, 11, 18, 19, 20, 22, 23, 24, 0, 1, 2, 12, 13]
	game.open_rob_kong(0, {"type": "addedKong", "tile": 14, "tiles": [14, 14, 14, 14]})
	var moves: Array = game.actions(1)
	check(moves.any(func(move): return move.type == "win" and move.get("pattern", "") == "sparrow"),
		"a rob-kong win carries its best pattern")


func test_big_hand_outranks_plain_local() -> void:
	var game = fixture()
	game.players[3].hand = [5]
	game.players[0].hand = [0, 1, 2, 9, 10, 11, 18, 19, 20, 22, 23, 24, 3, 4, 6, 6]
	game.players[1].hand = [26, 26, 9, 10, 11, 18, 19, 20, 22, 23, 24, 0, 1, 2, 3, 4]
	game.players[2].hand = []
	game.discard(3, 5)
	check(game.actions(0).is_empty(), "a nearer plain win waits for a bigger pending win")
	var win: Dictionary = {}
	for move in game.actions(1):
		if move.type == "win":
			win = move
	check(not win.is_empty() and game.act(1, win.id), "the sparrow claim resolves")
	check(game.result.get("winner") == 1 and game.result.get("kind") == "sparrow",
		"the sparrow hand intercepts the nearer plain win")


func test_big_hand_outranks_plain_online() -> void:
	var game = fixture(true)
	game.players[3].hand = [5]
	game.players[0].hand = [0, 1, 2, 9, 10, 11, 18, 19, 20, 22, 23, 24, 3, 4, 6, 6]
	game.players[1].hand = [26, 26, 9, 10, 11, 18, 19, 20, 22, 23, 24, 0, 1, 2, 3, 4]
	game.players[2].hand = []
	game.discard(3, 5)
	check(game.online_actor() == 1 and game.actions(0).is_empty(),
		"ordered claims ask the bigger pattern first")
	var win: Dictionary = {}
	for move in game.actions(1):
		if move.type == "win":
			win = move
	check(not win.is_empty() and win.get("pattern", "") == "sparrow" and game.act(1, win.id),
		"the first responder takes the sparrow win")
	check(game.result.get("winner") == 1 and game.result.get("kind") == "sparrow",
		"online settlement keeps the sparrow winner")
