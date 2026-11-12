extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/opponent.gd")
const MIXED_GROUPS := [0, 1, 2, 9, 10, 11, 18, 19, 20, 21, 22, 23, 24, 25, 26]
const MIXED_WIN := MIXED_GROUPS + [13, 13]

var failures := 0


func _initialize() -> void:
	test_base_points()
	test_gold_groups()
	test_patterns()
	test_gold_gap()
	test_ai()
	test_ai_restricted_pong()
	if failures == 0:
		print("Godot v1.2.2 scoring passed.")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func test_base_points() -> void:
	var guest := Rules.score(1, 3, "discard", MIXED_WIN, [], [], 4)
	check(guest.deltas == [0, 1, 0, -1], "guest's discard win uses a base of one")
	var dealer := Rules.score(0, -1, "self", MIXED_WIN, [], [], 4)
	check(dealer.deltas == [18, -6, -6, -6], "dealer's self-draw uses a base of three and three payers")
	var grab := Rules.score(1, -1, "grab", MIXED_WIN, [], [], 4)
	check(grab.per_payer == 3, "grab gold uses 3P")


func test_gold_groups() -> void:
	check(Rules.gold_tiles(34) == [34, 35, 36, 37], "seasonal gold includes all four seasons")
	check(Rules.gold_tiles(41) == [38, 39, 40, 41], "plant gold includes all four plants")
	check(Rules.gold_tiles(27) == [27] and not Rules.is_gold(28, 27), "honor gold only includes the matching honor")
	check(Rules.is_flower(38, 34) and not Rules.is_flower(37, 34), "gold seasons stay in hand while plants are flowers")
	check(Rules.gold_count([34, 35, 36, 38, 4], 35) == 3, "each tile in the gold family is counted")
	check(Rules.winning(MIXED_GROUPS + [35, 36], 0, 34, true), "flower golds form a double-gold pair")
	check(not Rules.winning(MIXED_GROUPS + [35, 38], 0, 34), "a flower outside the gold family cannot be a wildcard")
	check(Rules.idle_gold(MIXED_GROUPS + [36], 0, 34), "flower gold can be the single idle gold")
	check(Rules.counts([35, -1, 3, 3])[3] == 2, "numbered counts safely ignore flowers and hidden tiles")
	var sparrow := Rules.score(2, 1, "rob", [35, 36, 9, 10, 11, 13, 14, 15], [27, 38, 39], [
		{"type": "concealedKong", "tiles": [0, 0, 0, 0]},
		{"type": "kong", "tiles": [18, 18, 18, 18]},
		{"type": "addedKong", "tiles": [24, 24, 24, 24]},
	], 34)
	check(sparrow.kind == "sparrow" and sparrow.method == "rob", "rob method keeps the higher sparrow score")
	check(sparrow.base_points == 1 and sparrow.flower_points == 7 and sparrow.gold_points == 4 and sparrow.flower_golds == 2,
		"settlement exposes the contribution of each tile and kong")
	check(sparrow.offset == 40 and sparrow.deltas == [0, -88, 88, 0], "sparrow adds 40 and only the robbed player pays")
	var flower_base := Rules.score(2, 1, "discard", MIXED_GROUPS + [13, 35], [27, 38, 39], [], 34)
	check(flower_base.base == 6 and flower_base.per_payer == 6, "flower gold is worth two in the base")


func test_patterns() -> void:
	var regular_rob := Rules.score(2, 3, "rob", MIXED_WIN, [], [], 4, 2)
	check(regular_rob.kind == "rob" and regular_rob.deltas == [0, 0, 6, -6], "rob kong alone uses 2P and the current dealer's base")
	var idle := Rules.score(2, -1, "self", MIXED_GROUPS + [4, 13], [], [], 4, 0, true)
	check(idle.kind == "idle" and idle.method == "self" and idle.per_payer == 14, "qualified idle gold uses 2P+10")
	var sparrow := Rules.score(2, 1, "discard", MIXED_GROUPS + [4, 4], [], [], 4)
	check(sparrow.kind == "sparrow" and sparrow.deltas == [0, -52, 52, 0], "double gold wins on a discard with one payer")
	var incomplete := Rules.score(2, -1, "three", MIXED_GROUPS.slice(0, 13) + [4, 4, 4], [], [], 4)
	check(incomplete.kind == "three" and incomplete.per_payer == 12, "three golds without a full winning structure score 3P")
	var dragon_hand: Array = MIXED_WIN.slice(3) + [4, 4, 4]
	var dragon := Rules.score(2, -1, "three", dragon_hand, [], [], 4)
	check(dragon.kind == "dragon" and dragon.method == "three" and dragon.per_payer == 70, "gold dragon beats three gold and sparrow")
	var heaven := Rules.score(0, -1, "heaven", dragon_hand, [], [], 4)
	check(heaven.kind == "heaven" and heaven.per_payer == 80, "heaven keeps priority when tied with gold dragon")
	var open_groups := [
		{"type": "pong", "tiles": [0, 0, 0]},
		{"type": "pong", "tiles": [9, 9, 9]},
		{"type": "pong", "tiles": [18, 18, 18]},
		{"type": "pong", "tiles": [22, 22, 22]},
	]
	var three_only := Rules.score(2, -1, "self", [4, 4, 4, 9, 22], [], open_groups, 4)
	check(three_only.kind == "three" and three_only.per_payer == 12, "automatic self-draw can use three-gold scoring")
	var sparrow_not_dragon := Rules.score(2, -1, "self", [4, 4, 4, 9, 11], [], open_groups, 4)
	check(sparrow_not_dragon.kind == "sparrow", "dragon requires an independent group of three golds")
	var bamboo := [18, 19, 20, 18, 19, 20, 21, 22, 23, 24, 25, 26, 21, 22, 12, 26, 26]
	var pure := Rules.score(2, -1, "self", bamboo, [], [], 12)
	check(pure.kind == "pure" and pure.per_payer == 60, "gold can fill a pure hand in a different suit from the indicator")
	var mixed_meld := Rules.score(2, -1, "self", bamboo.slice(3), [], [{"type": "pong", "tiles": [0, 0, 0]}], 12)
	check(mixed_meld.kind == "self", "a meld from another suit disqualifies pure scoring")
	var unformed := Rules.score(2, -1, "three", bamboo.slice(3, 16) + [12, 12, 12], [], [], 12)
	check(unformed.kind == "three", "a single suit alone is insufficient for pure scoring")


