extends SceneTree

const Desk = preload("res://table.tscn")
const Game = preload("res://scripts/game.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)


func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		root.push_input(event, true)


func run() -> void:
	var desk = Desk.instantiate()
	desk.preferences_root = OS.get_temp_dir().path_join("fuqing-v133c-%d" % OS.get_process_id())
	root.add_child(desk)
	var native = desk.get_node_or_null("BoardArt/NativeTable")
	check(is_instance_valid(native), "the normal table mounts the native board renderer")
	if not is_instance_valid(native):
		desk.free()
		quit(failures)
		return
	check(not native.visible, "native board is hidden on the start screen")
	desk.lobby.hide()
	desk.game = Game.new(43)
	desk.game.phase = "turn"
	desk.refresh()
	desk.ai_timer.stop()
	check(native.visible, "gameplay activates the native 3D board")
	check(desk.human_buttons.size() == 17, "native table shows all 17 opening tiles")
	for card in desk.human_buttons:
		check(card.projected_face.size() == 4, "the on-table button has four projected face points")
	var first = desk.human_buttons[0]
	var face_center := Vector2.ZERO
	for point in first.projected_face:
		face_center += point * 0.25
	var number: int = first.number
	click(first.get_global_transform() * face_center)
	check(desk.selected_index == 0 and desk.selected_tile == number,
		"selecting the projected tile picks the original hand index")
	var wall_bounds: Rect2 = native.project_rect(desk.TableLayout3D.wall_pose(70, desk.wall_art.dealer))
	check(desk._wall_source(70).is_equal_approx(wall_bounds.get_center()), "flights use the native wall slot")
	for seat in range(4):
		var bounds: Array[Rect2] = desk.river_slots(seat, 36)
		check(bounds.size() == 36, "six rows remain addressable")
		for rect in bounds:
			check(Rect2(0, 0, 1280, 800).encloses(rect), "all river tiles stay within the table design canvas")
	for seat in range(1, 4):
		var hidden = desk.dynamic.get_node("ConcealedHand%d" % seat)
		check(hidden.get_child_count() == desk.game.players[seat].hand.size(), "concealed count matches the view")
		for card in hidden.get_children():
			check(card.number == -1, "opponent hidden tile has no face identity")
	desk.show_lobby()
	check(not native.visible, "leaving a table releases the visible board")
	desk.free()
	if failures == 0:
		print("Native table projection, clicking, wall source, river capacity and privacy passed.")
	quit(failures)
