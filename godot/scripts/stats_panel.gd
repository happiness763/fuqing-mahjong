extends Control

const Stats = preload("res://scripts/stats.gd")
const Rules = preload("res://scripts/rules.gd")

const INK := Color("#f3e5cb")
const MUTED := Color("#b0bd9e")
const GOLD := Color("#edc780")
const PANEL := Color("#1d382c")
const BORDER := Color("#3f5a49")
const TAB_KEYS := ["overview", "round", "history", "achievements"]
const TAB_NAMES := {"overview": "总览", "round": "本局", "history": "历史", "achievements": "成就"}

var desk
var tab := "overview"
var panel_width := 1040
var panel_height := 700
var content_width := 968.0
var scroll: ScrollContainer
var body: Control
var y := 0.0
var selected_entry: Dictionary = {}
var tab_buttons: Dictionary = {}
var clear_button: Button
var clear_armed := false


func setup(table, initial_tab := "overview", entry := {}) -> void:
	desk = table
	var parent := get_parent()
	if parent is Control:
		panel_width = int(parent.size.x)
		panel_height = int(parent.size.y)
	size = Vector2(panel_width, panel_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab = initial_tab if initial_tab in TAB_KEYS else "overview"
	selected_entry = entry if entry is Dictionary else {}
	_build_tabs()
	_refresh()


func _build_tabs() -> void:
	for index in range(TAB_KEYS.size()):
		var key: String = TAB_KEYS[index]
		var node: Button = desk.button(self, TAB_NAMES[key], Rect2(24 + index * 118, 86, 108, 34),
			_switch_tab.bind(key))
		tab_buttons[key] = node
	clear_button = desk.button(self, "清空统计", Rect2(panel_width - 144, 86, 120, 34), _clear_stats)
	clear_button.add_theme_font_size_override("font_size", 13)


func _update_tabs() -> void:
	for key in tab_buttons:
		var node: Button = tab_buttons[key]
		node.add_theme_color_override("font_color", GOLD if key == tab else INK)
	clear_button.text = "再点一次确认" if clear_armed else "清空统计"
	clear_button.add_theme_color_override("font_color", GOLD if clear_armed else INK)


func _switch_tab(key: String) -> void:
	tab = key
	clear_armed = false
	if key == "round":
		selected_entry = {}
	_refresh()


func _clear_stats() -> void:
	if not clear_armed:
		clear_armed = true
		_update_tabs()
		return
	desk.stats.clear()
	clear_armed = false
	selected_entry = {}
	_refresh()


func _refresh() -> void:
	if is_instance_valid(scroll):
		scroll.queue_free()
		scroll = null
	scroll = ScrollContainer.new()
	scroll.position = Vector2(24, 132)
	scroll.size = Vector2(panel_width - 48, panel_height - 176)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body)
	content_width = panel_width - 72.0
	y = 0.0
	if tab == "overview":
		_overview()
	elif tab == "round":
		_round()
	elif tab == "history":
		_history()
	else:
		_achievements()
	body.custom_minimum_size = Vector2(content_width, y + 24)
	body.size = Vector2(content_width, y + 24)
	_update_tabs()


func _label(copy: String, rect: Rect2, font_size := 14, color := MUTED,
		align := HORIZONTAL_ALIGNMENT_LEFT, display := false, wrap := false) -> Label:
	var node: Label = desk.label(body, copy, rect, font_size, color, align, display)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


