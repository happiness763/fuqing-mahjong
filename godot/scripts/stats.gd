extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const VERSION := 1
const MAX_RECENT := 100
const MAX_TABLE_IDS := 200
const PATTERN_ORDER := ["plain", "sparrow", "dragon", "pure", "pengpeng", "dandiao",
	"three", "grab", "heaven", "goldGap", "idle"]
const PATTERN_NAMES := {
	"plain": "平胡", "sparrow": "金雀", "dragon": "金龙", "pure": "正清",
	"pengpeng": "碰碰胡", "dandiao": "单吊", "three": "三金倒", "grab": "抢金",
	"heaven": "天胡", "goldGap": "金坎", "idle": "闲金",
}
const METHOD_ORDER := ["self", "discard", "rob", "heaven", "three", "grab", "goldGap", "idle"]
const METHOD_NAMES := {
	"self": "自摸", "discard": "点炮", "rob": "抢杠", "heaven": "天胡",
	"three": "三金倒", "grab": "抢金", "goldGap": "金坎", "idle": "闲金",
}
const ACHIEVEMENTS := {
	"first_win": "首次胡牌",
	"first_self": "首次自摸",
	"first_sparrow": "首次金雀",
	"first_dragon": "首次金龙",
	"first_pure": "首次正清",
	"first_pengpeng": "首次碰碰胡",
	"first_dandiao": "首次单吊",
	"first_three": "首次三金倒",
	"first_grab": "首次抢金",
	"first_heaven": "首次天胡",
	"first_goldGap": "首次金坎",
	"first_idle": "首次闲金",
	"rounds_10": "累计 10 局",
	"rounds_50": "累计 50 局",
	"rounds_100": "累计 100 局",
	"rounds_500": "累计 500 局",
	"wins_10": "累计胡牌 10 次",
	"wins_50": "累计胡牌 50 次",
	"wins_100": "累计胡牌 100 次",
}
const FIRST_PATTERN_ACHIEVEMENTS := {
	"sparrow": "first_sparrow", "dragon": "first_dragon", "pure": "first_pure",
	"pengpeng": "first_pengpeng", "dandiao": "first_dandiao",
	"three": "first_three", "grab": "first_grab", "heaven": "first_heaven",
	"goldGap": "first_goldGap", "idle": "first_idle",
}

var root_dir := "user://"
var path := ""
var data: Dictionary = {}


func _init(root: String = "user://") -> void:
	root_dir = root
	path = root_dir.path_join("stats.json")
	_load()


func _blank_totals() -> Dictionary:
	return {
		"rounds": 0, "wins": 0, "self_draws": 0, "discard_wins": 0, "rob_wins": 0,
		"special_wins": 0, "deal_ins": 0, "robbed": 0, "draws": 0,
		"first_cycle_draws": 0, "redeals": 0,
		"score": 0, "best_round": 0, "worst_round": 0,
		"win_streak": 0, "best_win_streak": 0, "loss_streak": 0, "worst_loss_streak": 0,
		"dealer_rounds": 0, "dealer_wins": 0, "dealer_streak": 0, "best_dealer_streak": 0,
		"dealer_continuations": 0,
		"duration_ms": 0, "discards": 0, "tile_draws": 0,
		"melds": {"chow": 0, "pong": 0, "kong": 0, "addedKong": 0, "concealedKong": 0},
		"flowers": 0, "golds": 0, "flower_golds": 0, "gold_discards": 0, "gold_gaps": 0,
		"pass_pong": 0, "pass_win": 0,
		"patterns": {}, "methods": {},
		"gold_hist": [0, 0, 0, 0, 0],
		"flower_hist": [0, 0, 0, 0, 0, 0, 0, 0, 0],
		"kong_hist": [0, 0, 0, 0, 0, 0, 0],
		"tables_started": 0, "tables_finished": 0,
		"first_places": 0, "second_places": 0, "third_places": 0, "fourth_places": 0,
		"rank_sum": 0, "ranked_tables": 0,
		"records": {
			"best_pattern": "", "best_pattern_rank": 0,
			"fastest_win_discards": -1, "fastest_win_round": 0, "fastest_win_ms": 0,
			"most_golds": 0, "most_flowers": 0,
			"best_table_rank": 0, "best_table_score": 0,
		},
	}


