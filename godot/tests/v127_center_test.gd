extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")
const Art = preload("res://scripts/table_art.gd")

var failures := 0
var capture_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa="):
			capture_dir = argument.trim_prefix("--qa=")
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-v127-center-%d" % OS.get_process_id())
	root.add_child(desk)
	if not ("center_dial" in desk):
		check(false, "table has a center dial")
		desk.free()
		quit(failures)
		return

	desk.begin_game(desk.lobby.selections)
	check(not desk.center_dial.visible, "dealer dice are visible in the opening")
	desk.finish_dealer_roll()
	check(not desk.center_dial.visible, "the deal and gold animation keep the dial hidden")
	desk.skip_intro()
	desk.ai_timer.stop()
	desk.game = Game.new(14, 1, "normal", false, 2)
	desk.game.phase = "turn"
	desk.refresh()
	desk.ai_timer.stop()
	check(desk.center_dial.visible and desk.countdown_label.text.is_empty(), "solo uses the dial without a countdown")
	check(desk.center_dial.winds == ["东", "南", "西", "北"] and desk.seat_wind(0) == "东"
		and desk.seat_wind(desk.game.dealer) == "西" and desk.center_dial.active_seat == 2,
		"the west dealer does not change the east player's seat")
	await capture("solo-no-countdown")

	desk.show_lobby()
	desk.show_online()
	var game = Game.new(14, 1, "normal", true, 1)
	game.phase = "turn"
	game.current = 3
	var snapshot := {
		"phase": "playing", "view": game.view(2), "my_seat": 2, "owner": 0, "host_seat": 0,
		"stage": 1, "actor": 3, "remaining_ms": 11000, "turn_seconds": 15,
		"seats": [
			{"name": "玉兰", "kind": "human", "connected": true},
			{"name": "小松", "kind": "ai", "connected": true},
			{"name": "海棠", "kind": "human", "connected": true},
			{"name": "小竹", "kind": "ai", "connected": true}
		], "moves": []
	}
	desk.room._apply_snapshot(snapshot)
	check(not desk.center_dial.visible, "online opening keeps the tabletop dice visible")
	desk.skip_intro()
	check(desk.center_dial.winds == ["西", "北", "东", "南"], "view rotation keeps west at the bottom")
	check(desk.center_dial.active_seat == 1 and desk.countdown_label.text == "11",
		"shared clock accompanies the public north turn")
	var dealer_wind := desk.dynamic.get_node_or_null("SeatWind3") as Label
	var seat_record := desk.dynamic.get_node_or_null("SeatRecord3") as Label
	check(is_instance_valid(dealer_wind) and dealer_wind.text.begins_with("庄")
		and not dealer_wind.text.contains("南")
		and is_instance_valid(seat_record) and seat_record.text.begins_with("胡 ")
		and desk.center_dial._score_labels[0].text == "0",
		"seat plates drop the wind and show win/deal-in counts")
	check(desk.center_dial.format_score(10) == "+10" and desk.center_dial.format_score(-10) == "-10"
		and desk.center_dial.format_score(0) == "0", "counter scores use natural digits")
	desk.center_dial.set_scores([10, -10, 0, 0])
	check(desk.center_dial._score_labels[0].text == "+10"
		and desk.center_dial._score_labels[1].text == "-10"
		and desk.center_dial._score_labels[2].text == "0", "dial scores show signs without padding")
	desk.center_dial.set_scores([0, 0, 0, 0])
	desk.queue_action_banner("海棠", "碰")
	var banner_rect: Rect2 = desk.action_banner.get_rect()
	check(not banner_rect.intersects(Art.RIVERS[2]),
		"the action banner leaves the far river exposed")
	desk.clear_action_banner()
	await capture("online-countdown")

	snapshot.stage += 1
	snapshot.remaining_ms = 18100
	desk.room._apply_snapshot(snapshot)
	check(desk.countdown_label.text == "15", "temporary animation grace is excluded from visible seconds")
	snapshot.stage += 1
	snapshot.view.phase = "reaction"
	snapshot.view.last_discard = {"seat": 0, "tile": 2}
	desk.room._apply_snapshot(snapshot)
	check(desk.center_dial.active_seat == -1 and desk.countdown_label.text == "15",
		"claims show time without pointing to anyone")

	snapshot.stage += 1
	snapshot.view.phase = "robKong"
	snapshot.view.rob_tile = 2
	snapshot.moves = [{"type": "win", "kind": "rob", "id": "test"}, {"type": "pass", "id": "test-pass"}]
	desk.room._apply_snapshot(snapshot)
	var offer := desk.dynamic.get_node_or_null("RobKongOffer") as Control
	check(is_instance_valid(offer) and not offer.get_global_rect().intersects(desk.center_dial.get_global_rect()),
		"the rob-kong tile and timer occupy different areas")

	snapshot.reconnecting = true
	desk.room._apply_snapshot(snapshot)
	check(desk.countdown_label.text.is_empty() and desk.center_dial.active_seat == -1,
		"reconnecting clears stale time and active-seat cues")
	snapshot.reconnecting = false
	snapshot.remaining_ms = -1
	snapshot.turn_seconds = 0
	snapshot.view.phase = "turn"
	snapshot.moves = []
	desk.room._apply_snapshot(snapshot)
	check(desk.center_dial.visible and desk.countdown_label.text.is_empty(), "unlimited online has no digits")
	if failures == 0:
		print("v1.2.7 table directions and center clock passed")
	desk.free()
	quit(failures)
