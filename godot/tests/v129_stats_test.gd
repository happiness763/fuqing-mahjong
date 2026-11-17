extends SceneTree

const Stats = preload("res://scripts/stats.gd")
const Game = preload("res://scripts/game.gd")

var failures := 0
var root_dir := ""


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func entry(table_id: String, round_number: int, hand_id: int, winner: int, from_seat: int,
		method: String, kind: String, per_payer: int, finished := false, rank := 0) -> Dictionary:
	var deltas := [0, 0, 0, 0]
	if winner >= 0:
		if from_seat >= 0:
			deltas[from_seat] = -per_payer
			deltas[winner] = per_payer
		else:
			for seat in range(4):
				deltas[seat] = -per_payer if seat != winner else per_payer * 3
	var players: Array = []
	for seat in range(4):
		players.append({
			"hand": [], "melds": [], "flowers": [], "meld_counts":
				{"chow": 0, "pong": 0, "kong": 0, "addedKong": 0, "concealedKong": 0},
			"flower_count": 0, "gold_count": 0, "discarded_gold": false,
			"gold_discards": 0, "gold_gap": [], "pass_pong": 0, "pass_win": 0,
			"delta": deltas[seat], "score": 0, "is_dealer": seat == 0,
			"is_winner": seat == winner,
			"is_deal_in": seat == from_seat and method == "discard",
			"is_robbed": seat == from_seat and method == "rob",
		})
	players[0].meld_counts.pong = 1
	players[0].pass_pong = 1
	players[0].pass_win = 1
	players[0].gold_discards = 1
	players[0].flower_count = 1
	var result := {
		"kind": kind, "method": method, "winner": winner, "from": from_seat,
		"deltas": deltas, "base": 10, "base_points": 3, "flower_points": 1,
		"gold_points": 1, "multiplier": 1, "offset": 0, "per_payer": per_payer,
		"payers": [from_seat] if from_seat >= 0 else [1, 2, 3],
		"flowers": 1, "golds": 1, "normal_golds": 1, "flower_golds": 0,
		"exposed": 0, "concealed": 0,
	}
	var scores := [0, 0, 0, 0]
	for seat in range(4):
		scores[seat] = deltas[seat]
	return {
		"table_id": table_id, "round": round_number, "hand_id": hand_id,
		"mode": "single", "round_limit": 2, "difficulty": "normal", "luck": "normal",
		"dealer": 0, "duration_ms": 1000, "discards": 10, "tile_draws": 12,
		"remaining": 18, "result": result, "scores": scores,
		"table_finished": finished, "table_rank": rank, "standings": [],
		"gold": 0, "indicator": 1, "gold_dice": [1, 2], "gold_index": 0,
		"dealer_rolls": {}, "names": ["你", "阿岚", "阿榕", "阿屿"],
		"players": players, "winner_hand": [], "winner_melds": [], "winner_flowers": [],
	}


func run() -> void:
	root_dir = "user://stats_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_dir))
	var stats = Stats.new(root_dir)
	check(stats.totals().rounds == 0, "stats start empty")
	var first: Dictionary = entry("A", 1, 1, 0, -1, "self", "sparrow", 8)
	first.scores = [24, -8, -8, -8]
	stats.record_round(first)
	var totals: Dictionary = stats.totals()
	check(totals.rounds == 1 and totals.wins == 1, "first win is counted")
	check(totals.self_draws == 1 and totals.score == 24, "self draw and score")
	check(totals.patterns.get("sparrow", 0) == 1, "sparrow distribution")
	check(totals.melds.pong == 1 and totals.pass_pong == 1 and totals.gold_discards == 1,
		"viewer behavior counters")
	check(stats.unlocked("first_win") and stats.unlocked("first_sparrow"), "first win achievements")
	var second: Dictionary = entry("A", 2, 2, 1, 0, "discard", "self", 8)
	second.scores = [16, 0, -16, -16]
	stats.record_round(second)
	totals = stats.totals()
	check(totals.rounds == 2 and totals.wins == 1 and totals.deal_ins == 1, "deal-in is counted")
	check(totals.score == 16 and totals.loss_streak == 1, "loss streak and score")
	var summary: Dictionary = stats.table_summary("A")
	check(int(summary.rounds) == 2, "table summary rounds")
	check(int(summary.seats[0].wins) == 1 and int(summary.seats[0].deal_ins) == 1,
		"table summary player counts")
	check(int(summary.seats[1].wins) == 1, "table summary other player wins")
	var third: Dictionary = entry("A", 3, 3, 0, 2, "discard", "pure", 15, true, 1)
	third.scores = [31, 0, -31, -16]
	stats.record_round(third)
	var redeal: Dictionary = entry("A", 4, 4, -1, -1, "self", "firstCycleDraw", 0)
	stats.record_round(redeal)
	check(stats.totals().rounds == 3, "first-cycle redeal is not a completed round")
	check(stats.totals().first_cycle_draws == 1 and stats.totals().redeals == 1,
		"first-cycle redeal is recorded")
	totals = stats.totals()
	check(totals.wins == 2 and totals.discard_wins == 1, "discard win is counted")
	check(totals.first_places == 1 and totals.tables_finished == 1, "finished table and rank")
	check(str(totals.records.best_pattern) == "正清", "best pattern record")
	check(stats.unlocked("first_pure"), "first pure achievement")
	summary = stats.table_summary("A")
	check(int(summary.seats[0].wins) == 2 and int(summary.seats[0].deal_ins) == 1,
		"end-of-table win and deal-in counts")
	check(int(summary.seats[2].deal_ins) == 1, "end-of-table payer count")
	check(int(summary.seats[0].score) == 31, "end-of-table score snapshot")
	check(stats.last_entry().hand_id == 4, "last entry is available")
	var loaded = Stats.new(root_dir)
	check(loaded.totals().rounds == 3 and loaded.totals().wins == 2, "stats persist")
	check(loaded.table_summary("A").seats[0].wins == 2, "table summary persists")
	for index in range(105):
		stats.record_round(entry("B", index + 1, 1000 + index, -1, -1, "self", "draw", 0))
	check(stats.recent_entries().size() == Stats.MAX_RECENT, "recent history is capped")
	check(stats.totals().draws == 105, "draws are counted")
	check(stats.unlocked("rounds_10") and stats.unlocked("rounds_50") and stats.unlocked("rounds_100"),
		"round milestones")
	stats.clear()
	check(stats.totals().rounds == 0 and stats.recent_entries().is_empty(), "clear resets stats")
	check(stats.achievements().is_empty(), "clear resets achievements")
	var game = Game.new(7, 1)
	check(int(game.view(0).get("discard_count", -1)) == 0, "game exposes discard counter")
	check(int(game.view(0).get("draw_count", -1)) == 0, "game exposes draw counter")
	var hand: Array = game.players[0].hand
	if not hand.is_empty():
		game.discard(0, hand[0])
		check(int(game.view(0).get("discard_count", 0)) == 1, "discard counter increments")
	var stats_path := root_dir.path_join("stats.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stats_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root_dir))
	if failures == 0:
		print("v1.2.9 stats tests passed")
	quit(failures)
