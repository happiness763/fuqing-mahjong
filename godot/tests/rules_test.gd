extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")
const AI = preload("res://scripts/opponent.gd")
const GROUPS = [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25]
var failures := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	test_claim_visibility()
	test_round_settings()
	test_kong_remains_available()
	check(Rules.winning(GROUPS + [14, 14], 0, 26), "five groups and a pair")
	check(Rules.winning(GROUPS + [14, 26], 0, 26), "wild pair")
	check(Rules.winning([0, 1, 26, 26, 26], 4, 26, true), "two golds as pair")
	check(not Rules.winning([0, 4, 26, 26, 26], 4, 26, true), "gold pair requires valid groups")
	check(not Rules.winning([8, 9, 10, 14, 14], 4, 26), "suits cannot cross")
	check(Rules.idle_gold(GROUPS + [26], 0, 26), "idle gold")
	var score: Dictionary = Rules.score(0, -1, "self", [26], [27, 34], [], 26)
	check(score.deltas == [36, -12, -12, -12], "self-draw scoring")
	var kong_score: Dictionary = Rules.score(1, 3, "discard", [0, 1, 2, 9, 10, 11, 26, 26], [], [
		{"type": "concealedKong", "tiles": [3, 3, 3, 3]}, {"type": "addedKong", "tiles": [4, 4, 4, 4]},
		{"type": "kong", "tiles": [5, 5, 5, 5]}], 26)
	check(kong_score.deltas == [0, 68, 0, -68], "kong bonuses and discard payment")

	var game = Game.new(43)
	check(game.players.map(func(p): return p.hand.size()) == [17, 16, 16, 16], "starting hand sizes")
	check(not game.view(0).players[1].has("hand"), "opponent hand hidden")
	game = fixture()
	game.players[0].hand = [4, 8]
	game.players[1].hand = [2, 3]
	game.players[3].hand = [4, 4, 26]
	play(game, 0, "discard", 4)
	play(game, 1, "chow")
	check(game.phase == "reaction", "waits for competing responses")
	play(game, 3, "pong")
	check(game.current == 3 and game.players[0].river.is_empty(), "pong beats chow")

	game = fixture()
	game.players[0].hand = [14]
	game.players[1].hand = GROUPS + [14]
	game.players[2].hand = GROUPS + [14]
	play(game, 0, "discard", 14)
	play(game, 2, "win")
	play(game, 1, "win")
	check(game.result.winner == 1 and game.result.deltas == [-1, 1, 0, 0], "nearest discard winner")
	game.next_round()
	check(game.dealer == 1 and game.scores == [-1, 1, 0, 0], "rotating dealer and carried scores")

	game = fixture()
	game.players[0].hand = [26]
	game.players[1].hand = GROUPS + [14]
	play(game, 0, "discard", 26)
	check(game.current == 1 and game.players[0].discarded_gold, "gold discard cannot be claimed")
	game.players[0].hand = GROUPS + [14]
	play(game, 1, "discard", 14)
	check(not game.actions(0).any(func(move): return move.type == "win"), "discarded gold blocks ron")

	game = fixture()
	game.wall.resize(21)
	game.wall[0] = 34
	game.players[0].hand = [8]
	play(game, 0, "discard", 8)
	check(game.phase == "sea" and game.wall.size() == 20, "the last live flower starts the sea stage")

	game = fixture()
	game.players[0].hand = [3, 3, 3, 3, 8]
	game.wall.append(7)
	game.wall.append(6)
	play(game, 0, "concealedKong", 3)
	check(game.players[0].hand == [8, 6], "kong draws from tail")
	check(game.view(1).players[0].melds[0].tiles == [-1, -1, -1, -1], "concealed kong hidden")
	game.players[0].melds.append({"type": "pong", "tiles": [6, 6, 6], "from": 1})
	play(game, 0, "addedKong", 6)
	check(game.players[0].melds[1].type == "addedKong", "added kong updates pong")

	game = fixture()
	game.players[0].hand = GROUPS + [14, 8]
	game.players[1].hand = GROUPS.slice(0, 13) + [26, 26, 26]
	game.open_claims("three")
	check(game.actions(0).is_empty(), "opening three gold beats grab")
	play(game, 1, "win")
	check(game.result.kind == "three", "three gold win")
	game = fixture()
	game.players[0].hand = GROUPS + [14, 8]
	game.open_claims("three")
	play(game, 0, "win", 8)
	check(game.result.kind == "grab" and game.indicator == -1 and
		game.players[0].hand.back() == 26 and game.players[0].river.back() == 8, "dealer exchanges for gold")

	var wins := 0
	var expected: Array = Rules.make_wall(RandomNumberGenerator.new())
	expected.sort()
	for seed in range(1, 16):
		game = Game.new(seed)
		var difficulty: String = ["easy", "normal", "hard"][seed % 3]
		for round_number in range(1, 3):
			var actions_taken := 0
			while game.phase != "result" and actions_taken < 300:
				if game.phase == "sea":
					var before_sea: int = game.sea_done
					game.advance_sea()
					check(game.sea_done > before_sea or game.phase == "result", "sea stage advances")
					actions_taken += 1
					continue
				var actor := -1
				for seat in range(4):
					if not game.actions(seat).is_empty():
						actor = seat
						break
				check(actor >= 0, "round has an actor")
				if actor < 0:
					break
				var move: Dictionary = AI.choose(game.view(actor), game.actions(actor), difficulty)
				check(game.act(actor, move.id), "AI chooses a legal action")
				actions_taken += 1
			check(game.phase == "result" and actions_taken < 300, "round terminates")
			var tiles: Array = game.wall.duplicate()
			for player in game.players:
				tiles.append_array(player.hand + player.flowers + player.river)
				for meld in player.melds:
					tiles.append_array(meld.tiles)
			if game.indicator >= 0:
				tiles.append(game.indicator)
			tiles.sort()
			check(tiles == expected and tiles.size() == 144, "round conserves tiles")
			check(game.scores.reduce(func(sum, value): return sum + value, 0) == 0, "zero-sum scores")
			check(game.round_number == round_number, "next round increments")
			if game.result.get("winner", -1) >= 0:
				wins += 1
			check(game.next_round(), "can continue after result")
	check(wins > 0, "AI completes a winning hand")
	if failures == 0:
		print("Godot rules passed, including 30 seeded rounds and ", wins, " wins.")
	quit(failures)


