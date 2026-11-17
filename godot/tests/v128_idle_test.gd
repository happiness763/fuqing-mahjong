extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const GOLD := 33
const WINNER := 1
const FOUR_GROUPS := [3, 4, 5, 9, 10, 11, 18, 19, 20, 21, 22, 23]
const SINGLE_GOLD := FOUR_GROUPS + [0, 1, 2, GOLD]
const DUAL_SEQUENCE := FOUR_GROUPS + [0, 1, GOLD, GOLD]
const DUAL_TRIPLET := FOUR_GROUPS + [0, 0, GOLD, GOLD]
const DUAL_INCOMPLETE := FOUR_GROUPS + [0, 7, GOLD, GOLD]

var failures := 0


func _initialize() -> void:
	check(Rules.idle_gold(SINGLE_GOLD, 0, GOLD), "a single reserved gold leaves five natural groups")
	check(Rules.idle_gold(DUAL_SEQUENCE, 0, GOLD), "the second gold can complete a sequence")
	check(Rules.idle_gold(DUAL_TRIPLET, 0, GOLD), "the second gold can complete a triplet")
	check(Rules.idle_gold([0, 1, GOLD, GOLD], 4, GOLD), "existing melds count toward the five groups")
	check(not Rules.idle_gold(DUAL_INCOMPLETE, 0, GOLD), "the second gold cannot repair two unrelated tiles")
	for online in [false, true]:
		check_self_draw(online, SINGLE_GOLD, GOLD, 14, "idle", 16, "single gold")
		check_self_draw(online, DUAL_SEQUENCE, GOLD, 14, "idle", 20, "dual gold complementing a sequence")
		check_self_draw(online, DUAL_TRIPLET, GOLD, 14, "idle", 20, "dual gold complementing a triplet")
		check_self_draw(online, FOUR_GROUPS + [0, 1, 34, 36], 35, 14, "idle", 20,
			"two seasonal golds with distinct faces")
		check_self_draw(online, DUAL_INCOMPLETE, GOLD, 7, "self", 10, "dual gold without an idle wait")
		check_self_draw(online, DUAL_SEQUENCE, GOLD, 2, "sparrow", 60, "sparrow beats idle on the same draw")
		check_self_draw(online, SINGLE_GOLD, GOLD, GOLD, "sparrow", 60, "drawing gold can form sparrow")
		check_self_draw(online, FOUR_GROUPS + [0, 1, 26, 26], 26, 14, "idle", 16,
			"two ordinary golds")
		check_discard_claim(online, SINGLE_GOLD, false)
		check_discard_claim(online, DUAL_SEQUENCE, true)
		check_rob_claim(online, SINGLE_GOLD, false)
		check_rob_claim(online, DUAL_SEQUENCE, true)
	if failures == 0:
		print("Godot v1.2.8 idle gold tests passed.")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func fixture(online: bool, prior: Array, gold: int):
	var game = Game.new(43, 15, "normal", online)
	game.dealer = 0
	game.current = 0
	game.phase = "turn"
	game.pending = {}
	game.gold = gold
	game.indicator = gold
	game.drawn = -1
	game.wall.resize(24)
	game.wall.fill(17)
	for player in game.players:
		player.hand = []
		player.melds = []
		player.flowers = []
		player.river = []
	game.players[WINNER].hand = prior.duplicate()
	return game


func find_win(options: Array) -> Dictionary:
	for option in options:
		if option.type == "win":
			return option
	return {}


func check_self_draw(online: bool, prior: Array, gold: int, tile: int, kind: String, points: int, scenario: String) -> void:
	var game = fixture(online, prior, gold)
	var label := "%s (online=%s)" % [scenario, online]
	game.wall[0] = tile
	game.draw_tile(WINNER, false)
	var win := find_win(game.actions(WINNER))
	check(win.get("pattern", "") == kind, "%s offers %s" % [label, kind])
	if win.is_empty():
		return
	check(game.act(WINNER, win.id), "%s accepts win action" % label)
	check(game.result.get("kind", "") == kind and game.result.get("method", "") == "self",
		"%s settlement agrees with the winning pattern" % label)
	check(game.result.get("per_payer", -1) == points, "%s pays %d points per opponent" % [label, points])


func check_discard_claim(online: bool, prior: Array, allowed: bool) -> void:
	var game = fixture(online, prior, GOLD)
	game.players[0].hand = [14]
	game.discard(0, 14)
	var win := find_win(game.actions(WINNER))
	var label := "discard claim (online=%s, allowed=%s)" % [online, allowed]
	var offered: bool = win.get("kind", "") == "discard"
	check(offered == allowed, "%s preserves eligibility" % label)
	if allowed and offered:
		check(win.get("pattern", "") == "discard", "%s uses ordinary discard scoring" % label)
		check(game.act(WINNER, win.id), "%s accepts win action" % label)
		check(game.result.get("kind", "") == "discard" and game.result.get("per_payer", -1) == 5,
			"%s settles for one payer at base points" % label)


func check_rob_claim(online: bool, prior: Array, allowed: bool) -> void:
	var game = fixture(online, prior, GOLD)
	game.players[0].hand = [14]
	game.players[0].melds = [{"type": "pong", "tiles": [14, 14, 14], "from": 3}]
	game.open_rob_kong(0, {"type": "addedKong", "tile": 14, "tiles": [14, 14, 14, 14]})
	var win := find_win(game.actions(WINNER))
	var label := "rob claim (online=%s, allowed=%s)" % [online, allowed]
	var offered: bool = win.get("kind", "") == "rob"
	check(offered == allowed, "%s preserves eligibility" % label)
	if allowed and offered:
		check(win.get("pattern", "") == "rob", "%s uses ordinary rob scoring" % label)
		check(game.act(WINNER, win.id), "%s accepts win action" % label)
		check(game.result.get("kind", "") == "rob" and game.result.get("per_payer", -1) == 10,
			"%s settles for one payer at double the base points" % label)