func _section(copy: String) -> void:
	_label(copy, Rect2(0, y, content_width, 30), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += 38


func _line(copy: String, font_size := 14, color := MUTED, height := 22) -> void:
	_label(copy, Rect2(0, y, content_width, height), font_size, color)
	y += height + 3


func _kv(key: String, value: String, key_width := 260.0) -> void:
	_label(key, Rect2(0, y, key_width, 22), 14, MUTED)
	_label(value, Rect2(key_width, y, content_width - key_width, 22), 14, INK,
		HORIZONTAL_ALIGNMENT_RIGHT)
	y += 25


func _card(x: float, card_y: float, width: float, height: float, title: String,
		value: String, sub: String) -> void:
	desk.panel(body, Rect2(x, card_y, width, height), PANEL, BORDER, 8)
	_label(title, Rect2(x + 12, card_y + 9, width - 24, 18), 12, MUTED)
	_label(value, Rect2(x + 12, card_y + 26, width - 24, 28), 22, INK,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(sub, Rect2(x + 12, card_y + 56, width - 24, 18), 11, MUTED)


func _percent(part: int, total: int) -> String:
	if total <= 0:
		return "0%"
	return "%d%%" % roundi(100.0 * part / total)


func _points(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _duration(milliseconds: int) -> String:
	if milliseconds <= 0:
		return "0 秒"
	var seconds := int(round(milliseconds / 1000.0))
	if seconds < 60:
		return "%d 秒" % seconds
	var minutes := seconds / 60
	if minutes < 60:
		return "%d 分 %d 秒" % [minutes, seconds % 60]
	return "%d 时 %d 分" % [minutes / 60, minutes % 60]


func _date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var text := Time.get_datetime_string_from_unix_time(unix_time, true)
	return text.substr(0, 16)


func _history_time(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var text := Time.get_datetime_string_from_unix_time(unix_time, true)
	return text.substr(5, 11)


func _time_range(entry: Dictionary) -> String:
	var start := _history_time(int(entry.get("started_at", 0)))
	var finish := _history_time(int(entry.get("ended_at", 0)))
	if start.is_empty() and finish.is_empty():
		return "时间未记录"
	if start.is_empty():
		return finish
	if finish.is_empty():
		return start
	return start + " → " + finish


func _overview() -> void:
	var totals: Dictionary = desk.stats.totals()
	var rounds := int(totals.get("rounds", 0))
	var wins := int(totals.get("wins", 0))
	var total_score := int(totals.get("score", 0))
	var tables_started := int(totals.get("tables_started", 0))
	var tables_finished := int(totals.get("tables_finished", 0))
	_section("总览 · 本机")
	_line("数据只保存在本机，最近保留 %d 局；不统计 AI 的个人累计。" % Stats.MAX_RECENT, 13)
	var gap := 12.0
	var card_width := (content_width - gap * 3.0) / 4.0
	var card_y := y
	_card(0, card_y, card_width, 82, "总局数", str(rounds),
		"%d 桌 · 完成 %d" % [tables_started, tables_finished])
	_card(card_width + gap, card_y, card_width, 82, "胡牌率", _percent(wins, rounds),
		"胡牌 %d 次" % wins)
	_card((card_width + gap) * 2.0, card_y, card_width, 82, "场均分",
		_points(roundi(float(total_score) / rounds)) if rounds > 0 else "0",
		"总净分 %s" % _points(total_score))
	_card((card_width + gap) * 3.0, card_y, card_width, 82, "最长连胜",
		str(int(totals.get("best_win_streak", 0))), "当前 %s" % _streak_text(totals))
	card_y += 94
	_card(0, card_y, card_width, 82, "自摸率", _percent(int(totals.get("self_draws", 0)), wins),
		"自摸 %d 次" % int(totals.get("self_draws", 0)))
	_card(card_width + gap, card_y, card_width, 82, "点炮率",
		_percent(int(totals.get("deal_ins", 0)), rounds),
		"点炮 %d 次" % int(totals.get("deal_ins", 0)))
	_card((card_width + gap) * 2.0, card_y, card_width, 82, "最高单局",
		_points(int(totals.get("best_round", 0))),
		"最低 %s" % _points(int(totals.get("worst_round", 0))))
	_card((card_width + gap) * 3.0, card_y, card_width, 82, "第一名率",
		_percent(int(totals.get("first_places", 0)), int(totals.get("ranked_tables", 0))),
		"完成桌 %d" % int(totals.get("ranked_tables", 0)))
	y = card_y + 96.0

	_section("排名与连续")
	_kv("第一名 / 第二名 / 第三名 / 第四名", "%d / %d / %d / %d" % [
		int(totals.get("first_places", 0)), int(totals.get("second_places", 0)),
		int(totals.get("third_places", 0)), int(totals.get("fourth_places", 0))])
	_kv("平均名次", "%.2f" % (float(totals.get("rank_sum", 0)) /
		maxf(1.0, float(totals.get("ranked_tables", 0)))))
	_kv("当前连续", _streak_text(totals))
	_kv("最长连胜 / 最长连败", "%d / %d" % [
		int(totals.get("best_win_streak", 0)), int(totals.get("worst_loss_streak", 0))])
	_kv("庄家局数 / 庄家胜率 / 连庄次数 / 最长连庄", "%d / %s / %d / %d" % [
		int(totals.get("dealer_rounds", 0)),
		_percent(int(totals.get("dealer_wins", 0)), int(totals.get("dealer_rounds", 0))),
		int(totals.get("dealer_continuations", 0)),
		int(totals.get("best_dealer_streak", 0))])

	_section("时间与行牌")
	_kv("总对局时长 / 平均每局", "%s / %s" % [
		_duration(int(totals.get("duration_ms", 0))),
		_duration(int(round(float(totals.get("duration_ms", 0)) / maxi(1, rounds))))])
	_kv("总出牌 / 平均每局", "%d / %.1f" % [
		int(totals.get("discards", 0)), float(totals.get("discards", 0)) / maxi(1, rounds)])
	_kv("总摸牌 / 平均每局", "%d / %.1f" % [
		int(totals.get("tile_draws", 0)), float(totals.get("tile_draws", 0)) / maxi(1, rounds)])

	_section("模式与设置")
	var groups: Dictionary = desk.stats.groups()
	var by_mode := {"single": {"rounds": 0, "wins": 0, "score": 0},
		"online": {"rounds": 0, "wins": 0, "score": 0}}
	for key in groups:
		var parts: PackedStringArray = str(key).split("|")
		var mode: String = parts[0] if parts.size() > 0 else "single"
		if not by_mode.has(mode):
			by_mode[mode] = {"rounds": 0, "wins": 0, "score": 0}
		var group: Dictionary = groups[key]
		var current: Dictionary = by_mode[mode]
		current["rounds"] = int(current.get("rounds", 0)) + int(group.get("rounds", 0))
		current["wins"] = int(current.get("wins", 0)) + int(group.get("wins", 0))
		current["score"] = int(current.get("score", 0)) + int(group.get("score", 0))
		by_mode[mode] = current
	for mode in ["single", "online"]:
		var group: Dictionary = by_mode.get(mode, {"rounds": 0, "wins": 0, "score": 0})
		_kv("单机" if mode == "single" else "联机", "%d 局 · 胡 %d · 胡率 %s · 均分 %s" % [
			int(group.get("rounds", 0)), int(group.get("wins", 0)),
			_percent(int(group.get("wins", 0)), int(group.get("rounds", 0))),
			_points(roundi(float(group.get("score", 0)) / maxi(1, int(group.get("rounds", 0)))))])
	var shown := 0
	for key in groups:
		if shown >= 10:
			break
		var group: Dictionary = groups[key]
		if int(group.get("rounds", 0)) <= 0:
			continue
		_kv("  " + _group_text(str(key)), "%d 局 · 胡 %d · 均分 %s" % [
			int(group.get("rounds", 0)), int(group.get("wins", 0)),
			_points(roundi(float(group.get("score", 0)) / maxi(1, int(group.get("rounds", 0)))))])
		shown += 1

	_section("最近战绩")
	var recent: Array = desk.stats.recent_entries()
	if recent.is_empty():
		_line("还没有记录。打完一局后会出现在这里。")
	else:
		var last_ten := recent.slice(maxi(0, recent.size() - 10))
		var marks := ""
		var wins_ten := 0
		var score_ten := 0
		for entry in last_ten:
			var result: Dictionary = entry.get("result", {})
			var winner := int(result.get("winner", -1))
			var delta: Array = result.get("deltas", [0, 0, 0, 0])
			if winner == 0:
				marks += "胜 "
				wins_ten += 1
			elif winner < 0:
				marks += "流 "
			else:
				marks += "负 "
			if delta.size() > 0:
				score_ten += int(delta[0])
		_kv("最近 10 局", marks.strip_edges())
		_kv("最近 10 局胡牌 / 净分", "%d / %s" % [wins_ten, _points(score_ten)])
		var last_fifty := recent.slice(maxi(0, recent.size() - 50))
		var wins_fifty := 0
		var score_fifty := 0
		for entry in last_fifty:
			var result: Dictionary = entry.get("result", {})
			if int(result.get("winner", -1)) == 0:
				wins_fifty += 1
			var delta: Array = result.get("deltas", [0, 0, 0, 0])
			if delta.size() > 0:
				score_fifty += int(delta[0])
		_kv("最近 50 局胡牌 / 净分", "%d / %s" % [wins_fifty, _points(score_fifty)])

	_section("牌型分布")
	var patterns: Dictionary = totals.get("patterns", {})
	for key in Stats.PATTERN_ORDER:
		var count := int(patterns.get(key, 0))
		if count == 0:
			continue
		_kv(desk.stats.pattern_name(key), "%d 次 · 占胡牌 %s" % [count, _percent(count, wins)])
	if wins == 0:
		_line("还没有胡牌记录。")

	_section("胡法分布")
	var methods: Dictionary = totals.get("methods", {})
	for key in Stats.METHOD_ORDER:
		var count := int(methods.get(key, 0))
		if count == 0:
			continue
		_kv(desk.stats.method_name(key), "%d 次" % count)

	_section("金、花与杠分布")
	_kv("单局金数", _histogram(totals.get("gold_hist", []), ["0", "1", "2", "3", "4+"]))
	_kv("单局花数", _histogram(totals.get("flower_hist", []),
		["0", "1", "2", "3", "4", "5", "6", "7", "8+"]))
	_kv("单局杠数", _histogram(totals.get("kong_hist", []), ["0", "1", "2", "3", "4", "5", "6+"]))

	_section("最高记录")
	var records: Dictionary = totals.get("records", {})
	_kv("最高牌型", str(records.get("best_pattern", "—")))
	var common_key := ""
	var common_count := 0
	for key in Stats.PATTERN_ORDER:
		var count := int(patterns.get(key, 0))
		if count > common_count:
			common_count = count
			common_key = key
	_kv("最常见牌型", ("%s（%d 次）" % [desk.stats.pattern_name(common_key), common_count])
		if common_count > 0 else "—")
	_kv("单局最高 / 最低", "%s / %s" % [
		_points(int(totals.get("best_round", 0))), _points(int(totals.get("worst_round", 0)))])
	_kv("最快胡牌", _fastest_text(records))
	_kv("单局最多金 / 花", "%d / %d" % [
		int(records.get("most_golds", 0)), int(records.get("most_flowers", 0))])

	_section("行为统计")
	var melds: Dictionary = totals.get("melds", {})
	_kv("吃 / 碰 / 明杠 / 补杠 / 暗杠", "%d / %d / %d / %d / %d" % [
		int(melds.get("chow", 0)), int(melds.get("pong", 0)), int(melds.get("kong", 0)),
		int(melds.get("addedKong", 0)), int(melds.get("concealedKong", 0))])
	_kv("花牌 / 金 / 花金", "%d / %d / %d" % [
		int(totals.get("flowers", 0)), int(totals.get("golds", 0)),
		int(totals.get("flower_golds", 0))])
	_kv("打金 / 闲金", "%d / %d" % [
		int(totals.get("gold_discards", 0)), int(totals.get("gold_gaps", 0))])
	_kv("过碰 / 过胡", "%d / %d" % [
		int(totals.get("pass_pong", 0)), int(totals.get("pass_win", 0))])
	_kv("抢杠成功 / 被抢杠", "%d / %d" % [
		int(totals.get("rob_wins", 0)), int(totals.get("robbed", 0))])
	_kv("首巡同牌流局 / 重发", "%d / %d" % [
		int(totals.get("first_cycle_draws", 0)), int(totals.get("redeals", 0))])


func _streak_text(totals: Dictionary) -> String:
	var win_streak := int(totals.get("win_streak", 0))
	var loss_streak := int(totals.get("loss_streak", 0))
	if win_streak > 0:
		return "%d 连胜" % win_streak
	if loss_streak > 0:
		return "%d 连败" % loss_streak
	return "—"


func _group_text(key: String) -> String:
	var parts: PackedStringArray = key.split("|")
	if parts.size() < 4:
		return key
	var difficulty: String = {"easy": "简单", "normal": "普通", "hard": "困难"}.get(parts[2], parts[2])
	var luck: String = {"unlucky": "非酋", "normal": "普通", "lucky": "欧皇"}.get(parts[3], parts[3])
	return "%s · %s 局 · %s · %s" % [
		"联机" if parts[0] == "online" else "单机", parts[1], difficulty, luck]


func _histogram(values: Variant, labels: Array) -> String:
	if not values is Array:
		return "—"
	var parts: Array[String] = []
	for index in range(mini(labels.size(), values.size())):
		var count := int(values[index])
		if count > 0:
			parts.append("%s:%d" % [labels[index], count])
	return " · ".join(parts) if not parts.is_empty() else "—"


func _fastest_text(records: Dictionary) -> String:
	var discards := int(records.get("fastest_win_discards", -1))
	if discards < 0:
		return "—"
	return "第 %d 局 · %d 张出牌 · %s" % [
		int(records.get("fastest_win_round", 0)), discards,
		_duration(int(records.get("fastest_win_ms", 0)))]


func _round() -> void:
	var entry: Dictionary = selected_entry if not selected_entry.is_empty() else desk.stats.last_entry()
	if entry.is_empty():
		_section("本局统计")
		_line("还没有本局数据。")
		return
	var result: Dictionary = entry.get("result", {})
	var winner := int(result.get("winner", -1))
	var names: Array = entry.get("names", [])
	var method := str(result.get("method", result.get("kind", "")))
	var kind := str(result.get("kind", method))
	var deltas: Array = result.get("deltas", [0, 0, 0, 0])
	var scores: Array = entry.get("scores", [0, 0, 0, 0])
	var round_number := int(entry.get("round", 0))
	var round_limit := int(entry.get("round_limit", 0))
	_section("第 %02d / %02d 局 · %s" % [round_number, round_limit,
		"联机" if str(entry.get("mode", "single")) == "online" else "单机"])
	_line("%s · 庄家 %s · 用时 %s · 出牌 %d · 摸牌 %d · 剩余 %d 张" % [
		_time_range(entry), _name(names, int(entry.get("dealer", -1))),
		_duration(int(entry.get("duration_ms", 0))),
		int(entry.get("discards", 0)), int(entry.get("tile_draws", 0)),
		int(entry.get("remaining", 0))], 13)
	var title := "本局流局"
	if bool(entry.get("redeal", false)):
		title = "首巡同牌 · 流局重发"
	if winner >= 0:
		var caption: String = "胡牌" if method == "discard" else desk.win_name(method)
		title = "%s%s" % [_name(names, winner), caption]
		if kind != method and kind not in ["discard", "self"]:
			title += " · " + desk.win_name(kind)
		if int(result.get("from", -1)) >= 0:
			title += " · " + _name(names, int(result.from)) + ("被抢杠" if method == "rob" else "点炮")
	_line(title, 19, INK, 28)
	if winner >= 0:
		var flower_golds := int(result.get("flower_golds", 0))
		var ordinary_gold_points := int(result.get("gold_points", 0)) - flower_golds * 2
		_line("底分 %d ＋ 花分 %d ＋ 普通金 %d ＋ 花金 %d × 2 = %d" % [
			int(result.get("base_points", 0)), int(result.get("flower_points", 0)),
			ordinary_gold_points, flower_golds, int(result.get("base", 0))])
		var payers: Array = result.get("payers", [])
		var payer_names: Array[String] = []
		for payer in payers:
			payer_names.append(_name(names, int(payer)))
		_line("%d × %d ＋ %d = 每家 %d · 付款 %s" % [
			int(result.get("base", 0)), int(result.get("multiplier", 1)),
			int(result.get("offset", 0)), int(result.get("per_payer", 0)),
			"、".join(payer_names) if not payer_names.is_empty() else "—"])
	_line("本局：" + _delta_text(names, deltas))
	_line("累计：" + _score_text(names, scores))
	if bool(entry.get("table_finished", false)):
		_line("整桌结束，你的名次：第 %d 名" % int(entry.get("table_rank", 0)), 15, GOLD)
	_section("四家明细")
	var players: Array = entry.get("players", [])
	for seat in range(mini(4, players.size())):
		var player: Dictionary = players[seat]
		var marks: Array[String] = []
		if bool(player.get("is_winner", false)):
			marks.append("胡")
		if bool(player.get("is_deal_in", false)):
			marks.append("点炮")
		if bool(player.get("is_robbed", false)):
			marks.append("被抢杠")
		var meld_counts: Dictionary = player.get("meld_counts", {})
		var gold_gap := Array(player.get("gold_gap", []))
		_line("%s  本局 %s  累计 %s  %s  吃%d 碰%d 明杠%d 补杠%d 暗杠%d  花%d 金%d  打金%d 闲金%d 过碰%d 过胡%d" % [
			_name(names, seat), _points(int(deltas[seat])) if seat < deltas.size() else "0",
			_points(int(scores[seat])) if seat < scores.size() else "0",
			(" ".join(marks)) if not marks.is_empty() else "—",
			int(meld_counts.get("chow", 0)), int(meld_counts.get("pong", 0)),
			int(meld_counts.get("kong", 0)), int(meld_counts.get("addedKong", 0)),
			int(meld_counts.get("concealedKong", 0)), int(player.get("flower_count", 0)),
			int(player.get("gold_count", 0)), int(player.get("gold_discards", 0)),
			1 if not gold_gap.is_empty() else 0,
			int(player.get("pass_pong", 0)), int(player.get("pass_win", 0))], 13, MUTED, 24)
	var meld_lines: Array[String] = []
	for seat in range(mini(4, players.size())):
		var melds: Array = players[seat].get("melds", [])
		var meld_parts: Array[String] = []
		for meld in melds:
			meld_parts.append("%s %s" % [
				Rules.MELD_NAMES.get(str(meld.get("type", "")), str(meld.get("type", ""))),
				"、".join(Array(meld.get("tiles", [])).map(Rules.tile_name))])
		if not meld_parts.is_empty():
			meld_lines.append("%s：%s" % [_name(names, seat), "；".join(meld_parts)])
	if not meld_lines.is_empty():
		_line("副露明细：" + "  ".join(meld_lines), 13, MUTED, 24)
	_section("牌面")
	var gold := int(entry.get("gold", -1))
	var indicator := int(entry.get("indicator", -1))
	_line("金牌 %s · 指示牌 %s · 开金骰子 %s · 翻金位置 %d" % [
		_tile_name(gold), _tile_name(indicator),
		_dice_text(entry.get("gold_dice", [])), int(entry.get("gold_index", -1))], 14)
	var rolls: Dictionary = entry.get("dealer_rolls", {})
	if not rolls.is_empty():
		_line("定庄掷骰：" + _dealer_roll_text(rolls, names), 13)
	var winner_hand: Array = entry.get("winner_hand", [])
	if winner >= 0 and not winner_hand.is_empty():
		_line("胡牌手牌", 15, INK)
		var hand_sorted := winner_hand.duplicate()
		hand_sorted.sort()
		var hand_x := 0.0
		for number in hand_sorted:
			desk.tile(body, int(number), Rect2(hand_x, y, 23, 32), gold)
			hand_x += 25.0
		y += 38
		var melds: Array = entry.get("winner_melds", [])
		if not melds.is_empty():
			var meld_text: Array[String] = []
			for meld in melds:
				meld_text.append("%s %s" % [Rules.MELD_NAMES.get(str(meld.get("type", "")), str(meld.get("type", ""))),
					"、".join(Array(meld.get("tiles", [])).map(Rules.tile_name))])
			_line("副露：" + "；".join(meld_text), 13)
		var flowers: Array = entry.get("winner_flowers", [])
		if not flowers.is_empty():
			_line("花牌：" + "、".join(flowers.map(Rules.tile_name)), 13)
	_section("过程与特殊")
	var kind_text := "正常胡牌"
	if kind == "firstCycleDraw":
		kind_text = "首巡四家同牌 · 流局重发"
	elif kind == "draw":
		kind_text = "牌墙耗尽 · 流局"
	elif method == "rob":
		kind_text = "抢杠胡"
	elif method == "discard":
		kind_text = "点炮胡"
	elif method == "self":
		kind_text = "自摸"
	_line("结果：" + kind_text)
	_line("本局统计会在结算时写入；重连或重新打开不会重复计数。", 12)


func _history() -> void:
	var recent: Array = desk.stats.recent_entries()
	_section("最近 %d 局" % recent.size())
	if recent.is_empty():
		_line("还没有记录。")
		return
	_line("点击任意一局查看完整统计。", 13)
	for index in range(recent.size() - 1, -1, -1):
		var entry: Dictionary = recent[index]
		var node: Button = desk.button(body, _history_text(entry), Rect2(0, y, content_width, 34),
			_open_history.bind(entry))
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node.add_theme_font_size_override("font_size", 13)
		y += 38.0


func _open_history(entry: Dictionary) -> void:
	selected_entry = entry
	tab = "round"
	clear_armed = false
	_refresh()


func _history_text(entry: Dictionary) -> String:
	var result: Dictionary = entry.get("result", {})
	var winner := int(result.get("winner", -1))
	var names: Array = entry.get("names", [])
	var round_number := int(entry.get("round", 0))
	var round_limit := int(entry.get("round_limit", 0))
	var delta: Array = result.get("deltas", [0, 0, 0, 0])
	var scores: Array = entry.get("scores", [0, 0, 0, 0])
	var copy := "第 %02d/%02d 局 · " % [round_number, round_limit]
	if winner < 0:
		copy += "首巡同牌重发" if bool(entry.get("redeal", false)) else "流局"
	else:
		var method := str(result.get("method", result.get("kind", "")))
		var kind := str(result.get("kind", method))
		copy += "%s %s" % [_name(names, winner), desk.win_name(method)]
		if kind != method and kind not in ["discard", "self"]:
			copy += "·" + desk.win_name(kind)
		if int(result.get("from", -1)) >= 0:
			copy += "（%s）" % _name(names, int(result.from))
	copy += " · 你 %s · 累计 %s" % [
		_points(int(delta[0])) if delta.size() > 0 else "0",
		_points(int(scores[0])) if scores.size() > 0 else "0"]
	var time_text := _history_time(int(entry.get("ended_at", 0)))
	if not time_text.is_empty():
		copy += " · " + time_text
	return copy


func _achievements() -> void:
	_section("成就")
	var earned: Dictionary = desk.stats.achievements()
	var unlocked_count := 0
	for id in Stats.ACHIEVEMENTS.keys():
		var is_unlocked := earned.has(id)
		if is_unlocked:
			unlocked_count += 1
		var text := ("✓ " if is_unlocked else "· ") + str(Stats.ACHIEVEMENTS[id])
		if is_unlocked:
			var record: Dictionary = earned[id]
			text += "  " + _date(int(record.get("at", 0)))
		_line(text, 14, GOLD if is_unlocked else MUTED, 21)
	_line("已解锁 %d / %d" % [unlocked_count, Stats.ACHIEVEMENTS.size()], 13)
	_section("最高记录")
	var totals: Dictionary = desk.stats.totals()
	var records: Dictionary = totals.get("records", {})
	_kv("最高牌型", str(records.get("best_pattern", "—")))
	_kv("单局最高 / 最低", "%s / %s" % [
		_points(int(totals.get("best_round", 0))), _points(int(totals.get("worst_round", 0)))])
	_kv("最快胡牌", _fastest_text(records))
	_kv("单局最多金 / 花", "%d / %d" % [
		int(records.get("most_golds", 0)), int(records.get("most_flowers", 0))])
	_kv("最长连胜 / 连败", "%d / %d" % [
		int(totals.get("best_win_streak", 0)), int(totals.get("worst_loss_streak", 0))])
	_kv("最长连庄", str(int(totals.get("best_dealer_streak", 0))))
	_kv("最佳整桌名次 / 最高整桌分", "%d / %s" % [
		int(records.get("best_table_rank", 0)), _points(int(records.get("best_table_score", 0)))])


func _name(names: Array, seat: int) -> String:
	if seat == 0:
		return "你"
	if seat >= 0 and seat < names.size():
		return str(names[seat])
	return "—"


func _delta_text(names: Array, deltas: Array) -> String:
	var parts: Array[String] = []
	for seat in range(mini(4, deltas.size())):
		parts.append("%s %s" % [_name(names, seat), _points(int(deltas[seat]))])
	return " · ".join(parts)


func _score_text(names: Array, scores: Array) -> String:
	var parts: Array[String] = []
	for seat in range(mini(4, scores.size())):
		parts.append("%s %s" % [_name(names, seat), _points(int(scores[seat]))])
	return " · ".join(parts)


func _dice_text(dice: Variant) -> String:
	if not dice is Array or dice.size() < 2:
		return "—"
	return "%d + %d = %d" % [int(dice[0]), int(dice[1]), int(dice[0]) + int(dice[1])]


func _dealer_roll_text(rolls: Dictionary, names: Array) -> String:
	var dice: Array = rolls.get("dice", [])
	var sums: Array = rolls.get("sums", [])
	if dice.size() < 4:
		return "—"
	var parts: Array[String] = []
	for seat in range(4):
		var pair: Array = dice[seat]
		if pair.size() >= 2:
			parts.append("%s %d+%d=%d" % [_name(names, seat),
				int(pair[0]), int(pair[1]), int(sums[seat]) if seat < sums.size() else 0])
	return " · ".join(parts)


func _tile_name(number: int) -> String:
	return Rules.tile_name(number) if number >= 0 else "—"
