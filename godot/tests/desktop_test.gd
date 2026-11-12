extends SceneTree

const Game = preload("res://scripts/game.gd")
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
	root.add_child(desk)
	check(ProjectSettings.get_setting("application/config/version") == "1.2.4", "project version")
	check(desk.game == null and desk.lobby.round_field.text == "15", "lobby defaults to 15 rounds")
	check(Art.FRAME == Rect2(28, 16, 1042, 768), "table frame fills the window")
	check(Art.FELT == Rect2(41, 29, 1016, 742), "felt follows the frame")
	check(Art.CENTER == Vector2(549, 400), "table center is recentered")
	check(Art.RIVERS[0] == Rect2(352, 505, 394, 101), "bottom river fits above the hand")
	check(is_instance_valid(desk.menu_button) and desk.menu_button.text == "菜单", "one menu button replaces the header row")
	check(not desk.header.find_children("*", "Label", true, false).any(func(node): return node.text == "福清麻将"), "title block is removed")
	check(desk.win_caption({"kind": "discard", "pattern": "sparrow"}) == "金雀", "win button names the big pattern")
	check(desk.win_caption({"kind": "self", "pattern": "pengpeng"}) == "碰碰胡", "self-draw button names pengpeng")
	check(desk.win_caption({"kind": "rob", "pattern": "sparrow"}) == "抢杠·金雀", "rob button names the method and pattern")
	check(desk.win_caption({"kind": "discard"}) == "胡", "a plain discard win keeps the plain caption")
	check(not desk.lobby.online_button.disabled, "online mode is available")
	check(desk.lobby.selections.difficulty == "normal" and desk.lobby.selections.luck == "normal",
		"default difficulty and luck")
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
	check(desk.human_buttons[0].size == Vector2(56, 76), "hand grows to 56x76")
	check(desk.human_buttons.back().position.x + 56 <= 1070, "17 tiles fit the frame width")
	check(is_instance_valid(desk.status_label) and desk.status_label.text.contains("轮到你出牌"),
		"turn status moves to the side panel")
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
	check(not menu_labels.has("操作说明"), "the old operation hints are gone")
	click(by_text(desk.menu_panel, "玩法规则"))
	check(is_instance_valid(desk.modal), "rules opens")
	click(by_text(desk.modal, "×"))
	check(not is_instance_valid(desk.modal) and not desk.menu_open(), "rules closes")
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
	check(desk.game.phase == "result" and is_instance_valid(desk.modal), "round completes and opens settlement")
	if is_instance_valid(desk.modal):
		print("Desktop round finished: ", desk.result_title(desk.game.result))
		await capture("settlement.png")
		var display_rng := RandomNumberGenerator.new()
		display_rng.seed = 20261111
		if is_instance_valid(board_art):
			desk._display_rng.seed = display_rng.seed
		click(by_text(desk.modal, "下一局"))
		check(desk.game.round_number == 2, "next round opens")
		if is_instance_valid(board_art):
			var expected := Vector2i(display_rng.randi_range(1, 6), display_rng.randi_range(1, 6))
			check(board_art.dice == expected, "next round samples new dice")
	await finish_round(desk)
	check(desk.game.is_table_finished() and is_instance_valid(desk.modal), "last round opens table settlement")
	if is_instance_valid(desk.modal):
		await capture("final-scores.png")
		click(by_text(desk.modal, "返回首页"))
		check(desk.game == null and desk.lobby.round_field.text == "2", "lobby preserves settings")
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
	await test_flower_gold(desk)
	await test_gold_gap_declaration(desk)
	test_waiting_presentation(desk)
	await test_scoring_presentation(desk)
	test_dense_board(desk)
	var roll := {"winner": 2, "dice": [[1, 2], [3, 4], [5, 6], [2, 2]], "sums": [3, 7, 11, 4], "rerolls": 0}
	desk.show_dealer_roll(roll, Callable())
	check(is_instance_valid(desk.dealer_roll_panel), "dealer roll panel opens")
	var roll_labels: Array = desk.dealer_roll_panel.find_children("*", "Label", true, false).map(
		func(node): return node.text)
	check(roll_labels.any(func(text): return text.contains("阿榕"))
		and roll_labels.any(func(text): return text.contains("11")),
		"winner and sums are shown")
	desk.finish_dealer_roll()
	check(desk.dealer_roll_panel == null, "dealer roll closes")
	desk.game = Game.new(43, 2)
	desk.start_intro()
	check(desk.intro_active() and desk.local_moves().is_empty(), "intro blocks moves")
	check(desk.status_label.text.begins_with("发牌"), "intro status is visible")
	check(not desk.dynamic.has_node("GoldDisplay"), "gold stays hidden while dealing")
	for index in range(4):
		desk.intro.advance()
		desk.refresh()
	check(desk.human_buttons.size() == 16, "four rounds reveal sixteen tiles")
	desk.skip_intro()
	check(not desk.intro_active() and desk.human_buttons.size() == desk.game.players[0].hand.size(),
		"skip restores the full hand")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(864, 540)
		await create_timer(0.65).timeout
		await capture("small.png")
	if failures == 0:
		print("Godot desktop checks passed: relocated gold, stable dice, settings and a two-round table.")
	desk.audio.stop()
	await create_timer(0.24).timeout
	desk.queue_free()
	await process_frame
	quit(failures)


