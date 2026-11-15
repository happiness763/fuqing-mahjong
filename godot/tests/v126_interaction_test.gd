extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")

var failures := 0
var capture_path := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-props-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	root.add_child(desk)
	if not ("interactions" in desk):
		check(false, "table has an interaction controller")
		desk.free()
		quit(failures)
		return
	desk.begin_game(desk.lobby.selections)
	desk.finish_dealer_roll()
	desk.skip_intro()
	desk.ai_timer.stop()
	desk.game = Game.new(43)
	desk.game.phase = "turn"
	desk.game.current = 0
	desk.refresh()
	var controller = desk.interactions
	var revision: int = desk.game.action_revision
	var avatar := desk.dynamic.get_node_or_null("InteractionSeat2") as Button
	check(is_instance_valid(avatar), "other seats have interactive avatars")
	if is_instance_valid(avatar):
		avatar.pressed.emit()
	check(is_instance_valid(controller.menu) and controller.menu.get_child_count() == 5, "five choices near a seat")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path) == OK, "interaction preview captured")
	desk.flower_active = true
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(not is_instance_valid(controller.menu) and desk.flower_active,
		"escape closes the prop menu without skipping the flower animation")
	desk.cancel_flower_sequence()
	controller.send(2, "flower")
	check(controller.effects.get_child_count() == 1, "solo interaction reaches an AI avatar")
	controller.send(3, "egg")
	check(controller.effects.get_child_count() == 1, "cooldown limits repeat interaction")
	check(desk.game.action_revision == revision, "props do not advance the game")
	check(desk.preferences.update({"interaction_effects": false}) == OK, "local visual preference saves")
	controller.play(1, 0, "water")
	check(controller.effects.get_child_count() == 1, "muted visuals suppress new effects")
	check(desk.preferences.get_script().new(desk.preferences_root).values.interaction_effects == false,
		"the local visual setting survives restart")
	if failures == 0:
		print("v1.2.6 interaction tests passed")
	desk.free()
	quit(failures)