func _blank_data() -> Dictionary:
	return {
		"version": VERSION,
		"created_at": int(Time.get_unix_time_from_system()),
		"totals": _blank_totals(),
		"groups": {},
		"recent": [],
		"tables": {"started": [], "finished": []},
		"achievements": {},
	}


func _merge_totals(saved: Dictionary) -> Dictionary:
	var merged := _blank_totals()
	for key in merged.keys():
		if not saved.has(key):
			continue
		var value: Variant = saved[key]
		if typeof(merged[key]) == TYPE_DICTIONARY and value is Dictionary:
			var child: Dictionary = merged[key].duplicate()
			for sub in value:
				child[sub] = value[sub]
			merged[key] = child
		elif typeof(merged[key]) == TYPE_ARRAY and value is Array:
			var list: Array = merged[key].duplicate()
			for index in range(mini(list.size(), value.size())):
				list[index] = value[index]
			merged[key] = list
		else:
			merged[key] = value
	return merged


func _load() -> void:
	data = _blank_data()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var saved: Dictionary = parsed
	if int(saved.get("version", 0)) > VERSION:
		return
	var totals: Variant = saved.get("totals")
	if totals is Dictionary:
		data["totals"] = _merge_totals(totals)
	var groups: Variant = saved.get("groups")
	if groups is Dictionary:
		data["groups"] = groups
	var recent: Variant = saved.get("recent")
	if recent is Array:
		data["recent"] = recent.slice(maxi(0, recent.size() - MAX_RECENT))
	var tables: Variant = saved.get("tables")
	if tables is Dictionary:
		data["tables"] = {
			"started": Array(tables.get("started", [])).slice(-MAX_TABLE_IDS),
			"finished": Array(tables.get("finished", [])).slice(-MAX_TABLE_IDS),
		}
	var achievements: Variant = saved.get("achievements")
	if achievements is Dictionary:
		data["achievements"] = achievements


func _save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _has_entry(entry: Dictionary) -> bool:
	var table_id := str(entry.get("table_id", ""))
	var hand_id := int(entry.get("hand_id", -1))
	if table_id.is_empty() or hand_id < 0:
		return false
	for old: Variant in data.get("recent", []):
		if old is Dictionary and str(old.get("table_id", "")) == table_id \
				and int(old.get("hand_id", -1)) == hand_id:
			return true
	return false


func _touch_table(entry: Dictionary) -> void:
	var table_id := str(entry.get("table_id", ""))
	if table_id.is_empty():
		return
	var tables: Dictionary = data.tables
	var started: Array = tables.started
	if not table_id in started:
		started.append(table_id)
		if started.size() > MAX_TABLE_IDS:
			started.pop_front()
		data["totals"]["tables_started"] = int(data.totals.get("tables_started", 0)) + 1
	if bool(entry.get("table_finished", false)):
		var finished: Array = tables.finished
		if not table_id in finished:
			finished.append(table_id)
			if finished.size() > MAX_TABLE_IDS:
				finished.pop_front()
			data["totals"]["tables_finished"] = int(data.totals.get("tables_finished", 0)) + 1


func _unlock(achievement: String, entry: Dictionary) -> void:
	if ACHIEVEMENTS.has(achievement) and not data.achievements.has(achievement):
		data.achievements[achievement] = {
			"at": int(Time.get_unix_time_from_system()),
			"round": int(data.totals.get("rounds", 0)),
			"table_id": str(entry.get("table_id", "")),
		}