func fixture():
	var game = Game.new(11)
	for p in game.players:
		p.merge({"hand": [], "melds": [], "flowers": [], "river": [], "discarded_gold": false}, true)
	game.gold = 26
	game.indicator = 26
	game.wall.resize(22)
	game.wall.fill(2)
	game.phase = "turn"
	game.current = 0
	game.can_self_win = true
	game.result = {}
	return game


func test_claim_visibility() -> void:
	var game = fixture()
	game.current = 3
	game.players[3].hand = [4]
	game.players[0].hand = [2, 3, 5, 6]
	game.players[2].hand = [4, 4]
	play(game, 3, "discard", 4)
	check(game.actions(0).is_empty(), "higher-priority AI decision gates human chow")
	play(game, 2, "pass")
	var choices: Array = game.actions(0).filter(func(move): return move.type == "chow")
	check(choices.size() == 3, "all three chow choices appear after AI pass")
	if not choices.is_empty():
		var old_id: String = choices[0].id
		play(game, 0, "pass")
		game.current = 3
		game.players[3].hand = [4]
		play(game, 3, "discard", 4)
		check(game.actions(2).is_empty(), "AI cannot pong the same tile before drawing")
		check(game.actions(0).any(func(move): return move.type == "chow"), "chow remains available on the second discard")
		check(not game.act(0, old_id), "previous discard action cannot be submitted")
	game = fixture()
	game.current = 3
	game.players[3].hand = [4]
	game.players[0].hand = [2, 3]
	game.players[2].hand = [4, 4]
	play(game, 3, "discard", 4)
	play(game, 2, "pong")
	check(game.phase == "turn" and game.current == 2, "AI pong resolves without obsolete human menu")
	check(game.players[2].melds[0].claimed == 4, "meld records which tile was claimed")
	game = fixture()
	game.current = 3
	game.players[3].hand = [2]
	game.players[0].hand = [0, 1, 3, 4, 5, 6, 7, 8, 9, 9, 9, 18, 19, 20, 14, 14]
	game.players[2].hand = [2, 2]
	play(game, 3, "discard", 2)
	check(game.actions(0).is_empty(), "competing pong is decided before offering human actions")
	play(game, 2, "pong")
	check(game.actions(0).map(func(move): return move.type) == ["win", "pass"],
		"human win remains available over an AI pong")
	play(game, 0, "pass")
	check(game.current == 2, "passing the win commits the pending AI pong")
	game = fixture()
	game.current = 1
	game.players[1].hand = [14]
	game.players[2].hand = GROUPS + [14]
	game.players[0].hand = GROUPS + [14]
	play(game, 1, "discard", 14)
	check(game.actions(0).is_empty(), "nearer AI win gates farther human win")
	play(game, 2, "win")
	check(game.result.winner == 2, "nearer AI wins without opening human menu")


