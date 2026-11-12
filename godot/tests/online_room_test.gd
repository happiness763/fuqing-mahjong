extends SceneTree

const ROOM_PATH := "res://scripts/online_room.gd"
const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/rules.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func wait_for(predicate: Callable, message: String, timeout_ms := 3000) -> bool:
	var until := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < until:
		await process_frame
	var passed: bool = predicate.call()
	check(passed, message)
	return passed


func make_room(branch_name: String):
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var room = load(ROOM_PATH).new()
	room.name = "OnlineRoom"
	branch.add_child(room)
	return room


func drive_rolls(host, client) -> bool:
	var guard := 0
	while host.state.get("phase") == "rolling" and guard < 400:
		var roll: Dictionary = host.state.get("roll", {})
		var current: int = Rules.dealer_roll_current(roll) if not roll.is_empty() else -1
		if current == host.state.get("my_seat", -1):
			host.request("roll")
		elif current == client.state.get("my_seat", -1) and client.state.get("phase") == "rolling":
			client.request("roll")
		await create_timer(0.05).timeout
		guard += 1
	return await wait_for(func(): return client.state.get("phase") == "playing", "mixed table starts for both peers")


func set_dealer_turn(host, dealer: int) -> void:
	for seed in range(100):
		var game := Game.new(seed, 1, "normal", true)
		if dealer != 0:
			game.dealer = dealer
			game.start_round()
		if game.phase == "turn":
			host._game = game
			host._begin_stage()
			host._publish()
			return
	check(false, "fixture can find a turn after dealing")


func test_private_reaction(host, client) -> void:
	var game := Game.new(43, 1, "normal", true)
	game.phase = "turn"
	game.current = 0
	game.dealer = 0
	game.gold = 26
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [4]
	game.players[1].hand = [4, 4]
	game.discard(0, 4)
	host._game = game
	host._begin_stage()
	host._publish()
	var stage: int = host.state.stage
	if not await wait_for(func(): return client.state.stage == stage, "client receives reaction snapshot"):
		return
	check(host.state.actor == -1 and host.state.moves.is_empty(), "discarder cannot identify the reaction actor")
	check(client.state.actor == 1 and client.state.moves.any(func(move): return move.type == "pong"),
		"only the responder sees the claim options")
	check(host.state.view.last_discard == {"seat": 0, "tile": 4} and host.seconds_left() in range(14, 16),
		"discarder still sees the public discard and anonymous countdown")


func test_private_opening(host, client) -> void:
	var game := Game.new(43, 1, "normal", true)
	game.dealer = 0
	game.gold = 26
	for player in game.players:
		player.hand.clear()
	game.players[1].hand = [26, 26, 26]
	game.open_claims("three")
	host._game = game
	host._begin_stage()
	host._publish()
	var stage: int = host.state.stage
	if not await wait_for(func(): return client.state.stage == stage, "client receives opening snapshot"):
		return
	check(host.state.actor == -1 and host.state.moves.is_empty() and host.state.view.opening.is_empty(),
		"waiting players cannot identify the opening subtype or responder")
	check(client.state.actor == 1 and client.state.view.opening == "three"
		and client.state.moves[0].kind == "three",
		"opening responder sees the subtype and their option")


func test_private_rob_kong(host, client) -> void:
	var game := Game.new(43, 1, "normal", true)
	game.phase = "turn"
	game.current = 0
	game.gold = 26
	game.can_self_win = true
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [4]
	game.players[0].melds = [{"type": "pong", "tiles": [4, 4, 4], "from": 2, "claimed": 4}]
	game.players[1].hand = [0, 0, 0, 1, 1, 1, 3, 5, 9, 9, 9, 18, 18, 18, 25, 25]
	var kongs := game.actions(0).filter(func(move): return move.type == "addedKong")
	if kongs.is_empty():
		check(false, "rob-kong fixture offers a supplemental kong")
		return
	game.act(0, kongs[0].id)
	host._game = game
	host._begin_stage()
	host._publish()
	var stage: int = host.state.stage
	if not await wait_for(func(): return client.state.stage == stage, "client receives rob-kong snapshot"):
		return
	check(host.state.view.phase == "robKong" and host.state.actor == -1 and host.state.view.rob_tile == -1
		and host.state.moves.is_empty() and host.state.view.players[0].melds[0].type == "pong",
		"waiting players see neither the rob candidate nor an applied supplemental kong")
	check(client.state.actor == 1 and client.state.view.rob_tile == 4 and client.state.moves[0].kind == "rob"
		and client.seconds_left() in range(14, 16),
		"rob-kong responder sees the tile and receives a full deadline")
	var win: Dictionary = client.state.moves[0]
	client.request("play", {"stage": stage, "id": win.id})
	await wait_for(func(): return client.state.view.phase == "result", "client rob claim settles the round")
	check(host.state.view.result.method == "rob" and host.state.view.result.payers == [0],
		"rob win keeps the method and charges only the supplemental kong declarer")