func _record_pattern(kind: String, entry: Dictionary) -> void:
	var rank := Rules.win_rank(kind)
	var records: Dictionary = data.totals.records
	if rank <= int(records.get("best_pattern_rank", 0)):
		return
	var key := _pattern_key(kind)
	records["best_pattern"] = PATTERN_NAMES.get(key, Rules.WIN_NAMES.get(kind, kind))
	records["best_pattern_rank"] = rank


func _pattern_key(kind: String) -> String:
	return "plain" if kind in ["self", "discard"] else kind


func record_round(entry: Dictionary) -> void:
	if entry.is_empty() or _has_entry(entry):
		return
	var result: Dictionary = entry.get("result", {})
	var winner := int(result.get("winner", -1))
	var from_seat := int(result.get("from", -1))
	var method := str(result.get("method", result.get("kind", "")))
	var kind := str(result.get("kind", method))
	var deltas: Array = result.get("deltas", [0, 0, 0, 0])
	var delta := int(deltas[0]) if deltas.size() > 0 else 0
	var totals: Dictionary = data.totals
	_touch_table(entry)
	if bool(entry.get("redeal", false)) or kind == "firstCycleDraw":
		totals["first_cycle_draws"] = int(totals.get("first_cycle_draws", 0)) + 1
		totals["redeals"] = int(totals.get("redeals", 0)) + 1
		data.recent.append(entry)
		while data.recent.size() > MAX_RECENT:
			data.recent.pop_front()
		_save()
		return
	totals["rounds"] = int(totals.get("rounds", 0)) + 1
	totals["score"] = int(totals.get("score", 0)) + delta
	totals["best_round"] = maxi(int(totals.get("best_round", 0)), delta)
	totals["worst_round"] = mini(int(totals.get("worst_round", 0)), delta)
	totals["duration_ms"] = int(totals.get("duration_ms", 0)) + int(entry.get("duration_ms", 0))
	var won := winner == 0
	if won:
		totals["wins"] = int(totals.get("wins", 0)) + 1
		totals["win_streak"] = int(totals.get("win_streak", 0)) + 1
		totals["loss_streak"] = 0
		totals["best_win_streak"] = maxi(int(totals.get("best_win_streak", 0)),
			int(totals.get("win_streak", 0)))
		if method == "self":
			totals["self_draws"] = int(totals.get("self_draws", 0)) + 1
		elif method == "discard":
			totals["discard_wins"] = int(totals.get("discard_wins", 0)) + 1
		elif method == "rob":
			totals["rob_wins"] = int(totals.get("rob_wins", 0)) + 1
		else:
			totals["special_wins"] = int(totals.get("special_wins", 0)) + 1
	elif winner >= 0:
		totals["loss_streak"] = int(totals.get("loss_streak", 0)) + 1
		totals["win_streak"] = 0
		totals["worst_loss_streak"] = maxi(int(totals.get("worst_loss_streak", 0)),
			int(totals.get("loss_streak", 0)))
	else:
		totals["win_streak"] = 0
		totals["loss_streak"] = 0
		totals["draws"] = int(totals.get("draws", 0)) + 1
		if kind == "firstCycleDraw":
			totals["first_cycle_draws"] = int(totals.get("first_cycle_draws", 0)) + 1
			totals["redeals"] = int(totals.get("redeals", 0)) + 1
	if method == "discard" and from_seat == 0:
		totals["deal_ins"] = int(totals.get("deal_ins", 0)) + 1
	if method == "rob" and from_seat == 0:
		totals["robbed"] = int(totals.get("robbed", 0)) + 1
	if int(entry.get("dealer", -1)) == 0:
		totals["dealer_rounds"] = int(totals.get("dealer_rounds", 0)) + 1
		if won:
			totals["dealer_wins"] = int(totals.get("dealer_wins", 0)) + 1
		if won or winner < 0:
			totals["dealer_streak"] = int(totals.get("dealer_streak", 0)) + 1
			totals["dealer_continuations"] = int(totals.get("dealer_continuations", 0)) + 1
			totals["best_dealer_streak"] = maxi(int(totals.get("best_dealer_streak", 0)),
				int(totals.get("dealer_streak", 0)))
		else:
			totals["dealer_streak"] = 0
	if won:
		var pattern := _pattern_key(kind)
		var patterns: Dictionary = totals.patterns
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
		var methods: Dictionary = totals.methods
		methods[method] = int(methods.get(method, 0)) + 1
		totals["flower_golds"] = int(totals.get("flower_golds", 0)) + int(result.get("flower_golds", 0))
		var gold_hist: Array = totals.gold_hist
		gold_hist[clampi(int(result.get("golds", 0)), 0, gold_hist.size() - 1)] += 1
		var flower_hist: Array = totals.flower_hist
		flower_hist[clampi(int(result.get("flowers", 0)), 0, flower_hist.size() - 1)] += 1
		var kong_hist: Array = totals.kong_hist
		kong_hist[clampi(int(result.get("exposed", 0)) + int(result.get("concealed", 0)), 0,
			kong_hist.size() - 1)] += 1
		_record_pattern(kind, entry)
		var records: Dictionary = totals.records
		if int(result.get("golds", 0)) > int(records.get("most_golds", 0)):
			records["most_golds"] = int(result.get("golds", 0))
		if int(result.get("flowers", 0)) > int(records.get("most_flowers", 0)):
			records["most_flowers"] = int(result.get("flowers", 0))
		var fastest := int(records.get("fastest_win_discards", -1))
		if fastest < 0 or int(entry.get("discards", 0)) < fastest:
			records["fastest_win_discards"] = int(entry.get("discards", 0))
			records["fastest_win_round"] = int(entry.get("round", 0))
			records["fastest_win_ms"] = int(entry.get("duration_ms", 0))
		if result.has("kind") and int(result.get("winner", -1)) == 0:
			var achievement := str(FIRST_PATTERN_ACHIEVEMENTS.get(kind, ""))
			if not achievement.is_empty():
				_unlock(achievement, entry)
	if won:
		_unlock("first_win", entry)
		if method == "self":
			_unlock("first_self", entry)
	var players: Array = entry.get("players", [])
	if not players.is_empty() and players[0] is Dictionary:
		var me: Dictionary = players[0]
		var meld_counts: Dictionary = me.get("meld_counts", {})
		var melds: Dictionary = totals.melds
		for meld_kind in melds.keys():
			melds[meld_kind] = int(melds.get(meld_kind, 0)) + int(meld_counts.get(meld_kind, 0))
		totals["gold_discards"] = int(totals.get("gold_discards", 0)) + int(me.get("gold_discards", 0))
		totals["pass_pong"] = int(totals.get("pass_pong", 0)) + int(me.get("pass_pong", 0))
		totals["pass_win"] = int(totals.get("pass_win", 0)) + int(me.get("pass_win", 0))
		totals["flowers"] = int(totals.get("flowers", 0)) + int(me.get("flower_count", 0))
		totals["golds"] = int(totals.get("golds", 0)) + int(me.get("gold_count", 0))
		totals["discards"] = int(totals.get("discards", 0)) + int(me.get("discard_count", 0))
		totals["tile_draws"] = int(totals.get("tile_draws", 0)) + int(me.get("draw_count", 0))
		if not Array(me.get("gold_gap", [])).is_empty():
			totals["gold_gaps"] = int(totals.get("gold_gaps", 0)) + 1
	if bool(entry.get("table_finished", false)):
		var rank := int(entry.get("table_rank", 0))
		if rank >= 1 and rank <= 4:
			var keys := ["first_places", "second_places", "third_places", "fourth_places"]
			totals[keys[rank - 1]] = int(totals.get(keys[rank - 1], 0)) + 1
			totals["rank_sum"] = int(totals.get("rank_sum", 0)) + rank
			totals["ranked_tables"] = int(totals.get("ranked_tables", 0)) + 1
			var records: Dictionary = totals.records
			if int(records.get("best_table_rank", 0)) == 0 or rank < int(records.get("best_table_rank", 0)):
				records["best_table_rank"] = rank
			var scores: Array = entry.get("scores", [])
			var viewer_score := int(scores[0]) if scores.size() > 0 else 0
			if viewer_score > int(records.get("best_table_score", 0)):
				records["best_table_score"] = viewer_score
	var key := _group_key(entry)
	var groups: Dictionary = data.groups
	var group: Dictionary = groups.get(key, {"rounds": 0, "wins": 0, "deal_ins": 0, "score": 0})
	group["rounds"] = int(group.get("rounds", 0)) + 1
	if won:
		group["wins"] = int(group.get("wins", 0)) + 1
	if method == "discard" and from_seat == 0:
		group["deal_ins"] = int(group.get("deal_ins", 0)) + 1
	group["score"] = int(group.get("score", 0)) + delta
	groups[key] = group
	for threshold in [10, 50, 100, 500]:
		if int(totals.get("rounds", 0)) >= threshold:
			_unlock("rounds_%d" % threshold, entry)
	for threshold in [10, 50, 100]:
		if int(totals.get("wins", 0)) >= threshold:
			_unlock("wins_%d" % threshold, entry)
	data.recent.append(entry)
	while data.recent.size() > MAX_RECENT:
		data.recent.pop_front()
	_save()