func test_kong_remains_available() -> void:
	var game = fixture()
	game.wall.resize(24)
	game.wall.fill(2)
	game.players[0].hand = [3, 3, 3, 3, 8]
	check(game.actions(0).any(func(move): return move.type == "concealedKong"), "first kong prompt")
	play(game, 0, "discard", 8)
	game.draw_tile(0, false)
	check(game.actions(0).any(func(move): return move.type == "concealedKong"), "kong returns next turn")
	play(game, 0, "concealedKong", 3)
	check(not game.actions(0).any(func(move): return move.type == "concealedKong"), "played kong leaves candidates")


func test_round_settings() -> void:
	check(Game.new(43).round_limit == 15, "default table length")
	var game = Game.new(43, 1)
	game.finish({"kind": "draw", "winner": -1, "from": -1, "deltas": [4, -5, 4, -3]})
	check(game.is_table_finished() and not game.next_round(), "single round limit")
	check(game.standings().map(func(row): return row.rank) == [1, 1, 3, 4], "ties share rank")
	for dealer in [0, 2]:
		for mode in ["unlucky", "normal", "lucky"]:
			var deal = Game.new(54, 2, mode)
			deal.dealer = dealer
			deal._rng.seed = 54
			deal.start_round()
			var candidate = Game.new(1)
			candidate.dealer = dealer
			var rng := RandomNumberGenerator.new()
			rng.seed = 54
			var ratings := []
			var walls := []
			for attempt in range(5):
				candidate.gold_dice = deal.gold_dice.duplicate()
				candidate.deal(Rules.make_wall(rng))
				ratings.append(AI.opening_value(candidate.players[0].hand, candidate.gold, dealer == 0))
				walls.append(candidate.wall)
			var expected_index: int = 0
			if mode == "unlucky":
				expected_index = ratings.find(ratings.min())
			elif mode == "lucky":
				expected_index = ratings.find(ratings.max())
			check(deal.wall == walls[expected_index], "luck selects expected full wall for dealer %d" % dealer)
			var all_tiles: Array = deal.wall.duplicate()
			for player in deal.players:
				all_tiles.append_array(player.hand + player.flowers)
			all_tiles.append(deal.indicator)
			for tile in range(42):
				check(all_tiles.count(tile) == (4 if tile < 34 else 1), "luck conserves copies")


func play(game, seat: int, kind: String, tile := -1) -> void:
	for move in game.actions(seat):
		if move.type == kind and (tile < 0 or move.get("tile", -1) == tile):
			check(game.act(seat, move.id), "applied " + kind)
			return
	check(false, "missing action " + kind)
