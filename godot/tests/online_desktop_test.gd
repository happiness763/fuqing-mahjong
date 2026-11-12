extends SceneTree

const Desk = preload("res://table.tscn")
const Rules = preload("res://scripts/rules.gd")

var args := {}
var failures := 0
var observed_revision := -1
var observed_claims := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			args[pair[0]] = pair[1]
	run.call_deferred()


func check(valid: bool, message: String) -> void:
	if not valid:
		failures += 1
		printerr("FAIL: ", message)


func wait_for(predicate: Callable, message: String, milliseconds := 10000) -> bool:
	var deadline := Time.get_ticks_msec() + milliseconds
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var valid: bool = predicate.call()
	check(valid, message)
	return valid


func capture(name: String) -> void:
	if not args.has("qa") or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(args.qa.path_join(name + ".png")) == OK,
		"saved " + name)


func run() -> void:
	var host: bool = args.get("role") == "host"
	var role := "host" if host else "guest"
	var port: int = int(args.get("port", "36712"))
	var desk = Desk.instantiate()
	root.add_child(desk)
	desk.lobby.online_button.pressed.emit()
	var screen = desk.online_lobby
	var room = desk.room
	check(screen.parse_endpoint("frp-ice.com:45939") == {"address": "frp-ice.com", "port": 45939},
		"public UDP endpoint format is accepted")
	check(screen.parse_endpoint("[2001:db8::1]:36712") == {"address": "2001:db8::1", "port": 36712},
		"bracketed IPv6 endpoint is accepted")
	for invalid in ["frp-ice.com", "frp-ice.com:65536", "https://frp-ice.com:45939", "2001:db8::1:36712"]:
		check(screen.parse_endpoint(invalid).is_empty(), "rejects invalid endpoint: " + invalid)
	var ready: String = args.qa.path_join("endpoint.txt")
	if host:
		screen.entry_name.text = "玉兰"
		screen.host_port.text = str(port)
		screen.host_button.pressed.emit()
		if room.state.is_empty():
			printerr("FAIL: host could not open room")
			quit(1)
			return
		var address: String = args.get("address", "127.0.0.1")
		var external_port: String = args.get("join-port", str(port))
		var endpoint := "%s:%s" % [address, external_port]
		if DisplayServer.get_name() != "headless":
			screen.external_address.text = address
			screen.external_port.text = external_port
			screen._copy_external()
			check(DisplayServer.clipboard_get() == endpoint, "copy shares only the public endpoint")
		check(FileAccess.open(ready, FileAccess.WRITE).store_string(endpoint), "endpoint is shared")
		if not await wait_for(func(): return not room.state.seats[1].is_empty(), "friend joins"):
			quit(failures)
			return
		check(room.state.turn_seconds == 60, "opening defaults to 60 seconds")
		await capture("room-owner")
		screen.seat_rows[1].transfer.pressed.emit()
		screen.confirm.confirmed.emit()
		screen.confirm.hide()
	else:
		if not await wait_for(func(): return FileAccess.file_exists(ready), "host opened"):
			quit(failures)
			return
		screen.entry_name.text = "海棠"
		screen.join_endpoint.text = FileAccess.get_file_as_string(ready)
		screen.join_button.pressed.emit()
		if not await wait_for(func(): return room.state.get("owner", -1) == 1, "guest receives ownership"):
			quit(failures)
			return
		screen.round_field.text = "1"
		screen.round_field.text_changed.emit("1")
		screen.turn_menu.select(0)
		screen.save_button.pressed.emit()
		for seat in [2, 3]:
			screen.seat_rows[seat].add.pressed.emit()
			if not await wait_for(func(): return not room.state.seats[seat].is_empty(), "AI seat added"):
				quit(failures)
				return
			screen.seat_rows[seat].name.text = "小松" if seat == 2 else "小竹"
			screen.seat_rows[seat].difficulty.select(0 if seat == 2 else 2)
			screen.seat_rows[seat].save.pressed.emit()
		if not await wait_for(func(): return room.state.seats[3].get("name") == "小竹" and room.state.rounds == 1,
			"room settings synced"):
			quit(failures)
			return
		await capture("room-settings")
		screen.start_button.pressed.emit()

	if not await wait_for(func(): return room.state.get("phase") == "playing", "table starts on both peers"):
		quit(failures)
		return
	check(room.state.owner == 1 and room.state.turn_seconds == 15, "room owner and turn time are synchronized")
	check(desk.header.visible and not screen.visible and desk.online_view.seat == 0, "online table opens in local perspective")
	check(desk.player_name(0) == ("玉兰" if host else "海棠"), "local seat nickname")
	check(desk.online_view.players[0].has("hand") and not desk.online_view.players[1].has("hand"), "hand privacy through UI")
	check(is_instance_valid(desk.countdown_label) and room.seconds_left() in range(0, 76), "countdown displays from server state")
	room.state_changed.connect(func(): check_action_banner(desk, room))
	await create_timer(0.60).timeout
	await capture("table-" + role)
	var deadline := Time.get_ticks_msec() + 65000
	var actions := 0
	while room.state.get("phase") == "playing" and room.state.view.phase != "result" and Time.get_ticks_msec() < deadline:
		var moves: Array = desk.local_moves()
		if not moves.is_empty():
			var move: Dictionary = moves[0]
			for candidate in moves:
				if candidate.type == "discard":
					move = candidate
					break
			var win: Array = moves.filter(func(candidate): return candidate.type == "win")
			if win.is_empty() and desk.controls.has("pass"):
				desk.controls.pass.pressed.emit()
			elif move.type == "discard":
				var tile = desk.human_buttons.filter(func(candidate): return candidate.number == move.tile)[0]
				tile.pressed.emit()
				desk.controls.discard.pressed.emit()
			else:
				desk.perform(0, move)
			actions += 1
		await process_frame
	var result: Dictionary = room.state.get("view", {}).get("result", {})
	check(not result.is_empty() and room.state.view.table_finished, "online round finishes")
	if result.is_empty():
		quit(failures + 1)
		return
	check(desk.modal != null and room.state.standings.size() == 4, "full settlement is displayed")
	await capture("result-" + role)
	var result_file: String = args.qa.path_join(role + "-scores.txt")
	check(FileAccess.open(result_file, FileAccess.WRITE).store_string(str(room.state.view.scores)), "scores recorded")
	if host:
		await wait_for(func(): return FileAccess.file_exists(args.qa.path_join("guest-scores.txt")), "guest sees result")
		check(FileAccess.get_file_as_string(result_file) == FileAccess.get_file_as_string(args.qa.path_join("guest-scores.txt")),
			"both computers see the same scores")
	else:
		await wait_for(func(): return FileAccess.file_exists(args.qa.path_join("host-scores.txt")), "host sees result")
		desk.end_table()
	await wait_for(func(): return room.state.get("phase") == "lobby", "both peers return to the same room")
	check(screen.visible and not desk.header.visible, "return restores room UI")
	if failures == 0:
		print("Online desktop ", role, " passed: direct join, transfer, AI settings, countdown, ",
			observed_claims, " claim prompts, ", actions, " actions and settlement.")
	if host:
		await create_timer(0.25).timeout
	room.leave()
	await create_timer(0.30).timeout
	quit(failures)


func check_action_banner(desk, room) -> void:
	if room.state.get("phase") != "playing":
		return
	var event: Dictionary = room.state.view.latest
	var caption: String = Rules.MELD_NAMES.get(event.type, "")
	if event.type == "win":
		var result: Dictionary = room.state.view.result
		caption = "胡牌" if result.method == "discard" else Rules.WIN_NAMES[result.method]
		if result.kind != result.method:
			caption += " · " + Rules.WIN_NAMES[result.kind]
	elif event.type == "discard" and event.get("gold_gap", false):
		caption = "报听金坎"
	if caption.is_empty() or event.revision == observed_revision:
		return
	observed_revision = event.revision
	observed_claims += 1
	var actor: String = room.state.seats[event.seat].name
	var banner: Panel = desk.action_banner
	var visible: bool = (is_instance_valid(banner) and banner.get_node("Actor").text == actor
		and banner.get_node("Caption").text == caption)
	var queued: bool = desk.action_messages.any(func(message): return message.actor == actor and message.caption == caption)
	check(visible or queued, "confirmed claim announces the correct nickname and action to " + desk.player_name(0))