func _group_key(entry: Dictionary) -> String:
	return "%s|%d|%s|%s" % [
		str(entry.get("mode", "single")),
		int(entry.get("round_limit", 0)),
		str(entry.get("difficulty", "normal")),
		str(entry.get("luck", "normal")),
	]


func last_entry() -> Dictionary:
	var recent: Array = data.get("recent", [])
	return recent.back() if not recent.is_empty() else {}


func recent_entries() -> Array:
	return data.get("recent", [])


func groups() -> Dictionary:
	return data.get("groups", {})


func unlocked(achievement: String) -> bool:
	return data.get("achievements", {}).has(achievement)


func achievements() -> Dictionary:
	return data.get("achievements", {})


func totals() -> Dictionary:
	return data.get("totals", _blank_totals())


func table_summary(table_id: String) -> Dictionary:
	var seats: Array = []
	for seat in range(4):
		seats.append({"seat": seat, "wins": 0, "deal_ins": 0, "robbed": 0, "score": 0, "name": ""})
	var rounds := 0
	var latest: Dictionary = {}
	if table_id.is_empty():
		return {"table_id": "", "rounds": 0, "seats": seats, "latest": latest}
	for entry: Variant in data.get("recent", []):
		if not entry is Dictionary or str(entry.get("table_id", "")) != table_id:
			continue
		if bool(entry.get("redeal", false)) or str(entry.get("result", {}).get("kind", "")) == "firstCycleDraw":
			continue
		rounds += 1
		latest = entry
		var result: Dictionary = entry.get("result", {})
		var winner := int(result.get("winner", -1))
		var from_seat := int(result.get("from", -1))
		var method := str(result.get("method", result.get("kind", "")))
		for seat in range(4):
			if winner == seat:
				seats[seat].wins += 1
			if method == "discard" and from_seat == seat:
				seats[seat].deal_ins += 1
			if method == "rob" and from_seat == seat:
				seats[seat].robbed += 1
		var names: Array = entry.get("names", [])
		for seat in range(mini(4, names.size())):
			seats[seat].name = str(names[seat])
		var scores: Array = entry.get("scores", [])
		for seat in range(mini(4, scores.size())):
			seats[seat].score = int(scores[seat])
	return {"table_id": table_id, "rounds": rounds, "seats": seats, "latest": latest}


func clear() -> void:
	data = _blank_data()
	_save()


func pattern_name(key: String) -> String:
	return PATTERN_NAMES.get(key, key)


func method_name(key: String) -> String:
	return METHOD_NAMES.get(key, Rules.WIN_NAMES.get(key, key))
