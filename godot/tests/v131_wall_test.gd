extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")

var failures := 0
const GROUPS = [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25]


func _initialize() -> void:
	check(Rules.RESERVE == 20 and Rules.BASE_RESERVE == 16 and Rules.SEA_COUNT == 4,
		"the tail keeps 16 base tiles and 4 sea tiles")
	check(Rules.reserve(0, 0) == 20 and Rules.reserve(2, 1) == 24,
		"open kongs add one and concealed kongs add two")
	test_reserve_counts()
	test_sea_draws()
	test_sea_flower()
	test_sea_win()
	if failures == 0:
		print("v1.3.1 wall and sea tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func fixture(wall_size := 20) -> Game:
	var game := Game.new(43)
	game.gold = 26
	game.indicator = 26
	game.phase = "turn"
	game.current = 0
	game.drawn = -1
	game.can_self_win = true
	game.wall = []
	for index in range(wall_size):
		game.wall.append(10)
	for player in game.players:
		player.hand = []
		player.melds = []
		player.flowers = []
		player.river = []
	return game


func test_reserve_counts() -> void:
	var game := fixture()
	check(game.reserve() == 20, "a fresh table reserves twenty")
	game.players[1].melds = [{"type": "kong", "tiles": [1, 1, 1, 1]},
		{"type": "addedKong", "tiles": [2, 2, 2, 2]}]
	check(game.reserve() == 22, "two open kongs reserve two more")
	game.players[2].melds = [{"type": "concealedKong", "tiles": [3, 3, 3, 3]}]
	check(game.reserve() == 24, "a concealed kong reserves two more")
	check(game.view(0).reserve == 24 and game.view(0).remaining == 0,
		"the view publishes the dynamic reserve")


func test_sea_draws() -> void:
	var game := fixture()
	game.draw_tile(0, false)
	check(game.phase == "sea" and game.sea_total == 4 and game.sea_seat == 0,
		"an empty playable wall starts the sea stage at the next drawer")
	var first := game.advance_sea()
	check(not first.get("won", true) and game.sea_seat == 1,
		"the first sea draw passes to the next seat")
	check(game.players[0].hand.size() == 1, "a non-winning sea tile stays in the hand")
	game.advance_sea()
	game.advance_sea()
	var last := game.advance_sea()
	check(last.get("ended", false) and game.phase == "result" and game.result.get("kind") == "seaDraw",
		"four sea draws without a win end in a sea draw")
	check(game.result.deltas == [0, 0, 0, 0], "a sea draw carries no score")
	var game2 := fixture(18)
	game2.draw_tile(0, false)
	check(game2.phase == "sea" and game2.sea_total == 2,
		"the sea stage only takes the tiles still above the base")


func test_sea_flower() -> void:
	var game := fixture()
	game.wall[3] = 27
	game.draw_tile(0, false)
	var sea := game.advance_sea()
	check(sea.get("tile", -1) == 27 and game.players[0].flowers.is_empty(),
		"a sea flower is revealed but not counted")
	check(game.players[0].hand.is_empty() and bool(game.latest.get("flower", false)),
		"the flower is only revealed and never enters the hand")
	check(game.sea_seat == 1 and game.sea_done == 1, "a sea flower passes to the next seat")


func test_sea_win() -> void:
	var game := fixture()
	game.players[1].hand = GROUPS + [14]
	game.wall[3] = 10
	game.wall[2] = 14
	game.draw_tile(0, false)
	var first := game.advance_sea()
	check(not first.get("won", true) and game.players[0].hand == [10], "the first seat misses")
	var second := game.advance_sea()
	check(second.get("won", false) and game.result.get("winner") == 1 and bool(game.result.get("sea", false)),
		"a sea self-draw is scored as a sea win")
	check(game.result.get("tile", -1) == 14, "the sea winning tile is published")
	check(game.phase == "result", "a sea win ends the round")
