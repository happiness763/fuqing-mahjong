extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")

var failures := 0


func _initialize() -> void:
	test_roll_dealer_breaks_ties()
	test_gold_dice_choose_the_indicator()
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