func test_gold_gap() -> void:
	var waiting: Array = MIXED_WIN.slice(3) + [3, 5]
	check(Rules.gold_gap(waiting, 0, 4, [3, 5]), "literal gold gap completes the declared sequence")
	check(not Rules.gold_gap(waiting, 0, 4, [9, 11]), "the declared gap must have the gold in the middle")
	check(not Rules.gold_gap(waiting, 0, 34, [3, 5]), "flower gold cannot fill a literal gap")
	check(not Rules.gold_gap(waiting, 0, 4, [4, 6]), "declaration needs both actual non-gold gap tiles")
	var broken := waiting.duplicate()
	broken[0] = 15
	check(not Rules.gold_gap(broken, 0, 4, [3, 5]), "the remainder of a declared gap must be a winning structure")
	var finished := Rules.score(2, -1, "goldGap", waiting + [4], [], [], 4)
	check(finished.kind == "goldGap" and finished.method == "self" and finished.deltas == [-48, -48, 144, -48],
		"a declared gold gap is a self-draw and uses 4P+40 with three payers")
	var grabbed := Rules.score(2, -1, "grab", waiting + [4], [], [], 4)
	check(grabbed.kind == "grab" and grabbed.per_payer == 6, "grabbing gold to fill a gap scores as grab gold")


func test_ai() -> void:
	var flower_hand := MIXED_GROUPS + [35, 36]
	var player := {"hand": flower_hand, "river": [], "melds": []}
	var flower_view := {"seat": 0, "players": [player], "indicator": 34, "gold": 34}
	var flower_discards := [{"type": "discard", "tile": 35}, {"type": "discard", "tile": 9}]
	for difficulty in ["easy", "normal", "hard"]:
		check(AI.choose(flower_view, flower_discards, difficulty) == flower_discards[1], "AI keeps flower gold over an ordinary discard at %s" % difficulty)
	check(AI.opening_value(MIXED_GROUPS.slice(0, 13) + [35, 36, 37], 34, false) == 40.0, "AI values three different seasonal golds as an opening win")
	player.hand = MIXED_WIN.slice(3) + [3, 5, 8]
	var gap_view := {"seat": 0, "players": [player], "indicator": 4, "gold": 4}
	var gap := {"type": "declareGoldGap", "tile": 8, "tiles": [3, 5]}
	check(AI.choose(gap_view, [{"type": "discard", "tile": 8}, gap]) == gap, "AI can announce a live gold gap")
	player.river = [4, 4, 4]
	check(AI.choose(gap_view, [gap, {"type": "discard", "tile": 8}]).type == "discard", "AI keeps normal options when every gold is already visible")


func test_ai_restricted_pong() -> void:
	# After the pong, only discarding 六筒 leaves a wait on 四条.
	var player := {"hand": [1, 1, 1, 14, 15, 15, 16, 16, 18, 18, 19, 19, 20, 20, 20, 22], "river": [], "melds": []}
	var view := {"seat": 0, "players": [player], "indicator": 26, "gold": 26}
	var pong := {"type": "pong", "tiles": [16, 16], "tile": 16}
	var skip := {"type": "pass"}
	check(AI.choose(view, [pong, skip], "easy") == pong, "AI would accept an unrestricted pong with a better discard")
	pong.discards = [14]
	check(AI.choose(view, [pong, skip], "easy") == skip, "AI values a restricted pong using only its legal follow-up discard")
