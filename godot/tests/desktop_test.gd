extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")
const Desk = preload("res://table.tscn")
const Tile = preload("res://scripts/tile_view.gd")
const Art = preload("res://scripts/table_art.gd")

var failures := 0
var output_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			output_dir = argument.trim_prefix("--qa-dir=")
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func click(control: Control) -> void:
	if not is_instance_valid(control):
		check(false, "requested control exists")
		return
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)


func by_text(parent: Node, value: String) -> Button:
	for control in parent.find_children("*", "Button", true, false):
		if control.text == value:
			return control
	return null


func capture(filename: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(screenshot.save_png(output_dir.path_join(filename)) == OK, "saved " + filename)


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-desktop-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	root.add_child(desk)
	check(ProjectSettings.get_setting("application/config/version") == "1.3.3a", "project version")
	check(is_instance_valid(desk.action_font) and desk.action_font.has_char("胡".unicode_at(0)),
		"action captions use the bundled display font")
	check(is_instance_valid(desk.fx) and desk.effects in ["full", "simple", "off"],
		"the effects layer is ready with a valid intensity")
	check(desk.fx.style_for({"kind": "dragon", "method": "self"}).get("tier", "") == "top",
		"dragon uses the full-screen top effect")
	check(desk.fx.style_for({"kind": "sparrow", "method": "discard"}).get("motif", "") == "feathers",
		"big patterns have their own motif")
	desk.preferences.update({"effects": "off"})
	desk.apply_saved_appearance()
	check(desk.fx.mode == "off" and not desk.board_art.ambience_enabled, "effects can be switched off")
	desk.preferences.update({"effects": "full"})
	desk.apply_saved_appearance()
	check(desk.fx.mode == "full", "effects can be restored")
	check(desk.game == null and desk.lobby.round_field.text == "25", "lobby defaults to 25 rounds")
	check(Art.FRAME == Rect2(3, 3, 1274, 794) and Art.FRAME.encloses(Art.FELT), "the wooden frame runs around the viewport")
	
	check(Art.CENTER == Vector2(640, 325), "the wind dial leaves room for the near discards and wall")
	check(Art.RIVERS[0].position.y > Art.CENTER.y + 72 and Art.RIVERS[0].end.y < 615,
		"bottom river fits between the dial and the hand controls")
	check(is_instance_valid(desk.menu_button) and desk.menu_button.tooltip_text == "菜单", "the corner icon opens the menu")
	check(not desk.header.find_children("*", "Label", true, false).any(func(node): return node.text == "福清麻将"), "title block is removed")
	check(desk.win_caption({"kind": "discard", "pattern": "sparrow"}) == "金雀", "win button names the big pattern")
	check(desk.win_caption({"kind": "self", "pattern": "pengpeng"}) == "碰碰胡", "self-draw button names pengpeng")
	check(desk.win_caption({"kind": "rob", "pattern": "sparrow"}) == "抢杠·金雀", "rob button names the method and pattern")
	check(desk.win_caption({"kind": "discard"}) == "胡", "a plain discard win keeps the plain caption")
	check(not desk.lobby.online_button.disabled, "online mode is available")
	check(desk.lobby.selections.difficulty == "normal" and desk.lobby.selections.luck == "normal",
		"default difficulty and luck")
	check(desk.lobby.menu_layer.visible and not desk.lobby.setup_layer.visible,
		"initial page shows the menu")
	var menu_buttons: Array = desk.lobby.menu_layer.find_children("*", "Button", true, false).map(
		func(node): return node.text)
	check(menu_buttons == ["开始游戏", "数据统计", "设置", "玩法规则"],
		"four initial choices are in the requested order")
	await capture("lobby-menu.png")
	click(desk.lobby.menu_stats_button)
	check(is_instance_valid(desk.stats_panel), "initial page opens data statistics")
	desk.close_modal(false)
	click(desk.lobby.menu_settings_button)
	check(is_instance_valid(desk.settings_panel), "initial page opens settings")
	desk.close_modal(false)
	click(desk.lobby.menu_rules_button)
	check(is_instance_valid(desk.modal), "initial page opens rules")
	click(by_text(desk.modal, "×"))
	check(not is_instance_valid(desk.modal), "initial rules page closes")
	click(desk.lobby.menu_start_button)
	check(desk.lobby.setup_layer.visible and not desk.lobby.menu_layer.visible,
		"start opens the table setup")
	click(desk.lobby.back_button)
	check(desk.lobby.menu_layer.visible and not desk.lobby.setup_layer.visible,
		"setup returns to the initial menu")
	click(desk.lobby.menu_start_button)
	await capture("lobby.png")
	desk.lobby.round_field.text = "33"
	desk.lobby.round_field.text_changed.emit("33")
	check(desk.lobby.start_button.disabled, "invalid round count blocks play")
	desk.lobby.slider.value = 11
	check(desk.lobby.round_field.text == "11" and not desk.lobby.start_button.disabled, "slider updates input")
	desk.lobby.round_field.text = "2"
	desk.lobby.round_field.text_changed.emit("2")
	check(desk.lobby.slider.value == 2, "input updates slider")
	click(desk.lobby.start_button)
	check(is_instance_valid(desk.dealer_roll_panel), "dealer roll opens on start")
	desk.finish_dealer_roll()
	check(desk.game != null and desk.game.round_limit == 2, "starts with selected round count")
	desk.close_modal(false)
	desk.skip_intro()
	for seed in range(43, 60):
		desk.game = Game.new(seed, 2)
		if desk.game.phase == "turn":
			break
	desk.last_revision = -1
	desk.log_lines.clear()
	desk.refresh(true)
	await create_timer(0.68).timeout
	check(desk.human_buttons.size() == 17, "17 starting tiles visible")
	check(desk.human_buttons[0].size == Vector2(56, 85), "the upright hand keeps a large click target")
	check(desk.human_buttons.back().position.x + 56 <= 1280, "17 tiles fit the window width")
	check(not desk.dynamic.find_children("*", "Label", true, false).any(func(node): return node.text in ["牌桌状态", "行牌动态", "本桌积分"]),
		"the right sidebar is removed")
	check(not desk.dynamic.find_children("*", "Label", true, false).any(func(node): return node.text == "出牌操作"),
		"operation hints are removed")
	check(not desk.dynamic.get_children().any(func(node): return node.get_script() == Tile and node.number == -1),
		"opponent hand counts have no face-down tile markers")
	check(desk.faces.size() == 42, "42 tile images loaded")
	check(desk.session_font.has_char("酋".unicode_at(0)) and desk.session_font.has_char("址".unicode_at(0)),
		"bundled font covers Chinese controls")
	for index in range(desk.faces.size()):
		var face = desk.faces[index]
		check(face != null and face.get_image().get_used_rect().has_area(), "tile has visible artwork %d" % index)
	var honor: Button = desk.tile(desk, 27, Rect2(0, 0, 56, 76), 26)
	check(not honor.find_children("*", "Label", false, false).size(), "honor tiles do not fall back to text")
	honor.queue_free()
	test_gold_display(desk)
	var board_art: Control = desk.get("board_art")
	var first_roll := Vector2i.ZERO
	if is_instance_valid(board_art):
		first_roll = board_art.dice
	check(first_roll.x in range(1, 7) and first_roll.y in range(1, 7), "two dice have legal faces")
	await capture("desk.png")

	click(desk.menu_button)
	check(desk.menu_open(), "menu opens")
	var menu_labels: Array = desk.menu_panel.find_children("*", "Button", true, false).map(func(node): return node.text)
	check(menu_labels.has("声音  开") and menu_labels.has("玩法规则") and menu_labels.has("返回首页"),
		"menu has sound, rules and leave")
	check(menu_labels.has("数据统计"), "menu has data statistics")
	check(menu_labels.has("AI 托管  关"), "menu has the AI delegation switch")
	check(not menu_labels.has("操作说明"), "the old operation hints are gone")
	click(by_text(desk.menu_panel, "玩法规则"))
	check(is_instance_valid(desk.modal), "rules opens")
	click(by_text(desk.modal, "×"))
	check(not is_instance_valid(desk.modal) and not desk.menu_open(), "rules closes")
	click(desk.menu_button)
	await capture("menu-ai.png")
	var stats_menu := by_text(desk.menu_panel, "数据统计")
	check(is_instance_valid(stats_menu), "statistics menu entry")
	click(stats_menu)
	check(is_instance_valid(desk.stats_panel), "menu opens the statistics page")
	if is_instance_valid(desk.stats_panel):
		desk.close_modal(false)
	click(desk.menu_button)
	click(by_text(desk.menu_panel, "声音  开"))
	check(desk.muted, "sound can be muted")
	click(desk.menu_button)
	click(by_text(desk.menu_panel, "声音  关"))
	check(not desk.muted, "sound can be enabled")
	click(desk.human_buttons[0])
	check(desk.selected_index == 0 and not desk.controls.discard.disabled, "click selects a tile")
	click(desk.controls.get("clear"))
	check(desk.selected_tile == -1 and desk.controls.discard.disabled, "cancel clears selected tile")
	click(desk.human_buttons[0])
	click(desk.controls.discard)
	check(desk.game.players[0].river.size() == 1, "discard enters river")
	var human_revision: int = desk.game.revision
	await create_timer(1.2).timeout
	check(desk.game.revision > human_revision, "AI acts automatically")
	if is_instance_valid(board_art):
		check(board_art.dice == first_roll, "dice stay fixed through a modal and discard")

	await finish_round(desk)
	check(desk.game.phase == "result", "round completes")
	if desk.fx_hold_active:
		check(not is_instance_valid(desk.modal) and desk.controls.has("skip"),
			"the win effect plays before the settlement opens")
		await create_timer(0.45).timeout
		await capture("win-hold.png")
		await create_timer(1.8).timeout
	check(is_instance_valid(desk.modal), "settlement opens after the win effect")
	check(is_instance_valid(desk.fx) and (desk.fx.win_active or not desk.fx.win_text.is_empty()),
		"the win effect plays with the settlement")
	if is_instance_valid(desk.modal):
		print("Desktop round finished: ", desk.result_title(desk.game.result))
		await capture("settlement.png")
		var round_stats_button := by_text(desk.modal, "本局统计")
		check(is_instance_valid(round_stats_button), "settlement links to round statistics")
		click(round_stats_button)
		check(is_instance_valid(desk.stats_panel), "round statistics opens")
		if is_instance_valid(desk.stats_panel):
			await create_timer(0.2).timeout
			await capture("stats-round.png")
			click(by_text(desk.stats_panel, "历史"))
			check(desk.stats_panel.tab == "history", "history tab opens")
			await create_timer(0.12).timeout
			await capture("stats-history.png")
			click(by_text(desk.stats_panel, "成就"))
			check(desk.stats_panel.tab == "achievements", "achievements tab opens")
			await create_timer(0.12).timeout
			await capture("stats-achievements.png")
			click(by_text(desk.stats_panel, "总览"))
			check(desk.stats_panel.tab == "overview", "overview tab opens")
			await create_timer(0.12).timeout
			await capture("stats-overview.png")
			desk.close_modal(false)
			desk.show_result()
			check(is_instance_valid(desk.modal), "settlement can be restored after statistics")
		click(by_text(desk.modal, "下一局"))
		check(desk.game.round_number == 2, "next round opens")
		desk.skip_intro()
		if is_instance_valid(board_art):
			var expected := Vector2i(int(desk.game.gold_dice[0]), int(desk.game.gold_dice[1]))
			check(board_art.dice == expected, "next round displays its own authoritative gold dice")
	await finish_round(desk)
	if desk.fx_hold_active:
		desk._finish_fx_hold()
		await process_frame
	check(desk.game.is_table_finished() and is_instance_valid(desk.modal), "last round opens table settlement")
	if is_instance_valid(desk.modal):
		await capture("final-scores.png")
		var final_labels: Array = desk.modal.find_children("*", "Label", true, false).map(
			func(node): return node.text)
		check(final_labels.has("胡牌") and final_labels.has("点炮"),
			"end-of-table settlement shows wins and deal-ins")
		click(by_text(desk.modal, "返回首页"))
		check(desk.game == null and desk.lobby.round_field.text == "2", "lobby preserves settings")
		click(desk.lobby.menu_start_button)
		click(desk.lobby.start_button)
		desk.finish_dealer_roll()
	desk.skip_intro()
	desk.ai_timer.stop()
	click(desk.menu_button)
	click(by_text(desk.menu_panel, "返回首页"))
	check(is_instance_valid(desk.modal), "leaving an active table asks for confirmation")
	if is_instance_valid(desk.modal):
		click(by_text(desk.modal, "继续本桌"))
	await test_multiple_chow(desk)
	test_concealed_kong_prompt(desk)
	test_draw_after_pass(desk)
	test_delegate(desk)
	await test_sea_presentation(desk)
	await test_flower_gold(desk)
	await test_gold_gap_declaration(desk)
	test_waiting_presentation(desk)
	await test_win_effect(desk)
	test_big_win_effects(desk)
	await test_scoring_presentation(desk)
	test_dense_board(desk)
	var roll_state := Rules.dealer_roll_state(RandomNumberGenerator.new())
	roll_state.start = 2
	roll_state.order = [2, 3, 0, 1]
	roll_state.round_seats = [2, 3, 0, 1]
	roll_state.dice = [[1, 2], [3, 4], [5, 6], [2, 2]]
	roll_state.sums = [3, 7, 11, 4]
	roll_state.winner = 2
	roll_state.finished = true
	desk.show_dealer_roll(roll_state, Callable())
	check(is_instance_valid(desk.dealer_roll_panel), "dealer roll panel opens")
	var roll_labels: Array = desk.dealer_roll_panel.find_children("*", "Label", true, false).map(
		func(node): return node.text)
	check(roll_labels.any(func(text): return text.contains("阿榕"))
		and roll_labels.any(func(text): return text.contains("11")),
		"winner and sums are shown")
	desk.finish_dealer_roll()
	check(desk.dealer_roll_panel == null, "dealer roll closes")
	var live_roll := Rules.dealer_roll_state(RandomNumberGenerator.new())
	desk.show_dealer_roll(live_roll, Callable())
	check(desk.dealer_roll_status.text.contains("掷骰"), "live dealer roll waits for a seat")
	while not live_roll.finished:
		desk._dealer_roll_apply_now()
	check(desk.dealer_roll_status.text.contains("坐庄"), "live dealer roll settles on a dealer")
	desk.finish_dealer_roll()
	check(desk.dealer_roll_panel == null, "live dealer roll panel closes")
	var online_state := Rules.dealer_roll_state(RandomNumberGenerator.new())
	online_state.start = 0
	online_state.order = [0, 1, 2, 3]
	online_state.round_seats = [0, 1, 2, 3]
	online_state.index = 0
	online_state.dice = [[], [], [], []]
	online_state.sums = [-1, -1, -1, -1]
	var online_snapshot := {"my_seat": 0, "seats": [
		{"name": "甲"}, {"name": "乙"}, {"name": "丙"}, {"name": "丁"}], "roll": online_state}
	desk.show_online_dealer_roll(online_snapshot)
	check(desk.dealer_roll_online and is_instance_valid(desk.dealer_roll_panel), "online roll panel opens")
	check(desk.dealer_roll_button.visible and desk.dealer_roll_status.text.contains("轮到你"),
		"local human can press roll")
	desk.close_online_dealer_roll()
	check(not desk.dealer_roll_online and desk.dealer_roll_panel == null, "online roll panel closes")
	if desk.draw_flower_active:
		desk._finish_flower_sequence()
	desk.game = Game.new(43, 2)
	desk.game.gold = desk.game.deal_initial_hands[0][0]
	desk.game.indicator = desk.game.gold
	desk.start_intro()
	check(desk.intro_active() and desk.local_moves().is_empty(), "intro blocks moves")
	check(desk.intro.status_text().begins_with("发牌"), "intro status is visible")
	check(not desk.dynamic.has_node("GoldDisplay"), "gold stays hidden while dealing")
	for index in range(4):
		desk.intro.advance()
		desk.refresh()
	check(desk.human_buttons.size() == 16, "four rounds reveal sixteen tiles")
	check(desk.human_buttons.all(func(button): return not button.golden), "gold stays hidden before the dice reveal")
	desk.intro.advance()
	desk.intro.advance()
	desk.refresh()
	check(desk.dynamic.has_node("GoldDisplay"), "gold appears after the dice reveal")
	check(desk.human_buttons.any(func(button): return button.number == desk.game.gold and button.golden),
		"hand marks the gold after the reveal")
	desk.skip_intro()
	check(not desk.intro_active() and desk.human_buttons.size() == desk.game.players[0].hand.size(),
		"skip restores the full hand")
	desk.game = Game.new(43, 2)
	desk.game.players[0].hand = [10, 22]
	desk.game.deal_initial_hands = [[27, 10], [], [], []]
	desk.game.deal_flowers = [{"round": 0, "seat": 0, "tile": 27}]
	desk.game.deal_draws = [{"round": 1, "seat": 0, "tile": 22, "flower": false}]
	desk.start_intro()
	for index in range(4):
		desk.intro.advance()
	desk.intro.advance()
	desk.intro.advance()
	desk.refresh()
	check(desk.intro.stage == "gold", "intro reaches the gold reveal")
	check(desk.human_buttons.any(func(button): return button.number == 27),
		"the dealing hand shows flowers before replacement")
	desk.advance_intro()
	check(desk.flower_active and desk.flower_preview, "opening flower preview starts")
	check(desk.flower_status_text == "摸到花", "opening flower shows the initial draw")
	check(desk.flower_preview_hand == [27, 10], "raw hand keeps the dealt flowers")
	desk.advance_flower()
	check(desk.flower_preview_hand == [10], "initial flower leaves the raw hand")
	desk.advance_flower()
	check(desk.flower_preview_hand.has(22), "replacement slides into the raw hand")
	check(desk.flower_timer.wait_time >= 0.23, "opening replacement has time to finish sliding before the board is rebuilt")
	desk.advance_flower()
	check(not desk.flower_active and desk.intro == null, "opening flower animation finishes the intro")
	desk.game = Game.new(43)
	desk.game.phase = "turn"
	desk.game.current = 0
	desk.game.gold = 26
	desk.game.indicator = 26
	desk.game.players[0].hand = [10, 16, 10]
	desk.game.drawn = 10
	desk.game.last_flowers = [{"round": 1, "seat": 0, "tile": 27}]
	desk.game.flower_revision = 1
	desk.last_flower_revision = 0
	desk.refresh()
	check(desk.draw_flower_active and desk.flower_active, "draw flower animation starts")
	check(desk.flower_status_text == "摸到花", "draw flower shows the drawn flower first")
	check(desk.local_moves().is_empty(), "draw flower animation blocks moves")
	desk.advance_flower()
	check(desk.flower_status_text == "第 1 次补花", "draw flower shows the replacement round")
	check(desk.human_buttons.map(func(button): return button.number) == [10, 16],
		"the settled hand stays in place during the flower")
	var first_slot: Vector2 = desk.human_buttons[0].position
	desk.advance_flower()
	check(desk.flower_active and desk.human_buttons.size() == 3,
		"the replacement arrives before the flower sequence unlocks the hand")
	check(desk.human_buttons[0].modulate.a == 1.0 and desk.human_buttons.back().modulate.a < 1.0,
		"only the newly drawn copy slides in when its face matches an existing tile")
	check(desk.human_buttons[0].position == first_slot, "the settled row does not recenter when the replacement appears")
	desk.refresh()
	check(desk.human_buttons.back().modulate.a < 1.0, "an intervening refresh does not snap the replacement into place")
	desk._finish_flower_sequence()
	check(not desk.draw_flower_active and not desk.flower_active, "draw flower animation ends")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(864, 540)
		await create_timer(0.65).timeout
		await capture("small.png")
		if OS.get_name() == "Windows":
			await test_fullscreen(desk)
	if failures == 0:
		print("Godot desktop checks passed: relocated gold, stable dice, settings and a two-round table.")
	desk.audio.stop()
	await create_timer(0.24).timeout
	desk.queue_free()
	await process_frame
	quit(failures)


func test_fullscreen(desk) -> void:
	root.size = Vector2i(1120, 560)
	await process_frame
	check(root.get_visible_rect().encloses(desk.menu_button.get_global_rect()),
		"window scaling keeps the menu visible")
	if is_instance_valid(desk.controls.get("discard")):
		check(root.get_visible_rect().encloses(desk.controls.discard.get_global_rect()),
			"window scaling keeps the discard control visible")
	var portrait := desk.dynamic.get_node_or_null("InteractionSeat2") as Button
	if is_instance_valid(portrait):
		click(portrait)
		check(is_instance_valid(desk.interactions.menu), "scaled layout keeps portrait interaction clickable")
		click(portrait)
		check(not is_instance_valid(desk.interactions.menu), "clicking the portrait again closes its menu")
	var windowed := Rect2i(root.position, root.size)
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_F11
	shortcut.pressed = true
	root.push_input(shortcut)
	await process_frame
	check(root.mode == Window.MODE_FULLSCREEN and desk.preferences.values.fullscreen,
		"F11 enters and remembers fullscreen")
	await capture("fullscreen.png")
	root.push_input(shortcut)
	await process_frame
	check(root.mode == Window.MODE_WINDOWED and Rect2i(root.position, root.size) == windowed
		and not desk.preferences.values.fullscreen, "F11 restores the previous window bounds")


func test_gold_display(desk) -> void:
	var gold_display: Control = desk.dynamic.get_node_or_null("GoldDisplay")
	check(is_instance_valid(gold_display), "gold display exists under the round counter")
	if not is_instance_valid(gold_display):
		return
	check(desk.GOLD_AREA.encloses(gold_display.get_rect()), "gold display sits under the round counter")
	var mark := gold_display.get_node_or_null("GoldMark") as Label
	var cards: Array = gold_display.find_children("*", "Button", false, false)
	var labels: Array = gold_display.find_children("*", "Label", false, false)
	check(is_instance_valid(mark) and mark.text == "金" and cards.size() == 1
		and cards[0].number == desk.game.gold and labels.size() == 1,
		"the gold display shows the gold mark and tile without naming it")


func test_flower_gold(desk) -> void:
	desk.game.gold = 34
	desk.game.indicator = 34
	desk.game.players[0].hand = [1, 35]
	desk.game.drawn = -1
	desk.refresh()
	var display: Control = desk.dynamic.get_node("GoldDisplay")
	var mark := display.get_node_or_null("GoldMark") as Label
	var cards: Array = display.find_children("*", "Button", false, false)
	var labels: Array = display.find_children("*", "Label", false, false)
	check(is_instance_valid(mark) and mark.text == "金" and labels.size() == 1,
		"flower gold keeps the gold mark without naming the tile")
	check(cards.size() == 4 and cards.all(func(card): return card.golden)
		and cards.any(func(card): return card.number == 37 and card.texture != null),
		"spring gold shows four readable gold tiles")
	check(not desk.human_buttons[0].golden and desk.human_buttons[1].golden,
		"summer is gold and numbered tiles are ordinary with a spring indicator")
	await capture("flower-gold.png")


func test_gold_gap_declaration(desk) -> void:
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 0
	game.gold = 4
	game.indicator = 4
	game.drawn = -1
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [0, 0, 0, 3, 5, 9, 10, 11, 12, 18, 18, 18, 21, 21, 21, 24, 24]
	desk.refresh()
	var declaration := by_text(desk.dynamic, "报听金坎")
	check(is_instance_valid(declaration), "own turn exposes a gold gap declaration")
	if not is_instance_valid(declaration):
		return
	click(declaration)
	var choices: Array = desk.modal.find_children("*", "Button", true, false).filter(
		func(node): return node.get_script() == Tile)
	check(choices.map(func(card): return card.number) == [9, 3, 5, 12, 3, 5],
		"unselected declaration shows both choices with their own discard")
	await capture("gold-gap-choices.png")
	click(by_text(desk.modal, "返回"))
	var selected: Button = desk.human_buttons.filter(func(card): return card.number == 12)[0]
	click(selected)
	click(by_text(desk.dynamic, "报听金坎"))
	check(is_instance_valid(desk.modal), "selected declaration still opens confirmation")
	if not is_instance_valid(desk.modal):
		return
	var cards: Array = desk.modal.find_children("*", "Button", true, false).filter(
		func(node): return node.get_script() == Tile)
	check(cards.map(func(card): return card.number) == [12, 3, 5], "confirmation shows the selected discard and both gap tiles")
	if cards.size() == 3:
		click(cards[0].get_parent())
	check(game.players[0].river == [12], "declaration discards the selected tile")
	var public_gap: Panel = desk.dynamic.get_node_or_null("GoldGap0")
	check(is_instance_valid(public_gap), "declared tiles stay visible beside the player's seat")
	await capture("gold-gap-declared.png")


func test_waiting_presentation(desk) -> void:
	var view: Dictionary = desk.board_view()
	view.phase = "reaction"
	view.current = 3
	view.actor = 2
	view.last_discard = {"seat": 3, "tile": 4}
	view.result = {}
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_controls(view, [])
	desk.draw_seat(view, 2, desk.SEAT_POSITIONS[2])
	var labels: Array = desk.dynamic.find_children("*", "Label", false, false)
	check(not labels.any(func(node): return node.text.contains("等待中") or node.text.contains("打出")),
		"claim waiting no longer uses a status line")
	check(desk.controls.is_empty(), "waiting on a claim has no action buttons")
	var seat_panel := desk.dynamic.get_children().filter(func(node): return node is Panel)[0] as Panel
	var style := seat_panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(style.border_color == desk.SEAT_IDLE_EDGE, "claim waiting does not highlight the responder")
	view.phase = "opening"
	view.opening = "grab"
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_controls(view, [])
	labels = desk.dynamic.find_children("*", "Label", false, false)
	check(not labels.any(func(node): return node.text.contains("等待中")),
		"opening subtype is hidden while waiting")

	view.phase = "robKong"
	view.rob_tile = 4
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_board(view, [], false, false)
	check(not desk.dynamic.has_node("RobKongOffer"), "waiting on a rob claim hides its tile")
	var rob_moves := [Game.action("win", {"kind": "rob"}), Game.action("pass")]
	desk.render_board(view, rob_moves, false, false)
	desk.render_controls(view, rob_moves)
	var offer: Panel = desk.dynamic.get_node_or_null("RobKongOffer")
	check(is_instance_valid(offer) and offer.find_children("*", "Button", false, false)[0].number == 4
		and desk.controls.win.text == "抢杠" and desk.controls.has("pass"),
		"responder sees the physical tile and the rob or pass controls")

	view.phase = "reaction"
	view.actor = 0
	view.last_discard = {"seat": 3, "tile": 4}
	view.result = {}
	var sparrow := Game.action("win", {"kind": "discard"})
	sparrow.pattern = "sparrow"
	var claim_moves := [sparrow, Game.action("pass")]
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_controls(view, claim_moves)
	check(desk.controls.win.text == "金雀" and desk.controls.pass.text == "过",
		"a big discard win shows its pattern on the claim button")


func test_win_effect(desk) -> void:
	desk.close_modal(false)
	desk.shown_round = -1
	desk.fx_result_hand = -1
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "reaction"
	game.players[3].river = [17, 22]
	game.pending = {"from": 3, "tile": 22}
	game._resolve_claim(2, {"type": "win", "kind": "discard"})
	desk.refresh()
	check(int(game.result.get("tile", -1)) == 22, "a discard win publishes the winning tile")
	check("win_source" in desk.fx and "win_target" in desk.fx, "the win effect uses both card anchors")
	if "win_source" in desk.fx and "win_target" in desk.fx:
		check(Art.RIVERS[3].encloses(desk.fx.win_source) and desk.fx.win_target.position.y < 125,
			"discard light starts at the claimed river slot and ends at the winning hand")
	await create_timer(0.22).timeout
	await capture("win-trail.png")
	await create_timer(0.20).timeout
	await capture("win-impact.png")
	desk._finish_fx_hold()
	desk.close_modal(false)

	desk.shown_round = -1
	desk.fx_result_hand = -1
	desk.game = Game.new(45)
	game = desk.game
	game.current = 0
	game.drawn = game.players[0].hand.back()
	game.finish_win(0, -1, "self")
	desk.refresh()
	check(int(game.result.get("tile", -1)) == game.drawn, "a self-draw result records the drawn tile")
	if "win_source" in desk.fx and "win_target" in desk.fx:
		check(not desk.fx.win_source.has_area() and desk.fx.win_target == desk.human_buttons.back().get_rect(),
			"self draw highlights the actual drawn card without a river trail")
	await create_timer(0.23).timeout
	await capture("win-self-impact.png")
	desk._finish_fx_hold()
	desk.close_modal(false)


func test_big_win_effects(desk) -> void:
	var big_win = desk.fx.big_win
	var view: Dictionary = desk.board_view()
	view.gold = 4
	view.players[0].hand = [3, 4, 4, 4, 5]
	view.players[0].gold_gap = [3, 5]
	view.result = {"winner": 0, "kind": "goldGap", "method": "goldGap", "tile": 4}
	for kind in ["dragon", "heaven", "pure", "dandiao", "sparrow", "goldGap", "three", "grab", "pengpeng", "idle"]:
		view.result.kind = kind
		desk.fx.play_win(view)
		check(desk.fx.big_win_active and is_equal_approx(desk.fx.win_duration, 2.0)
			and big_win.kind == kind, "each special pattern has a two-second presentation: " + kind)
	desk.fx.stop_win()
	view.result.kind = "goldGap"
	big_win.prepare(view, "goldGap", desk.GOLD_AREA)
	check(big_win.groups == [[3, 4, 5]], "gold gap places the winning gold between the declared tiles")
	view.players[0].hand = [1, 1, 2, 2, 4, 7, 7, 7]
	view.players[0].melds = []
	big_win.prepare(view, "pengpeng", desk.GOLD_AREA)
	check(big_win.groups == [[2, 2, 4], [7, 7, 7], [1, 1]],
		"all-triplets stage includes the actual gold substitute and pair")
	view.result.kind = "discard"
	view.result.method = "discard"
	desk.fx.play_win(view)
	check(not desk.fx.big_win_active and desk.fx.win_duration < 2.0, "ordinary wins retain the shorter presentation")
	desk.fx.stop_win()


func test_scoring_presentation(desk) -> void:
	desk.fx_hold_results = false
	desk.close_modal(false)
	desk.shown_round = -1
	desk.game = Game.new(43)
	var game = desk.game
	game.gold = 34
	game.indicator = 34
	game.players[0].hand = [0, 0, 0, 1, 1, 1, 3, 4, 5, 9, 9, 9, 18, 18, 18, 35, 36]
	game.players[0].flowers = [39]
	game.players[0].melds.clear()
	game.finish_win(0, 1, "rob")
	desk.last_revision = -1
	desk.refresh()
	var labels: Array = desk.modal.find_children("*", "Label", true, false)
	check(labels.any(func(node):
		return (node.text.contains("胡法 抢杠 · 最高分牌型 金雀") and node.text.contains("被抢杠者 阿岚")
			and node.text.contains("底分 3 ＋ 花分 1 ＋ 普通金 0 ＋ 花金 2 × 2 = 8")
			and node.text.contains("8 × 4 ＋ 40 = 每家应付 72 分"))
	), "settlement distinguishes robbing a kong from its best pattern and itemizes the score")
	check(desk.action_banner.get_node("Caption").text == "抢杠 · 金雀", "win banner also distinguishes method and pattern")
	await capture("rob-kong-scores.png")
	desk.close_modal(false)
	var view: Dictionary = desk.board_view()
	view.latest = {"type": "win", "seat": 1, "revision": 100,
		"previous": {"type": "discard", "seat": 0, "tile": 12, "revision": 99, "gold_gap": true}}
	view.result = {"method": "self", "kind": "self"}
	desk.log_lines.clear()
	desk.record(view)
	check(desk.log_lines.slice(0, 2) == ["阿岚 自摸", "你 打出 四筒 · 报听金坎"],
		"an automatic win preserves the discard and declaration that triggered it")
	desk.fx_hold_results = true


func finish_round(desk) -> void:
	desk.skip_intro()
	if desk.draw_flower_active:
		desk._finish_flower_sequence()
	var steps := 0
	while desk.game.phase != "result" and steps < 260:
		desk.ai_timer.stop()
		if desk.draw_flower_active:
			desk._finish_flower_sequence()
		if desk.game.actions(0).is_empty():
			desk.run_ai()
		elif desk.controls.has("discard"):
			var moves: Array = desk.game.actions(0)
			var discard: Dictionary = moves.filter(func(move): return move.type == "discard")[0]
			var card: Button = desk.human_buttons.filter(func(node): return node.number == discard.tile)[0]
			click(card)
			click(desk.controls.discard)
		elif desk.controls.has("pass"):
			click(desk.controls.pass)
		else:
			check(false, "found an available player control")
			break
		steps += 1
		await process_frame


func test_multiple_chow(desk) -> void:
	desk.close_modal(false)
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 3
	game.gold = 26
	game.players[3].hand = [4]
	game.players[0].hand = [2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 13, 16, 19, 21, 22, 24]
	game.players[1].hand = []
	game.players[2].hand = [4, 4]
	desk.refresh()
	desk.perform(3, game.actions(3).front())
	check(not desk.controls.has("chow"), "floating chow waits for higher priority AI")
	desk.perform(2, game.actions(2).back())
	check(desk.controls.chow.text == "吃" and desk.controls.chow.size.y >= 54
		and desk.controls.chow.size.x >= 110 and desk.controls.chow.position.y == desk.controls.pass.position.y,
		"large chow and pass buttons share the horizontal action row")
	await capture("floating.png")
	click(desk.controls.chow)
	check(is_instance_valid(desk.modal), "multiple chow choices open panel")
	var shown: Array = desk.modal.find_children("*", "Button", true, false).filter(
		func(node): return node.get_script() == Tile)
	check(shown.size() == 9, "three combinations display nine physical tiles")
	await capture("chow.png")
	click(by_text(desk.modal, "返回"))
	check(not is_instance_valid(desk.modal) and desk.controls.has("chow"), "back returns to same claim")
	click(desk.controls.chow)
	var first: Button = desk.modal.find_children("*", "Button", true, false).filter(
		func(node): return node.text.is_empty() and node.get_script() != Tile)[0]
	click(first)
	check(game.players[0].melds[0].tiles == [2, 3, 4], "choice claims intended sequence")
	var rotated: Array = desk.dynamic.find_children("*", "Button", true, false).filter(
		func(node): return node.get_script() == Tile and is_equal_approx(node.rotation_degrees, 90))
	check(rotated.size() == 1 and rotated[0].number == 4, "claimed tile lies sideways")
	var banner: Panel = desk.action_banner
	check(is_instance_valid(banner) and banner.get_node("Caption").text == "吃", "accepted chow appears as a large table prompt")
	desk.refresh()
	check(is_instance_valid(banner) and desk.action_banner == banner, "board refresh keeps the prompt visible")
	await capture("claim.png")


func test_concealed_kong_prompt(desk) -> void:
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 0
	game.gold = 26
	game.players[0].hand = [2, 2, 2, 2, 9, 9, 9, 9, 14]
	desk.refresh()
	check(desk.controls.kong.text == "杠", "concealed kongs use one plain Kong button")
	click(desk.controls.kong)
	check(is_instance_valid(desk.modal), "multiple kongs open picker")
	click(by_text(desk.modal, "返回"))
	var discard: Dictionary = game.actions(0).filter(func(move): return move.type == "discard" and move.tile == 14)[0]
	desk.perform(0, discard)
	game.draw_tile(0, false)
	desk.refresh()
	if desk.draw_flower_active:
		desk._finish_flower_sequence()
	check(desk.controls.has("kong") and desk.controls.kong.text == "杠", "deferred kong prompts on next turn")


func test_draw_after_pass(desk) -> void:
	desk.close_modal(false)
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 3
	game.gold = 26
	game.wall.resize(21)
	game.wall.fill(18)
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [2, 3, 7, 8, 10, 11, 12, 13, 13, 16, 19, 21, 22, 24, 25, 25]
	game.players[3].hand = [4]
	desk.refresh()
	desk.perform(3, game.actions(3).front())
	check(game.phase == "reaction", "discard offers a chow")
	desk.perform(0, game.actions(0).back())
	check(game.current == 0 and game.drawn == 18, "pass advances to player's draw")
	check(desk.human_buttons.back().modulate.a < 1.0, "draw after passed claim starts a tween")


func test_delegate(desk) -> void:
	desk.close_modal(false)
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 0
	game.gold = 26
	game.wall.resize(30)
	game.wall.fill(8)
	for player in game.players:
		player.hand = []
		player.melds = []
	game.players[0].hand = [2, 5, 7]
	desk.clear_selection()
	desk.refresh()
	check(not desk.ai_delegate, "delegation starts off")
	desk.set_delegate(true)
	check(desk.ai_delegate and desk.delegate_button.text.contains("开"),
		"the menu toggles AI delegation")
	desk.ai_timer.stop()
	desk.run_ai()
	check(game.players[0].river.size() == 1, "delegation discards for the local seat")
	desk.set_delegate(false)
	check(not desk.ai_delegate and desk.delegate_button.text.contains("关"),
		"delegation can be switched off again")


func test_sea_presentation(desk) -> void:
	desk.close_modal(false)
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "sea"
	game.current = 0
	game.sea_total = 4
	game.sea_done = 1
	game.sea_seat = 1
	game.sea_drawn = 10
	game.wall.resize(20)
	game.wall.fill(10)
	game.latest = {"type": "sea", "seat": 0, "tile": 10, "flower": false, "revision": game.revision + 1}
	desk.last_revision = -1
	desk.refresh()
	desk.sea_timer.stop()
	check(desk.dynamic.has_node("SeaNotice"), "the sea stage shows its draw notice")
	var labels: Array = desk.dynamic.find_children("*", "Label", true, false).map(func(node): return node.text)
	check(labels.has("海底 1/4"), "the round counter switches to the sea count")
	await capture("sea-stage.png")


func test_dense_board(desk) -> void:
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 0
	game.gold = 26
	game.players[0].hand = [4, 5]
	game.players[0].melds = [
		{"type": "chow", "tiles": [1, 2, 3], "from": 3, "claimed": 3},
		{"type": "pong", "tiles": [8, 8, 8], "from": 2, "claimed": 8},
		{"type": "addedKong", "tiles": [9, 9, 9, 9], "from": 1, "claimed": 9},
		{"type": "chow", "tiles": [17, 18, 19], "from": 3, "claimed": 17},
		{"type": "kong", "tiles": [22, 22, 22, 22], "from": 3, "claimed": 22},
	]
	for seat in range(4):
		var river: Array = []
		for index in range(28 if seat == 1 else 11):
			river.append((index + seat) % 27)
		game.players[seat].river = river
	desk.refresh()
	var tiles: Array = desk.dynamic.find_children("*", "Button", true, false).filter(
		func(node): return node.get_script() == Tile)
	for seat in range(4):
		var region: Rect2 = Art.RIVERS[seat]
		var prefix := "RiverTile%d_" % seat
		var shown: Array = tiles.filter(func(node): return node.name.begins_with(prefix)).filter(func(node):
			var center: Vector2 = node.position + node.size * 0.5
			var footprint_size: Vector2 = node.size
			var angle := int(node.rotation_degrees) % 360
			if angle == 90 or angle == 270:
				footprint_size = Vector2(node.size.y, node.size.x)
			return region.grow(2).encloses(Rect2(center - footprint_size * 0.5, footprint_size)))
		check(shown.size() == game.players[seat].river.size(), "long river fits region %d" % seat)
