extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")
const Art = preload("res://scripts/table_art.gd")
const DRAW_NOTICE := "首巡四家同牌 · 流局"

var failures := 0
var capture_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			capture_dir = argument.trim_prefix("--qa-dir=")
	run.call_deferred()


func check(valid: bool, message: String) -> void:
	if not valid:
		failures += 1
		printerr("FAIL: ", message)


func has_draw_notice(desk: Control) -> bool:
	return desk.dynamic.find_children("*", "Label", true, false).any(
		func(node): return node.text == DRAW_NOTICE)


func draw_first_cycle(game) -> void:
	game.phase = "redeal"
	game.result = {"kind": "firstCycleDraw", "winner": -1, "from": -1, "deltas": [0, 0, 0, 0]}
	for player in game.players:
		player.river.append(4)
	game.last_discard = {"seat": 3, "tile": 4}
	game.note("discard", 3, 4)


func test_local(desk: Control) -> void:
	desk.lobby.hide()
	desk.header.show()
	desk.game = Game.new(164, 1, "normal", false, 2)
	desk.game.scores = [8, -1, 3, -10]
	desk.refresh()
	desk.selected_index = 0
	desk.selected_tile = int(desk.game.players[0].hand[0])
	desk.queue_action_banner("阿岚", "碰")
	draw_first_cycle(desk.game)
	desk.refresh(true)
	check(has_draw_notice(desk), "local redeal shows the first-cycle draw notice")
	var notice: Control = desk.dynamic.get_node_or_null("RedealNotice")
	if is_instance_valid(notice):
		var clears_rivers := true
		for seat in range(4):
			for slot_rect in desk.river_slots(seat, desk.game.players[seat].river.size()):
				if notice.get_rect().intersects(slot_rect):
					clears_rivers = false
		check(clears_rivers, "the draw notice leaves all four rivers visible")
	check(not is_instance_valid(desk.modal) and desk.controls.is_empty() and desk.local_moves().is_empty(),
		"local redeal has no settlement dialog or actions")
	check(desk.selected_index == -1 and not is_instance_valid(desk.action_banner),
		"local redeal clears the old selection and action banner")
	desk.show_result()
	check(not is_instance_valid(desk.modal), "a redeal cannot be opened as a settlement")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		check(capture.save_png(capture_dir.path_join("redeal-notice.png")) == OK, "saved the native draw notice")
	await create_timer(0.2).timeout
	check(desk.game.phase == "redeal", "local draw notice stays visible briefly")
	var deadline := Time.get_ticks_msec() + 3000
	while desk.game.phase == "redeal" and Time.get_ticks_msec() < deadline:
		await process_frame
	check(desk.game.phase in ["turn", "opening"] and desk.intro_active(),
		"local draw restarts automatically with the normal deal animation")
	check(desk.game.round_number == 1 and desk.game.dealer == 2 and desk.game.scores == [8, -1, 3, -10],
		"restarting the final round keeps the round, dealer and scores")
	check(not has_draw_notice(desk) and desk.game.players[3].river.is_empty(),
		"the new hand removes the notice and the old river")


func apply_online_hand(desk: Control, game, stage: int, remaining_ms := 12000) -> void:
	var view: Dictionary = game.view(0)
	var seats: Array = []
	for index in range(4):
		seats.append({"name": "牌手%d" % index, "kind": "human", "connected": true})
	desk.room._apply_snapshot({
		"phase": "playing", "stage": stage, "owner": 0, "my_seat": 0,
		"turn_seconds": 15, "remaining_ms": remaining_ms, "seats": seats, "view": view,
		"moves": [{"id": "stale", "type": "skip"}],
	})


func test_online(desk: Control) -> void:
	desk.show_lobby()
	desk.show_online()
	var game = Game.new(164, 1, "normal", true)
	apply_online_hand(desk, game, 1)
	desk.skip_intro()
	check(not desk.countdown_label.text.is_empty(), "online table exposes the turn clock once opening completes")
	desk.open_modal("旧动作", 280, 140)
	desk.modal_tracks_stage = true
	draw_first_cycle(game)
	apply_online_hand(desk, game, 2)
	check(has_draw_notice(desk), "online redeal shows the host's first-cycle draw notice")
	check(not is_instance_valid(desk.modal) and desk.controls.is_empty() and desk.local_moves().is_empty(),
		"online redeal closes a stale chooser without opening settlement or allowing stale moves")
	check(desk.countdown_label.text.is_empty(), "online redeal suppresses an old turn clock")
	check(not desk.online_view.players[1].has("hand"), "the redeal view keeps other hands concealed")

	game.start_round()
	apply_online_hand(desk, game, 3)
	check(desk.online_view.round == 1 and not has_draw_notice(desk) and desk.intro_active(),
		"a synchronized online update with the same round and a new hand starts the new deal")
	check(desk.human_buttons.is_empty() and desk.countdown_label.text.is_empty(),
		"the new deal hides hands and countdown until opening proceeds")
	desk.skip_intro()
	check(not desk.human_buttons.is_empty() and not desk.countdown_label.text.is_empty(),
		"online opening completion restores the current hand and clock")

	game.start_round()
	apply_online_hand(desk, game, 6, 910)
	check(not desk.intro_active() and not desk.human_buttons.is_empty() and desk.countdown_label.text == "01",
		"a stage jump to a hand near the deadline immediately reveals the playable hand and clock")


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-redeal-desktop-%d" % OS.get_process_id())
	root.add_child(desk)
	await test_local(desk)
	test_online(desk)
	desk.queue_free()
	await process_frame
	if failures == 0:
		print("v1.2.8 desktop redeal checks passed")
	quit(failures)
