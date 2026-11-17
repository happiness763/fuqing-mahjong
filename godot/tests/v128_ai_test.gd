extends SceneTree

const Game = preload("res://scripts/game.gd")
const Opponent = preload("res://scripts/opponent.gd")

const WEAK := [24, 6, 8, 15, 18, 12, 25, 23, 25, 9, 3, 10, 21, 19, 15, 8, 3]
const STRONG := [23, 11, 4, 6, 18, 6, 24, 8, 3, 11, 24, 1, 5, 2, 21, 16, 20]
const READY := [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 18, 19, 20, 22, 8]
const CLAIM_HAND := [22, 5, 1, 20, 8, 19, 5, 13, 2, 12, 15, 24, 2, 0, 16, 4]

var failures := 0


func _initialize() -> void:
	for difficulty in ["easy", "normal", "hard"]:
		test_matching_discards(difficulty)
		test_protected_hands(difficulty)
		test_low_value_claim(difficulty)
	if failures == 0:
		print("v1.2.8 first-cycle AI tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func fixture(gold := 26, online := false):
	var game = Game.new(43, 1, "normal", online, 0)
	game.phase = "turn"
	game.gold = gold
	game.indicator = gold
	game.wall.fill(7)
	for player in game.players:
		player.hand = []
		player.river = []
		player.melds = []
	return game


func discard(game, seat: int, tile: int) -> bool:
	for move in game.actions(seat):
		if move.type == "discard" and move.tile == tile:
			return game.act(seat, move.id)
	return false


func turn_fixture(target: int, count: int, hand: Array, gold := 26, online := false):
	var game = fixture(gold, online)
	for seat in range(count):
		game.players[seat].hand.append(target)
		check(discard(game, seat, target), "fixture makes matching discard %d" % (seat + 1))
	game.players[count].hand = hand.duplicate()
	game.drawn = hand.back()
	return game


func test_matching_discards(difficulty: String) -> void:
	for count in [1, 2]:
		var early = turn_fixture(21, count, WEAK)
		var move := Opponent.choose(early.view(count), early.actions(count), difficulty)
		check(move.get("tile") == 21, difficulty + " weak hand follows a close early alternative")
	var second = turn_fixture(24, 2, WEAK)
	var move := Opponent.choose(second.view(2), second.actions(2), difficulty)
	check(move.get("tile") != 24, difficulty + " keeps a clearly better early discard")
	var third = turn_fixture(24, 3, WEAK, 26, true)
	var view: Dictionary = third.view(3)
	var moves: Array = third.actions(3)
	var without_cycle := view.duplicate(true)
	without_cycle.first_cycle = {}
	check(Opponent.choose(without_cycle, moves, difficulty).get("tile") != 24,
		difficulty + " follows ordinary play once the first cycle is inactive")
	move = Opponent.choose(view, moves, difficulty)
	check(move.get("tile") == 24 and third.act(3, move.id) and third.phase == "redeal",
		difficulty + " makes the fourth matching discard through the online action API")


func test_protected_hands(difficulty: String) -> void:
	for trial in [[STRONG, 1], [READY, 19]]:
		var game = turn_fixture(trial[1], 3, trial[0])
		check(Opponent.choose(game.view(3), game.actions(3), difficulty).get("tile") != trial[1],
			difficulty + " preserves a strong or ready hand")
	var winning := READY.duplicate()
	winning[16] = 22
	var game = turn_fixture(19, 3, winning)
	check(Opponent.choose(game.view(3), game.actions(3), difficulty).type == "win",
		difficulty + " still takes an available win")
	game = turn_fixture(21, 2, WEAK, 21)
	check(Opponent.choose(game.view(2), game.actions(2), difficulty).get("tile") != 21,
		difficulty + " does not spend a gold to follow")
	game = turn_fixture(24, 3, WEAK)
	game.players[3].lock_discards = [6, 8]
	var legal: Array = game.actions(3)
	check(legal.has(Opponent.choose(game.view(3), legal, difficulty)),
		difficulty + " follows the legal discard restrictions")


func test_low_value_claim(difficulty: String) -> void:
	var game = fixture()
	game.players[0].hand = [0]
	game.players[1].hand = CLAIM_HAND.duplicate()
	check(discard(game, 0, 0) and game.phase == "reaction", "fixture offers a chow")
	var view: Dictionary = game.view(1)
	var moves: Array = game.actions(1)
	var without_cycle := view.duplicate(true)
	without_cycle.first_cycle = {}
	if difficulty == "easy":
		check(Opponent.choose(without_cycle, moves, difficulty).type == "chow", "the easy AI would normally take this chow")
	check(Opponent.choose(view, moves, difficulty).type == "pass",
		difficulty + " passes a low-value chow to keep the matching tile")
