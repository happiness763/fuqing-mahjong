extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")

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


func capture(filename: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir.path_join(filename)) == OK, "saved " + filename)


func drive_to_gold_roll(desk) -> void:
	desk.start_intro()
	while desk.intro.stage != "dice":
		desk.intro_timer.stop()
		desk.advance_intro()


func game_with_dice(pair: Array):
	for seed in range(200):
		var game := Game.new(seed, 2)
		if game.gold_dice == pair:
			return game
	check(false, "test has a seeded round with dice %s" % [pair])
	return Game.new(43, 2)


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-dice-%d" % OS.get_process_id())
	root.add_child(desk)
	desk.lobby.hide()
	desk.header.show()
	var roll := Rules.dealer_roll_state(RandomNumberGenerator.new())
	roll.start = 0
	roll.order = [0, 1, 2, 3]
	roll.round_seats = roll.order.duplicate()
	var snapshot := {"my_seat": 1, "seats": [{"name": "甲"}, {"name": "乙"}, {"name": "丙"}, {"name": "丁"}],
		"roll": roll, "last_rolled_seat": -1}
	desk.show_online_dealer_roll(snapshot)
	Rules.dealer_roll_apply(roll, RandomNumberGenerator.new(), func(): return 3)
	snapshot.last_rolled_seat = 0
	snapshot.roll_ready = false
	desk.show_online_dealer_roll(snapshot)
	check(desk.dealer_roll_animating, "dealer dice animate a host result")
	await create_timer(0.17).timeout
	await capture("dealer-rolling.png")
	await create_timer(0.25).timeout
	check(desk.dealer_roll_animating, "dealer dice still tumble after 0.42 seconds")
	await create_timer(0.39).timeout
	check(desk.board_art.dice == Vector2i(3, 3), "dealer dice settle on the authoritative pair")
	check(desk.dealer_roll_button.disabled, "local player waits for host to open the next throw")
	snapshot.roll_ready = true
	desk.show_online_dealer_roll(snapshot)
	check(not desk.dealer_roll_button.disabled and not desk.dealer_roll_animating, "host readiness unlocks the next throw without replay")
	await capture("dealer-settled.png")
	Rules.dealer_roll_apply(roll, RandomNumberGenerator.new(), func(): return 3)
	Rules.dealer_roll_apply(roll, RandomNumberGenerator.new(), func(): return 1)
	Rules.dealer_roll_apply(roll, RandomNumberGenerator.new(), func(): return 1)
	snapshot.last_rolled_seat = 3
	desk.close_online_dealer_roll()
	desk.show_online_dealer_roll(snapshot)
	check(desk.board_art.dice == Vector2i(1, 1) and not desk.dealer_roll_animating, "joining after a roll shows its final faces")
	Rules.dealer_roll_apply(roll, RandomNumberGenerator.new(), func(): return 3)
	snapshot.last_rolled_seat = 0
	desk.show_online_dealer_roll(snapshot)
	check(desk.dealer_roll_animating, "an identical pair still animates on a later throw")
	desk.close_online_dealer_roll()

	desk.game = game_with_dice([4, 6])
	drive_to_gold_roll(desk)
	await create_timer(0.15).timeout
	await capture("gold-rolling.png")
	check(desk.intro_active() and desk.intro.stage == "dice" and not desk.intro_gold, "wall gold stays hidden during the throw")
	await create_timer(0.55).timeout
	check(desk.intro_active() and desk.intro.stage == "dice" and not desk.intro_gold, "gold reveal waits for the dice to land")
	await create_timer(0.29).timeout
	check(desk.intro_active() and desk.intro.stage == "gold" and desk.intro_gold, "gold reveals after landing")
	check(desk.board_art.dice == Vector2i(4, 6), "settled gold dice agree with the wall reveal")
	await capture("gold-settled.png")

	desk.game = game_with_dice([2, 5])
	drive_to_gold_roll(desk)
	desk.skip_intro()
	check(desk.board_art.dice == Vector2i(2, 5) and desk.intro_gold, "skip shows final dice and gold together")
	await create_timer(0.8).timeout
	check(desk.board_art.dice == Vector2i(2, 5) and not desk.intro_active(), "cancelled rolls cannot change the final board")
	await capture("gold-skipped.png")
	if failures == 0:
		print("v1.2.6 dice tests passed")
	quit(1 if failures else 0)
