extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")
const OpeningIntro = preload("res://scripts/opening_intro.gd")

var failures := 0


func _initialize() -> void:
	test_roll_dealer_breaks_ties()
	test_dealer_roll_state()
	test_gold_dice_choose_the_indicator()
	test_opening_intro_sequence()
	test_deal_flower_events()
	test_flower_draw_events()
	if failures == 0:
		print("v1.2.4 opening tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func test_roll_dealer_breaks_ties() -> void:
	var queue := [6, 4, 5, 5, 2, 3, 1, 2, 6, 5, 2, 2]
	var roller := func():
		return queue.pop_front()
	var roll: Dictionary = Rules.roll_dealer(RandomNumberGenerator.new(), roller)
	check(roll.winner == 0 and roll.rerolls == 1, "tied leaders reroll until one wins")
	check(roll.sums == [11, 4, 5, 3], "only tied seats reroll")


func test_dealer_roll_state() -> void:
	var state := Rules.dealer_roll_state(RandomNumberGenerator.new())
	state.start = 0
	state.order = [0, 1, 2, 3]
	state.round_seats = [0, 1, 2, 3]
	state.index = 0
	var queue := [6, 4, 5, 5, 2, 3, 1, 2, 6, 5, 2, 2]
	var roller := func():
		return queue.pop_front()
	var rng := RandomNumberGenerator.new()
	for index in range(4):
		Rules.dealer_roll_apply(state, rng, roller)
	check(state.sums == [10, 10, 5, 3] and state.tied == [0, 1], "first round finds the tied leaders")
	check(state.round == 2 and state.round_seats == [0, 1] and state.index == 0,
		"tied leaders start the next round in seat order")
	check(Rules.dealer_roll_current(state) == 0, "the first tied seat rolls first")
	Rules.dealer_roll_apply(state, rng, roller)
	Rules.dealer_roll_apply(state, rng, roller)
	check(state.finished and state.winner == 0 and state.sums == [11, 4, 5, 3],
		"rerolls settle on a unique winner")


func test_gold_dice_choose_the_indicator() -> void:
	var game = Game.new(43, 1, "normal", false, 2)
	check(game.dealer == 2, "explicit dealer seat")
	check(game.gold_dice.size() == 2 and game.view(0).gold_dice == game.gold_dice, "view exposes gold dice")
	check(game.gold == game.indicator, "indicator becomes the gold")
	var sum: int = game.gold_dice[0] + game.gold_dice[1]
	check(game.gold_index == posmod(79 - 1 - 2 * (sum - 1), 79), "gold index follows the dice")
	var game2 = Game.new(43)
	game2.gold_dice = [1, 1]
	var deck := []
	deck.resize(100)
	deck.fill(10)
	deck[97] = 34
	game2.deal(deck)
	check(game2.indicator == 34, "sum 2 flips the second stack from the tail")


func test_opening_intro_sequence() -> void:
	var intro := OpeningIntro.new()
	intro.start(1)
	check(intro.stage == "deal" and intro.seat_counts == [0, 0, 0, 0], "deal starts empty")
	for i in range(4):
		intro.advance()
	check(intro.seat_counts == [16, 16, 16, 16] and intro.stage == "dealer_extra", "four rounds deal sixteen tiles")
	intro.advance()
	check(intro.seat_counts[1] == 17 and intro.stage == "dice", "dealer takes the extra tile")
	intro.advance()
	check(intro.stage == "gold", "dice precedes the gold reveal")
	intro.advance()
	check(intro.stage == "flowers", "flowers follow the gold")
	intro.advance()
	check(intro.stage == "done" and not intro.is_active(), "intro finishes")
	check(intro.visible_count(0, 16) == 16, "final counts are fully visible")
	intro.start(0)
	intro.skip()
	check(intro.stage == "done", "skip ends the intro")


func test_deal_flower_events() -> void:
	var game = Game.new(43)
	var deck := []
	deck.resize(100)
	deck.fill(10)
	deck[0] = 35
	deck[1] = 38
	deck[97] = 34
	deck[98] = 22
	deck[99] = 39
	game.gold_dice = [1, 1]
	game.deal(deck)
	check(game.gold == 34, "season gold")
	check(game.deal_flowers.has({"round": 0, "seat": 1, "tile": 38}), "initial flower is round zero")
	check(game.deal_flowers.has({"round": 1, "seat": 1, "tile": 39}), "replacement flower is round one")
	check(38 in game.deal_initial_hands[1], "initial hand keeps the flower until it is replaced")
	check(game.deal_draws.any(func(draw): return draw.seat == 1 and draw.tile == 39 and draw.flower),
		"flower replacement draws are recorded")
	check(game.deal_draws.any(func(draw): return draw.seat == 1 and draw.tile == 22 and not draw.flower),
		"tile replacements are recorded")
	check(game.view(0).deal_draws.any(func(draw): return draw.tile == 39), "public flower draw")
	check(not game.view(0).deal_draws.any(func(draw): return draw.tile == 22),
		"other seats' tile replacements stay private")


func test_flower_draw_events() -> void:
	var game = Game.new(43)
	game.gold = 26
	game.indicator = 26
	game.phase = "turn"
	game.current = 0
	game.players[0].hand = []
	game.players[0].flowers = []
	game.wall = []
	for index in range(18):
		game.wall.append(10)
	game.wall.append(10)
	game.wall.append(28)
	game.wall.append(27)
	game.draw_tile(0, true)
	check(game.last_flowers == [
		{"round": 1, "seat": 0, "tile": 27},
		{"round": 2, "seat": 0, "tile": 28},
	], "draw records flower rounds")
	check(game.flower_revision == 1 and game.view(0).last_flowers == game.last_flowers,
		"flower revision is exposed")
	check(game.players[0].hand == [10] and game.players[0].flowers == [27, 28],
		"draw replaces flowers in order")
