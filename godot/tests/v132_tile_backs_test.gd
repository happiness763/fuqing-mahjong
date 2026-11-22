extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not ResourceLoader.exists("res://scripts/tile_backs.gd"):
		check(false, "shared back artwork exists")
		quit(failures)
		return
	var backs = load("res://scripts/tile_backs.gd")
	check(backs.NAMES == ["pig", "cat", "rabbit", "bear", "chick", "dog"], "six backs include the dog")
	for hand in range(1, 8):
		check(backs.for_hand(hand) == (hand - 1) % 6, "each new deal advances one back")
		check(backs.texture_for(hand - 1) != null, "all six textures load")
	var mapping = load("res://scripts/online_table_view.gd")
	var game = Game.new(43)
	game.hand_id = 6
	for viewer in range(4):
		var state := {"my_seat": viewer, "seats": [{}, {}, {}, {}], "view": game.view(viewer)}
		var rotated: Dictionary = mapping.from_room(state)
		check(backs.for_hand(rotated.hand_id) == 5, "all four online perspectives preserve dog")
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-backs-%d" % OS.get_process_id())
	root.add_child(desk)
	desk.lobby.hide()
	desk.game = Game.new(43)
	desk.start_intro()
	check(desk.wall_art.back_index == 0, "first opening uses pig")
	var back = desk.tile(desk, -1, Rect2(0, 0, 30, 40), -1)
	check(back.back_index == 0, "flip and flight factory uses the same pig")
	back.free()
	desk.skip_intro()
	desk.game.start_round()
	desk.start_intro()
	check(desk.wall_art.back_index == 1, "new hand uses cat")
	desk.skip_intro()
	desk.game.phase = "redeal"
	desk.game.restart_after_draw()
	desk.start_intro()
	check(desk.wall_art.back_index == 2, "same round redeal advances the back")
	desk.skip_intro()
	desk.online_view = desk.game.view(0)
	desk.online_view.hand_id = 6
	desk.online_view.seat_info = [
		{"name": "A"}, {"name": "B"}, {"name": "C"}, {"name": "D"}
	]
	desk.refresh()
	check(desk.wall_art.back_index == 5, "received authoritative hand uses dog")
	desk.refresh()
	check(desk.wall_art.back_index == 5, "repeated snapshot preserves back")
	back = desk.tile(desk, -1, Rect2(0, 0, 30, 40), -1)
	check(back.back_index == 5, "received hand also determines animated backs")
	back.free()
	desk.free()
	if failures == 0:
		print("v1.3.2 six tile backs passed")
	quit(failures)