func test_gold_display(desk) -> void:
	var gold_display: Panel = desk.dynamic.get_node_or_null("GoldDisplay")
	check(is_instance_valid(gold_display), "gold display exists in the upper right")
	if not is_instance_valid(gold_display):
		return
	check(Rect2(842, 52, 194, 112).encloses(gold_display.get_rect()), "gold display fits reference area")
	var number: int = desk.game.gold
	var tile: Button = gold_display.find_children("*", "Button", false, false)[0]
	check(tile.number == number and tile.golden, "gold display uses actual gold tile")
	var indicator: int = desk.game.indicator
	desk.game.indicator = -1
	desk.refresh()
	var names: Array = desk.dynamic.get_node("GoldDisplay").find_children("*", "Label", false, false)
	check(names.any(func(node): return node.text.ends_with("已抢")), "robbed gold stays marked in its display")
	desk.game.indicator = indicator
	desk.refresh()


func test_flower_gold(desk) -> void:
	desk.game.gold = 34
	desk.game.indicator = 34
	desk.game.players[0].hand = [1, 35]
	desk.game.drawn = -1
	desk.refresh()
	var display: Panel = desk.dynamic.get_node("GoldDisplay")
	var cards: Array = display.find_children("*", "Button", false, false)
	check(cards.size() == 4 and cards.all(func(card): return card.golden), "spring indicator displays four flower golds")
	check(cards.any(func(card): return card.number == 37 and card.texture != null), "flower gold has a readable face")
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
	desk.draw_seat(view, 2, Vector2(472, 115))
	var labels: Array = desk.dynamic.find_children("*", "Label", false, false)
	check(labels.any(func(node): return node.text.contains("阿屿打出 五万") and node.text.ends_with("等待中")),
		"claim waiting shows the discarded tile and a generic message")
	var seat_panel := desk.dynamic.get_children().filter(func(node): return node is Panel)[0] as Panel
	var style := seat_panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(style.border_color == Color("#678367"), "claim waiting does not highlight the responder")
	view.phase = "opening"
	view.opening = "grab"
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_controls(view, [])
	labels = desk.dynamic.find_children("*", "Label", false, false)
	check(labels.any(func(node): return node.text == "等待中"), "opening subtype is hidden while waiting")

	view.phase = "robKong"
	view.rob_tile = 4
	desk.clear_board()
	desk.dynamic = Control.new()
	desk.add_child(desk.dynamic)
	desk.render_board(view, [], false, false, -1)
	check(not desk.dynamic.has_node("RobKongOffer"), "waiting on a rob claim hides its tile")
	var rob_moves := [Game.action("win", {"kind": "rob"}), Game.action("pass")]
	desk.render_board(view, rob_moves, false, false, -1)
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


func test_scoring_presentation(desk) -> void:
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


func finish_round(desk) -> void:
	desk.skip_intro()
	var steps := 0
	while desk.game.phase != "result" and steps < 260:
		desk.ai_timer.stop()
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
	desk.perform(3, Game.action("discard", {"tile": 4}))
	check(not desk.controls.has("chow"), "floating chow waits for higher priority AI")
	desk.perform(2, game.actions(2).back())
	check(desk.controls.chow.text == "吃" and desk.controls.chow.size.y >= 64, "one large chow button")
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
	check(desk.controls.has("kong") and desk.controls.kong.text == "杠", "deferred kong prompts on next turn")


func test_draw_after_pass(desk) -> void:
	desk.close_modal(false)
	desk.game = Game.new(43)
	var game = desk.game
	game.phase = "turn"
	game.current = 3
	game.gold = 26
	game.wall.resize(20)
	game.wall.fill(18)
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [2, 3, 7, 8, 10, 11, 12, 13, 13, 16, 19, 21, 22, 24, 25, 25]
	game.players[3].hand = [4]
	desk.refresh()
	desk.perform(3, Game.action("discard", {"tile": 4}))
	check(game.phase == "reaction", "discard offers a chow")
	desk.perform(0, game.actions(0).back())
	check(game.current == 0 and game.drawn == 18, "pass advances to player's draw")
	check(desk.human_buttons.back().modulate.a < 1.0, "draw after passed claim starts a tween")


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
		var shown: Array = tiles.filter(func(node): return region.encloses(node.get_rect()))
		check(shown.size() == game.players[seat].river.size(), "long river fits region %d" % seat)