func test_public_gold_gap(host, client) -> void:
	var game := Game.new(43, 1, "normal", true)
	game.phase = "turn"
	game.current = 0
	game.gold = 4
	for player in game.players:
		player.hand.clear()
		player.melds.clear()
	game.players[0].hand = [0, 0, 0, 3, 5, 9, 10, 11, 12, 18, 18, 18, 21, 21, 21, 24, 24]
	host._game = game
	host._begin_stage()
	host._publish()
	var choices: Array = host.state.moves.filter(func(move): return move.type == "declareGoldGap" and move.tile == 12)
	if choices.is_empty():
		check(false, "gold-gap fixture has a declaration for four circles")
		return
	host.request("play", {"stage": host.state.stage, "id": choices[0].id})
	await wait_for(func(): return client.state.view.players[0].gold_gap == [3, 5],
		"remote player sees both declared gold-gap tiles")
	check(client.state.view.players[0].river == [12] and not client.state.view.players[0].has("hand")
		and client.state.view.latest.gold_gap, "public declaration includes the chosen discard while the remaining hand is private")


func run() -> void:
	if not ResourceLoader.exists(ROOM_PATH):
		check(false, "authoritative ENet room is available")
		quit(failures)
		return
	var host = make_room("Host")
	var client = make_room("Client")
	var rejected = make_room("Rejected")
	var messages: Array[String] = []
	var host_messages: Array[String] = []
	rejected.notice.connect(func(message: String): messages.append(message))
	host.notice.connect(func(message: String): host_messages.append(message))
	var port := 40000 + int(randi() % 15000)
	check(host.host(" 房东 ", port) == "", "host binds loopback UDP port")
	if host.state.is_empty():
		quit(failures + 1)
		return
	check(host.state.has("local_addresses") and not host.state.has("code"), "owner shares a room endpoint")
	var candidates := PackedStringArray(["169.254.1.2", "198.18.0.1", "192.168.10.104", "127.0.0.1", "2001:db8::1"])
	check(host._find_local_addresses(candidates) == ["192.168.10.104", "2001:db8::1", "169.254.1.2"],
		"address picker prefers private IPv4 and puts link-local candidates last")
	check(host.state.owner == 0 and host.state.seats[0].name == "房东", "creator owns the first seat")
	check(host.state.turn_seconds == 60 and host.state.rounds == 15, "room defaults to 60 seconds and 15 rounds")
	check(not rejected.host("占端口", port).is_empty(), "an occupied UDP port is reported")
	check(rejected.join("房东", "127.0.0.1", port) == "", "duplicate name is checked by the server")
	await wait_for(func(): return messages.size() == 1, "duplicate name produces a rejection")
	check(rejected.state.is_empty() and host.state.seats[1].is_empty(), "rejected join leaves seats unoccupied")
	check(client.join("访客", "127.0.0.1", port) == "", "valid join begins without a code")
	if not await wait_for(func(): return client.state.get("my_seat") == 1, "valid client receives its seat"):
		quit(failures)
		return
	check(not client.state.has("local_addresses"), "local addresses are only listed for the owner")
	client.request("settings", {"rounds": 2, "turn_seconds": 0})
	await create_timer(0.1).timeout
	check(host.state.rounds == 15, "non-owner settings are rejected")
	host.request("transfer", {"seat": 1})
	await wait_for(func(): return client.state.get("owner") == 1, "management transfer reaches client")
	check(not host.state.has("local_addresses") and client.state.has("local_addresses"), "address controls follow ownership")
	client.request("settings", {"rounds": 1, "turn_seconds": 15})
	client.request("add_ai", {"seat": 2, "name": "二号", "difficulty": "easy"})
	client.request("add_ai", {"seat": 3, "name": "三号", "difficulty": "hard"})
	await wait_for(func(): return host.state.seats[3].get("kind") == "ai", "remote owner adds AI")
	check(host.state.rounds == 1 and host.state.turn_seconds == 15, "remote owner sets the table")
	check(host.state.seats[2].get("difficulty") == "easy" and host.state.seats[3].difficulty == "hard", "AI difficulty is per seat")
	check(rejected.join("候补", "127.0.0.1", port) == "", "fifth player attempts to join the full room")
	await wait_for(func(): return messages.size() == 2 and messages.back().contains("已满"), "full rooms reject new players")
	client.request("transfer", {"seat": 0})
	await wait_for(func(): return host.state.owner == 0, "owner can transfer management back")
	host.request("remove", {"seat": 1})
	await wait_for(func(): return client.state.is_empty(), "kick ends the removed client's session")
	check(host.state.seats[1].is_empty(), "kick vacates the seat")
	check(client.join("访客", "127.0.0.1", port) == "", "same endpoint can be used to join the vacated seat")
	if not await wait_for(func(): return client.state.get("my_seat") == 1, "client joins the vacated seat"):
		quit(failures)
		return
	host.request("start")
	if not await drive_rolls(host, client):
		quit(failures)
		return
	check(not host.state.view.dealer_rolls.is_empty(), "host publishes the dealer roll")
	check(client.state.view.dealer_rolls.winner == host.state.view.dealer_rolls.winner,
		"both peers see the same dealer")
	check(host.state.view.gold_dice.size() == 2 and client.state.view.gold_dice == host.state.view.gold_dice,
		"gold dice are part of the snapshot")
	check(host._deadline_ms - Time.get_ticks_msec() >= 4000, "first stage includes the intro grace")
	for room in [host, client]:
		for seat in range(4):
			check(room.state.view.players[seat].has("hand") == (seat == room.state.my_seat), "live hand is private to its seat")
		check(not room.state.view.has("wall") and not room.state.view.has("pending"), "private game internals stay server-side")
		if room.state.actor != room.state.my_seat:
			check(room.state.moves.is_empty(), "other seats cannot see the actor's moves")
	await test_private_reaction(host, client)
	await test_private_opening(host, client)
	await test_private_rob_kong(host, client)
	await test_public_gold_gap(host, client)
	# Use a fixture with the creator to act, regardless of the random opening above.
	set_dealer_turn(host, 0)
	var stage: int = host.state.stage
	var discard: Dictionary = host.state.moves.filter(func(move): return move.type == "discard").front()
	check(host.seconds_left() == 15 and host.state.actor == 0, "each human stage begins with the full clock")
	client.request("play", {"stage": stage, "id": discard.id, "seat": 0})
	await create_timer(0.05).timeout
	check(host.state.stage == stage, "remote client cannot act as a different seat")
	host.request("play", {"stage": stage - 1, "id": discard.id})
	check(host.state.stage == stage, "stale action is rejected even when its move is still legal")
	host.request("play", {"stage": stage, "id": "discard:99"})
	check(host.state.stage == stage, "unoffered action is rejected")
	host.request("play", {"stage": stage, "id": discard.id})
	check(host.state.stage == stage + 1, "current legal move is accepted exactly once")
	host.request("play", {"stage": stage, "id": discard.id})
	check(host.state.stage == stage + 1, "replayed move cannot change the stage again")
	# Reinstall a known turn, then submit a valid move after the host's deadline.
	set_dealer_turn(host, 0)
	stage = host.state.stage
	discard = host.state.moves.filter(func(move): return move.type == "discard").front()
	host._deadline_ms = Time.get_ticks_msec() - 1
	host.request("play", {"stage": stage, "id": discard.id})
	check(host.state.stage == stage and host_messages.back().contains("超时"), "valid move arriving after the deadline is rejected")
	await wait_for(func(): return host.state.stage > stage, "expired human stage advances by automatic discard")

	host.request("transfer", {"seat": 1})
	await wait_for(func(): return client.state.get("owner") == 1, "management can be transferred during play")
	var old_client_id: int = client.multiplayer.get_unique_id()
	client.multiplayer.multiplayer_peer.disconnect_peer(1)
	await wait_for(func(): return not host.state.seats[1].connected, "disconnect reserves the seat")
	check(host.state.owner == 0, "management falls back to the earliest online human")
	await wait_for(func(): return host.state.seats[1].connected and client.multiplayer.get_unique_id() != old_client_id,
		"client resumes its seat with a new ENet connection")
	check(client.state.my_seat == 1 and client.state.seats[1].name == "访客", "resume restores the same identity")
	client.leave()
	await wait_for(func(): return host.state.seats[1].get("managed", false), "explicit departure immediately enables AI takeover")
	check(host.state.seats[1].difficulty == "normal", "takeover uses normal difficulty")
	check(rejected.join("迟到", "127.0.0.1", port) == "", "late client attempts to join the in-progress game")
	await wait_for(func(): return messages.size() == 3 and messages.back().contains("已开局"), "new clients cannot join an in-progress game")

	var deadline := Time.get_ticks_msec() + 10000
	while host.state.view.phase != "result" and Time.get_ticks_msec() < deadline:
		if host._game.online_actor() == host.state.my_seat:
			host._deadline_ms = Time.get_ticks_msec() - 1
		else:
			host._ai_due_ms = 0
		await process_frame
	check(host.state.view.phase == "result" and host.state.standings.size() == 4, "AI and human timeouts play through to standings")
	host.request("lobby", {"stage": host.state.stage - 1})
	check(host.state.phase == "playing", "stale result command cannot return to the lobby")
	host.request("lobby", {"stage": host.state.stage})
	check(host.state.phase == "lobby" and host.state.seats[1].is_empty(), "owner returns completed table to editable seats")
	check(client.join("访客", "127.0.0.1", port) == "", "client reconnects to the new lobby")
	await wait_for(func(): return client.state.get("phase") == "lobby", "lobby accepts new clients after settlement")
	host.request("settings", {"rounds": 1, "turn_seconds": 0})
	host.request("start")
	if not await drive_rolls(host, client):
		quit(failures)
		return
	set_dealer_turn(host, 1)
	stage = host.state.stage
	await wait_for(func(): return client.state.get("stage") == stage, "client sees the unlimited stage")
	client.multiplayer.multiplayer_peer.disconnect_peer(1)
	await wait_for(func(): return not host.state.seats[1].connected and client.state.get("reconnecting", false),
		"unlimited round also gives a disconnected player time to return")
	check(host.state.stage == stage and host.seconds_left() == -1 and host.state.seats[1].kind == "human",
		"unlimited round waits on the reserved human seat")
	var grace_left_ms: int = host._seats[1].expires_at - Time.get_ticks_msec()
	check(grace_left_ms > 59000 and grace_left_ms <= 60000, "server reserves seats for 60 seconds")
	host._seats[1].expires_at = Time.get_ticks_msec() - 1
	await wait_for(func(): return host.state.seats[1].get("managed", false), "expired reservation becomes a managed AI seat")
	await wait_for(func(): return host.state.stage != stage, "managed AI advances the unlimited round")
	await wait_for(func(): return client.state.is_empty(), "expired credentials cannot reclaim a managed seat")
	host.leave()
	await create_timer(0.05).timeout
	check(host.host("房东", port) == "", "same transport can open another room after closing")
	check(client.join("访客", "127.0.0.1", port) == "", "client joins reopened room")
	await wait_for(func(): return client.state.get("phase") == "lobby", "reopened room publishes a fresh lobby")
	host.queue_free()
	await wait_for(func(): return client.state.is_empty(), "closing host ends the remote room")
	if failures == 0:
		print("Online room integration tests passed")
	quit(failures)
