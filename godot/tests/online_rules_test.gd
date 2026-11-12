extends SceneTree

const Game = preload("res://scripts/game.gd")
const GROUPS = [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25]
var failures := 0


func _initialize() -> void:
	test_pass_keeps_later_chow()
	test_nearest_win_and_round_revision()
	test_opening_priority()
	test_kong_claim()
	test_all_claims_passed()
	test_timeout_discard_and_privacy()
	test_online_uses_normal_luck()
	test_local_claims()
	if failures == 0:
		print("Online rules tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func fixture(online := true):
	var game = Game.new(43, 15, "normal", online)
	game.phase = "turn"
	game.pending = {}
	game.gold = 26
	game.indicator = 26
	game.wall.resize(24)
	game.wall.fill(17)
	for player in game.players:
		player.hand = []
		player.melds = []
		player.flowers = []
		player.river = []
	return game


func options(game, seat: int) -> Array:
	return game.actions(seat).map(func(move): return move.type)


func play(game, seat: int, kind: String, tile := -1) -> void:
	for move in game.actions(seat):
		if move.type == kind and (tile < 0 or move.get("tile", -1) == tile):
			check(game.act(seat, move.id), "applied " + kind)
			return
	check(false, "missing action " + kind)


func test_pass_keeps_later_chow() -> void:
	var game = fixture()
	game.current = 3
	game.players[3].hand = [2]
	game.players[0].hand = [0, 1, 3, 4, 5, 6, 7, 8, 9, 9, 9, 18, 19, 20, 14, 14]
	game.players[1].hand = [2, 2, 2, 12]
	play(game, 3, "discard", 2)
	check(game.online_actor() == 0 and options(game, 0) == ["win", "pass"], "win is offered before pong or kong")
	check(game.actions(1).is_empty(), "other seats cannot see pending claims")
	var pass_id: String = game.online_timeout_action().get("id", "")
	var revision: int = game.action_revision
	check(not game.act(1, pass_id) and game.action_revision == revision, "wrong seat cannot use another seat's offer")
	check(game.act(0, pass_id) and game.action_revision == revision + 1, "claim timeout is a single pass")
	check(game.online_actor() == 1 and options(game, 1) == ["pong", "kong", "pass"], "pong and kong outrank chow")
	check(not game.act(1, pass_id), "previous stage pass cannot affect a later stage")
	play(game, 1, "pass")
	check(game.online_actor() == 0 and options(game, 0) == ["chow", "chow", "chow", "pass"], "passing win preserves all later chow choices")
	check(not game.act(0, pass_id), "same seat cannot replay its prior pass")
	for move in game.actions(0):
		if move.get("tiles", []) == [1, 3]:
			check(game.act(0, move.id), "one chow combination can be chosen")
	check(game.phase == "turn" and game.online_actor() == 0, "chow immediately grants its own discard turn")
	check(game.players[0].melds.map(func(meld): return meld.tiles) == [[1, 2, 3]], "chosen chow is recorded")


func test_nearest_win_and_round_revision() -> void:
	var game = fixture()
	game.current = 2
	game.players[2].hand = [14]
	game.players[3].hand = GROUPS + [14]
	game.players[0].hand = GROUPS + [14]
	play(game, 2, "discard", 14)
	check(game.online_actor() == 3 and game.actions(0).is_empty(), "closest win is first across a seat wrap")
	play(game, 3, "pass")
	check(game.online_actor() == 0 and options(game, 0) == ["win", "pass"], "farther win is offered after the nearest seat passes")
	var revision: int = game.action_revision
	play(game, 0, "win")
	check(game.online_actor() == -1 and game.action_revision == revision + 1, "successful win closes the stage")
	check(game.result.get("winner") == 0 and game.scores == [3, 0, -3, 0], "claim settles immediately against the discarder")
	check(game.view(1).players[0].has("hand"), "settlement reveals the players' hands")
	check(game.online_timeout_action().is_empty(), "settlement has no timeout move")
	revision = game.action_revision
	check(game.next_round() and game.action_revision == revision + 1, "next round advances the action revision once")
	check(not game.next_round() and game.action_revision == revision + 1, "unavailable next round leaves the revision intact")


func test_opening_priority() -> void:
	var game = fixture()
	game.dealer = 2
	game.current = 2
	game.players[2].hand = GROUPS + [14, 8]
	game.players[3].hand = GROUPS + [14]
	game.players[0].hand = GROUPS + [14]
	game.players[1].hand = GROUPS.slice(0, 13) + [26, 26, 26]
	game.open_claims("three")
	check(game.online_actor() == 1 and game.view(1).opening == "three" and game.view(2).opening == "",
		"three gold is offered privately before dealer grab")
	check(game.actions(2).is_empty(), "dealer grab cannot compete with three gold")
	play(game, 1, "pass")
	check(game.online_actor() == 3 and game.view(3).opening == "grab", "idle grab beats dealer grab")
	check(game.actions(2).is_empty() and game.actions(0).is_empty(), "farther seats wait their turn")
	play(game, 3, "win")
	check(game.result.get("winner") == 3 and game.result.get("kind") == "grab", "grab settles while farther seats still qualify")


func test_kong_claim() -> void:
	var game = fixture()
	game.players[0].hand = [2]
	game.players[1].hand = [0, 1, 3, 4, 5, 6, 7, 8, 9, 9, 9, 18, 19, 20, 14, 14]
	game.players[3].hand = [2, 2, 2, 12, 26]
	game.wall.append(8)
	play(game, 0, "discard", 2)
	play(game, 1, "pass")
	play(game, 3, "kong")
	check(game.online_actor() == 3 and game.phase == "turn" and game.drawn == 8, "kong supersedes chow and draws a supplement immediately")
	check(game.players[0].river.is_empty(), "claim removes the original discard from the river")


func test_all_claims_passed() -> void:
	var game = fixture()
	game.players[0].hand = [4]
	game.players[1].hand = [2, 3]
	game.players[3].hand = [4, 4, 26]
	play(game, 0, "discard", 4)
	play(game, 3, "pass")
	play(game, 1, "pass")
	check(game.online_actor() == 1 and game.drawn == 17 and game.players[0].river == [4], "all passes resume the next seat's normal draw")


func test_timeout_discard_and_privacy() -> void:
	var game = fixture()
	game.players[0].hand = [12, 3, 3, 3, 3, 8, 26]
	game.wall.append(12)
	game.drawn = 8
	check(game.online_timeout_action().get("tile") == 8, "timeout prefers the drawn non-gold over a kong or lower tile")
	game.drawn = 26
	check(game.online_timeout_action().get("tile") == 3, "timeout picks the leftmost non-gold when gold was drawn")
	var stale_id := ""
	for move in game.actions(0):
		if move.type == "discard" and move.tile == 12:
			stale_id = move.id
	var revision: int = game.action_revision
	play(game, 0, "concealedKong", 3)
	check(game.action_revision == revision + 1 and not game.act(0, stale_id), "old discard ID is stale after same-seat supplement")
	var own: Dictionary = game.view(0)
	var other: Dictionary = game.view(1)
	check(own.drawn == 12 and own.players[0].melds[0].tiles == [3, 3, 3, 3], "active seat sees its draw and concealed kong")
	check(other.drawn == -1 and not other.players[0].has("hand") and other.latest.tile == -1, "opponents do not see private tiles in the view")
	check(other.players[0].melds[0].tiles == [-1, -1, -1, -1], "opponents see only the concealed kong backs")
	game.players[0].hand = [26, 26, 26]
	game.drawn = 26
	var gold_discard: Dictionary = game.online_timeout_action()
	check(gold_discard.get("type") == "discard" and gold_discard.get("tile") == 26, "timeout discards gold when it is the only option, even with a self-win")


func test_online_uses_normal_luck() -> void:
	var game = Game.new(43, 15, "lucky", true)
	var normal = Game.new(43)
	check(game.luck == "normal" and game.wall == normal.wall and game.players == normal.players, "online uses the same unmodified wall as normal luck")


func test_local_claims() -> void:
	var game = fixture(false)
	game.players[0].hand = [4]
	game.players[1].hand = [2, 3]
	game.players[3].hand = [4, 4, 26]
	play(game, 0, "discard", 4)
	play(game, 1, "chow")
	check(game.phase == "reaction", "local AI can still commit a lower-priority reply before other AI")
	play(game, 3, "pong")
	check(game.current == 3, "local mode still resolves simultaneous replies by priority")
