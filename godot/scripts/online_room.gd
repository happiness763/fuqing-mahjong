extends Node

signal state_changed
signal preferences_confirmed(changes: Dictionary)
signal notice(message: String)
signal interaction(source: int, target: int, kind: String)

const Game = preload("res://scripts/game.gd")
const Opponent = preload("res://scripts/opponent.gd")
const Rules = preload("res://scripts/rules.gd")
const Interactions = preload("res://scripts/table_interaction.gd")
const OpeningIntro = preload("res://scripts/opening_intro.gd")
const VERSION := "1.2.7"
const SERVER := 1
const DEFAULT_PORT := 36712
const CONNECT_MS := 8000
const RESUME_MS := 60000
const RETRY_MS := 800
const AI_DELAY_MS := 320
const INTRO_MS := 4500
const ROLL_AI_MS := 600
const ROLL_HUMAN_MS := 8000
const ROLL_RESULT_HOLD_MS := 140
const TURN_OPTIONS := [0, 15, 30, 60]
const DIFFICULTIES := ["easy", "normal", "hard"]

var state: Dictionary = {}

var _role := "idle"
var _peer: ENetMultiplayerPeer
var _port := DEFAULT_PORT
var _address := ""
var _nickname := ""
var _token := ""
var _local_addresses: Array[String] = []
var _owner_id := -1
var _next_seat_id := 0
var _seats: Array[Dictionary] = []
var _pending_peers: Dictionary = {}
var _interaction_after := {}
var _preference_serial := 0
var _pending_preferences := {}
var _rounds := 15
var _turn_seconds := 60
var _game: Game
var _rolling := false
var _roll_state: Dictionary = {}
var _roll_deadline_ms := -1
var _roll_ai_due_ms := -1
var _roll_lands_ms := -1
var _last_rolled_seat := -1
var _stage := 0
var _deadline_ms := -1
var _ai_due_ms := -1
var _local_deadline_ms := -1
var _connect_until_ms := -1
var _resume_until_ms := -1
var _retry_at_ms := -1
var _roll_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_roll_rng.randomize()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_connection_failed)


func _exit_tree() -> void:
	if _role == "host":
		_end_host()
	_close_transport()


func host(nick: String, port: int = DEFAULT_PORT, rounds := 15, turn_seconds := 60) -> String:
	if not _can_open():
		return "请先离开当前房间。"
	nick = nick.strip_edges()
	if not _valid_name(nick):
		return "昵称须为 1–12 个可见字符。"
	if not _valid_port(port):
		return "端口须为 1–65535。"
	if rounds < 1 or rounds > 32 or turn_seconds not in TURN_OPTIONS:
		return "房间局数或出牌时间无效。"
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 8) != OK:
		return "无法监听 UDP %d，端口可能已被占用。" % port
	_role = "host"
	_port = port
	_local_addresses = _find_local_addresses(IP.get_local_addresses())
	_next_seat_id = 0
	_rounds = rounds
	_turn_seconds = turn_seconds
	_game = null
	_seats = [_human_seat(nick, SERVER), {}, {}, {}]
	_owner_id = _seats[0].seat_id
	_install_transport(peer)
	_publish()
	return ""


func join(nick: String, address: String, port: int) -> String:
	if not _can_open():
		return "请先离开当前房间。"
	nick = nick.strip_edges()
	address = address.strip_edges().trim_prefix("[").trim_suffix("]")
	if not _valid_name(nick):
		return "昵称须为 1–12 个可见字符。"
	if not _valid_port(port):
		return "端口须为 1–65535。"
	if address.is_empty() or address.length() > 253 or "/" in address or " " in address:
		return "请输入房主 IP 地址或域名。"
	_address = address
	_port = port
	_nickname = nick
	_role = "connecting"
	if _connect_transport() != OK:
		_reset_session()
		return "无法连接该地址，请核对房主地址和 UDP 端口。"
	return ""


func is_connecting() -> bool:
	return _role == "connecting"


func leave() -> void:
	match _role:
		"host":
			_end_host()
			_clear_state()
		"client":
			_role = "leaving"
			_wire_depart.rpc_id(SERVER)
			_drain_peer(SERVER)
			_connect_until_ms = Time.get_ticks_msec() + 1000
			_clear_state()
		"connecting", "reconnecting":
			_reset_session()


func seconds_left() -> int:
	if _local_deadline_ms < 0:
		return -1
	return ceili(maxi(0, _local_deadline_ms - Time.get_ticks_msec()) / 1000.0)


func request(op: String, data: Dictionary = {}) -> void:
	if op in ["transfer", "remove", "update_ai"] and not data.has("seat_id"):
		var target: Variant = data.get("seat")
		var seats: Array = state.get("seats", [])
		if target is int and target >= 0 and target < seats.size():
			data = data.duplicate()
			data.seat_id = seats[target].get("seat_id", -1)
	if _role == "host":
		_handle_request(SERVER, op, data)
	elif _role == "client":
		var changes := _preference_changes(op, data)
		var receipt := 0
		if not changes.is_empty():
			_preference_serial += 1
			receipt = _preference_serial
			_pending_preferences[receipt] = changes
		_wire_request.rpc_id(SERVER, op, data, receipt)


func _preference_changes(op: String, data: Dictionary) -> Dictionary:
	match op:
		"rename":
			return {"nickname": _read_name(data)}
		"settings":
			return {"room_rounds": data.get("rounds"), "turn_seconds": data.get("turn_seconds")}
	return {}


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	match _role:
		"host":
			_expire_seats(now)
			for peer_id in _pending_peers.keys():
				if now >= _pending_peers[peer_id]:
					_pending_peers.erase(peer_id)
					_drain_peer(peer_id, "入房验证超时。")
			_process_stage(now) if not _rolling else _process_roll(now)
		"connecting":
			if now >= _connect_until_ms:
				_finish_client("连接超时，请核对房主地址和 UDP 端口。")
		"reconnecting":
			if now >= _resume_until_ms:
				_finish_client("重连超时，原座位已释放或托管。")
			elif _peer != null and now >= _connect_until_ms:
				_queue_retry()
			elif _peer == null and now >= _retry_at_ms:
				if _connect_transport() != OK:
					_retry_at_ms = now + RETRY_MS
		"closing", "leaving":
			if now >= _connect_until_ms or multiplayer.get_peers().is_empty():
				_reset_session()


func _can_open() -> bool:
	if _role in ["closing", "leaving"]:
		_reset_session()
	return _role == "idle"


func _install_transport(peer: ENetMultiplayerPeer) -> void:
	_peer = peer
	var api := multiplayer as SceneMultiplayer
	api.server_relay = false
	api.multiplayer_peer = peer


func _connect_transport() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_address, _port)
	if error == OK:
		_connect_until_ms = Time.get_ticks_msec() + CONNECT_MS
		_install_transport(peer)
	return error


func _close_transport() -> void:
	_pending_preferences.clear()
	if _peer == null:
		return
	var peer := _peer
	_peer = null
	multiplayer.multiplayer_peer = null
	peer.close()


func _clear_state() -> void:
	var was_visible := not state.is_empty()
	state = {}
	_local_deadline_ms = -1
	if was_visible:
		state_changed.emit()


func _reset_session() -> void:
	_role = "idle"
	_close_transport()
	_token = ""
	_seats.clear()
	_pending_peers.clear()
	_interaction_after.clear()
	_game = null
	_rolling = false
	_roll_state = {}
	_roll_deadline_ms = -1
	_roll_ai_due_ms = -1
	_roll_lands_ms = -1
	_last_rolled_seat = -1
	_deadline_ms = -1
	_ai_due_ms = -1
	_clear_state()


func _finish_client(message: String) -> void:
	_reset_session()
	notice.emit(message)


func _queue_retry() -> void:
	_close_transport()
	_retry_at_ms = Time.get_ticks_msec() + RETRY_MS


func _on_peer_connected(peer_id: int) -> void:
	if _role != "host":
		return
	_pending_peers[peer_id] = Time.get_ticks_msec() + CONNECT_MS
	_peer.get_peer(peer_id).set_timeout(32, 4000, 8000)


func _on_peer_disconnected(peer_id: int) -> void:
	if _role != "host":
		return
	_pending_peers.erase(peer_id)
	var seat := _seat_for_peer(peer_id)
	if seat < 0:
		return
	_seats[seat].peer = 0
	_seats[seat].expires_at = Time.get_ticks_msec() + RESUME_MS
	if _seats[seat].seat_id == _owner_id:
		_reassign_owner()
	_publish()


func _on_connected_to_server() -> void:
	if _role in ["connecting", "reconnecting"]:
		_peer.get_peer(SERVER).set_timeout(32, 4000, 8000)
		_wire_hello.rpc_id(SERVER, VERSION, _nickname, _token)


func _on_connection_failed() -> void:
	match _role:
		"connecting":
			_finish_client("无法连接房间，请核对地址和 UDP 端口。")
		"client":
			_role = "reconnecting"
			_resume_until_ms = Time.get_ticks_msec() + RESUME_MS
			_queue_retry()
			state.reconnecting = true
			state_changed.emit()
			notice.emit("连接中断，正在尝试恢复座位。")
		"reconnecting":
			_queue_retry()
		"leaving":
			_reset_session()


func _drain_peer(peer_id: int, message := "") -> void:
	var transport := _peer.get_peer(peer_id)
	# SceneMultiplayer can still list a peer whose ENet transport is disconnecting.
	if transport == null or transport.get_state() != ENetPacketPeer.STATE_CONNECTED:
		return
	if not message.is_empty():
		_wire_ended.rpc_id(peer_id, message)
	transport.peer_disconnect_later()
	_peer.host.flush()


func _end_host() -> void:
	_role = "closing"
	_connect_until_ms = Time.get_ticks_msec() + 1000
	for peer_id in multiplayer.get_peers():
		_drain_peer(peer_id, "承载端已关闭，房间结束。")


@rpc("any_peer", "call_remote", "reliable")
func _wire_hello(version: String, nick: String, token: String) -> void:
	if _role != "host":
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _pending_peers.has(sender):
		return
	_pending_peers.erase(sender)
	if version != VERSION:
		_drain_peer(sender, "游戏版本不一致，请使用 %s。" % VERSION)
		return
	var now := Time.get_ticks_msec()
	_expire_seats(now)
	if not token.is_empty():
		for seat in range(_seats.size()):
			if _seats[seat].get("peer", 0) == SERVER or _seats[seat].get("token", "") != token:
				continue
			var old_peer: int = _seats[seat].peer
			_seats[seat].peer = sender
			_seats[seat].expires_at = -1
			if old_peer != 0:
				_drain_peer(old_peer)
			_welcome(sender, seat)
			return
		_drain_peer(sender, "原座位已释放或托管，请重新加入。")
		return
	if _game != null or _rolling:
		_drain_peer(sender, "本桌已开局，请等结算后加入。")
		return
	var seat := _seats.find({})
	if seat < 0:
		_drain_peer(sender, "房间已满。")
		return
	nick = nick.strip_edges()
	if not _valid_name(nick):
		_drain_peer(sender, "昵称须为 1–12 个可见字符。")
		return
	if not _name_available(nick):
		_drain_peer(sender, "房间内已有同名玩家，请更换昵称。")
		return
	_seats[seat] = _human_seat(nick, sender)
	_welcome(sender, seat)


func _welcome(peer_id: int, seat: int) -> void:
	_wire_welcome.rpc_id(peer_id, _seats[seat].token, _snapshot(seat))
	_publish(peer_id)


@rpc("authority", "call_remote", "reliable")
func _wire_welcome(token: String, snapshot: Dictionary) -> void:
	if _role not in ["connecting", "reconnecting"]:
		return
	var resumed := _role == "reconnecting"
	_role = "client"
	_token = token
	_apply_snapshot(snapshot)
	if resumed:
		notice.emit("已恢复座位。")


@rpc("authority", "call_remote", "reliable")
func _wire_ended(message: String) -> void:
	if _role in ["connecting", "client", "reconnecting"]:
		_finish_client(message)


@rpc("authority", "call_remote", "reliable")
func _wire_notice(message: String) -> void:
	if _role == "client":
		notice.emit(message)


@rpc("authority", "call_remote", "reliable")
func _wire_snapshot(snapshot: Dictionary) -> void:
	if _role == "client":
		_apply_snapshot(snapshot)


@rpc("any_peer", "call_remote", "reliable")
func _wire_request(op: String, data: Dictionary, receipt: int) -> void:
	if _role == "host":
		_handle_request(multiplayer.get_remote_sender_id(), op, data, receipt)


@rpc("any_peer", "call_remote", "reliable")
func _wire_depart() -> void:
	if _role != "host":
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var seat := _seat_for_peer(peer_id)
	if peer_id != SERVER and seat >= 0:
		_release_seat(seat)
		_drain_peer(peer_id)
		_publish()


func _human_seat(nick: String, peer_id: int) -> Dictionary:
	var seat := {"name": nick, "kind": "human", "difficulty": "normal", "peer": peer_id,
		"token": Crypto.new().generate_random_bytes(24).hex_encode(), "expires_at": -1, "seat_id": _next_seat_id}
	_next_seat_id += 1
	return seat


func _seat_for_peer(peer_id: int) -> int:
	if peer_id <= 0:
		return -1
	for seat in range(_seats.size()):
		if _seats[seat].get("peer", 0) == peer_id:
			return seat
	return -1


func _release_seat(seat: int) -> void:
	var was_owner: bool = _seats[seat].seat_id == _owner_id
	if _game == null and not _rolling:
		_seats[seat] = {}
	else:
		var old_name: String = _seats[seat].get("name", "AI")
		_seats[seat] = {"name": old_name, "kind": "ai", "difficulty": "normal", "managed": true, "seat_id": _next_seat_id}
		_next_seat_id += 1
		if _game != null and _game.online_actor() == seat:
			_ai_due_ms = Time.get_ticks_msec() + AI_DELAY_MS
		elif _rolling and Rules.dealer_roll_current(_roll_state) == seat:
			_schedule_roll()
	if was_owner:
		_reassign_owner()


func _reassign_owner() -> void:
	var earliest := _next_seat_id
	for player in _seats:
		if player.get("peer", 0) != 0:
			earliest = mini(earliest, player.seat_id)
	_owner_id = -1 if earliest == _next_seat_id else earliest


func _owner_seat() -> int:
	for seat in range(_seats.size()):
		if _seats[seat].get("seat_id", -1) == _owner_id and not _seats[seat].is_empty():
			return seat
	return -1


func _expire_seats(now: int) -> void:
	var changed := false
	for seat in range(_seats.size()):
		var expiry: int = _seats[seat].get("expires_at", -1)
		if expiry >= 0 and now >= expiry:
			_release_seat(seat)
			changed = true
	if changed:
		_publish()


func _handle_request(peer_id: int, op: String, data: Dictionary, receipt := 0) -> void:
	var received_at := Time.get_ticks_msec()
	var seat := _seat_for_peer(peer_id)
	if seat < 0:
		return
	if op == "interaction":
		_broadcast_interaction(seat, data, received_at)
		return
	var error := _apply_request(seat, op, data, received_at)
	if error.is_empty():
		_publish()
		if peer_id == SERVER:
			var changes := _preference_changes(op, data)
			if not changes.is_empty():
				preferences_confirmed.emit(changes)
	elif peer_id == SERVER:
		notice.emit(error)
	else:
		_wire_notice.rpc_id(peer_id, error)
	if peer_id != SERVER and receipt > 0:
		_wire_preferences_confirmed.rpc_id(peer_id, receipt, error.is_empty())


@rpc("authority", "call_remote", "reliable")
func _wire_preferences_confirmed(receipt: int, accepted: bool) -> void:
	if _role != "client" or not _pending_preferences.has(receipt):
		return
	var changes: Dictionary = _pending_preferences[receipt]
	_pending_preferences.erase(receipt)
	if accepted:
		preferences_confirmed.emit(changes)


func _broadcast_interaction(source: int, data: Dictionary, now: int) -> void:
	if _game == null or _game.phase == "result" or now < int(_interaction_after.get(source, 0)):
		return
	var target: Variant = data.get("target")
	var kind: Variant = data.get("kind")
	if not target is int or not kind is String or target == source or target < 0 or target >= _seats.size():
		return
	var recipient: Dictionary = _seats[target]
	if recipient.is_empty() or not Interactions.PROPS.has(kind):
		return
	_interaction_after[source] = now + Interactions.COOLDOWN_MS
	for peer_id in multiplayer.get_peers():
		if _seat_for_peer(peer_id) >= 0:
			_wire_interaction.rpc_id(peer_id, source, target, kind)
	interaction.emit(source, target, kind)


@rpc("authority", "call_remote", "reliable", 1)
func _wire_interaction(source: int, target: int, kind: String) -> void:
	if _role == "client" and state.get("phase") == "playing":
		interaction.emit(source, target, kind)


func _apply_request(seat: int, op: String, data: Dictionary, received_at: int) -> String:
	if op == "roll":
		if not _rolling:
			return "当前不在掷骰阶段。"
		if seat != Rules.dealer_roll_current(_roll_state):
			return "还没轮到你掷骰。"
		if received_at < _roll_lands_ms:
			return "请等骰子停稳。"
		_roll_apply(seat)
		return ""
	if op == "play":
		return _play(seat, data, received_at)
	if _rolling:
		return "正在掷骰定庄，请稍候。"
	if op == "rename":
		return "本桌已开局，结算后可修改昵称。" if _game != null else _rename(seat, data)
	if op == "move_seat":
		return "本桌进行中，结算后可调整房间。" if _game != null else _move_seat(seat, data)
	if _seats[seat].seat_id != _owner_id:
		return "只有房主可以执行这项操作。"
	var target: Variant = data.get("seat", -1)
	var has_target := _valid_seat(target)
	if has_target and op in ["transfer", "remove", "update_ai"] and not _seat_matches(target, data.get("seat_id")):
		return "座位已变化，请确认后再操作。"
	if op == "transfer":
		if not has_target or _seats[target].get("peer", 0) == 0 or target == seat:
			return "请选择另一位在线真人接任房主。"
		_owner_id = _seats[target].seat_id
		return ""
	if op in ["next", "lobby"]:
		return _after_result(op, data)
	if _game != null:
		return "本桌进行中，结算后可调整房间。"
	match op:
		"arrange_seats":
			return _arrange_seats(data)
		"settings":
			var rounds: Variant = data.get("rounds")
			var seconds: Variant = data.get("turn_seconds")
			if typeof(rounds) != TYPE_INT or rounds < 1 or rounds > 32:
				return "总局数须为 1–32。"
			if typeof(seconds) != TYPE_INT or seconds not in TURN_OPTIONS:
				return "出牌时间须为 15 秒、30 秒、60 秒或不限时。"
			_rounds = rounds
			_turn_seconds = seconds
		"start":
			for player in _seats:
				if player.is_empty() or (player.kind == "human" and player.peer == 0):
					return "请等真人到齐或用 AI 补满四个座位。"
			_start_rolling()
		"add_ai", "update_ai":
			if not has_target:
				return "请选择有效座位。"
			return _set_ai(target, op == "update_ai", data)
		"remove":
			if not has_target or target == seat or _seats[target].is_empty() or _seats[target].get("peer", 0) == SERVER:
				return "请选择可移除的座位。"
			var player := _seats[target]
			_seats[target] = {}
			if player.kind == "human" and player.peer != 0:
				_drain_peer(player.peer, "房主已将你移出房间。")
		_:
			return "房间不支持这项操作。"
	return ""


func _valid_seat(seat: Variant) -> bool:
	return seat is int and seat >= 0 and seat < _seats.size()


func _seat_matches(seat: int, expected_id: Variant) -> bool:
	return expected_id is int and _seats[seat].get("seat_id", -1) == expected_id


func _move_seat(source: int, data: Dictionary) -> String:
	var target: Variant = data.get("seat")
	if not _valid_seat(target) or source == target:
		return "请选择其他空座。"
	if not _seats[target].is_empty():
		return "该座位已有人"
	var expected_source: Variant = data.get("from")
	if not expected_source is int or expected_source != source:
		return "座位已变化，请确认后再操作。"
	_seats[target] = _seats[source]
	_seats[source] = {}
	return ""


func _arrange_seats(data: Dictionary) -> String:
	var source: Variant = data.get("from")
	var target: Variant = data.get("seat")
	if not _valid_seat(source) or not _valid_seat(target) or source == target:
		return "请选择两个不同的座位。"
	if _seats[source].is_empty() or not _seat_matches(source, data.get("from_id")) or not _seat_matches(target, data.get("seat_id")):
		return "座位已变化，请确认后再操作。"
	var occupant := _seats[source]
	_seats[source] = _seats[target]
	_seats[target] = occupant
	return ""


func _rename(seat: int, data: Dictionary) -> String:
	var nick := _read_name(data)
	if not _valid_name(nick):
		return "昵称须为 1–12 个可见字符。"
	if not _name_available(nick, seat):
		return "房间内已有同名玩家，请更换昵称。"
	_seats[seat].name = nick
	return ""


func _set_ai(seat: int, update: bool, data: Dictionary) -> String:
	var player := _seats[seat]
	if (update and player.get("kind") != "ai") or (not update and not player.is_empty()):
		return "该座位不能执行此操作。"
	var difficulty: Variant = data.get("difficulty", player.get("difficulty", "normal"))
	if typeof(difficulty) != TYPE_STRING or difficulty not in DIFFICULTIES:
		return "请选择有效的 AI 难度。"
	var nick := _read_name(data)
	if not _valid_name(nick):
		return "昵称须为 1–12 个可见字符。"
	if not _name_available(nick, seat):
		return "房间内已有同名玩家，请更换昵称。"
	var seat_id: int = player.seat_id if update else _next_seat_id
	if not update:
		_next_seat_id += 1
	_seats[seat] = {"name": nick, "kind": "ai", "difficulty": difficulty, "seat_id": seat_id}
	return ""


func _read_name(data: Dictionary) -> String:
	var value: Variant = data.get("name")
	return value.strip_edges() if typeof(value) == TYPE_STRING else ""


func _name_available(nick: String, ignore_seat := -1) -> bool:
	var key := nick.to_lower()
	for seat in range(_seats.size()):
		if seat != ignore_seat and _seats[seat].get("name", "").to_lower() == key:
			return false
	return true


func _valid_name(nick: String) -> bool:
	if nick.length() < 1 or nick.length() > 12:
		return false
	for index in range(nick.length()):
		var character := nick.unicode_at(index)
		if character < 32 or character in [127, 8232, 8233]:
			return false
	return true


func _valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


func _find_local_addresses(candidates: PackedStringArray) -> Array[String]:
	var private_ipv4: Array[String] = []
	var other: Array[String] = []
	var link_local: Array[String] = []
	var seen := {}
	for address in candidates:
		if address.begins_with("127.") or address in ["::1", "0.0.0.0", "::"]:
			continue
		if seen.has(address):
			continue
		seen[address] = true
		if ":" in address:
			if not address.begins_with("fe80:") and not address.begins_with("::ffff:"):
				other.append(address)
			continue
		var octets := address.split(".")
		if octets.size() != 4:
			continue
		var second := int(octets[1])
		if octets[0] == "198" and second in [18, 19]:
			continue
		if address.begins_with("169.254."):
			link_local.append(address)
		elif address.begins_with("10.") or address.begins_with("192.168.") or (octets[0] == "172" and second >= 16 and second <= 31):
			private_ipv4.append(address)
		else:
			other.append(address)
	var addresses := private_ipv4 + other + link_local
	return ["127.0.0.1"] if addresses.is_empty() else addresses


func _play(seat: int, data: Dictionary, received_at: int) -> String:
	if _game == null or typeof(data.get("stage")) != TYPE_INT or data.stage != _stage:
		return "操作阶段已结束，请使用当前选项。"
	if _game.online_actor() != seat:
		return "当前未轮到你操作。"
	if _deadline_ms >= 0 and received_at >= _deadline_ms:
		return "本阶段操作已超时。"
	var id: Variant = data.get("id")
	var flower_revision := _game.flower_revision
	if typeof(id) != TYPE_STRING or not _game.act(seat, id):
		return "这项操作当前无效。"
	_begin_stage(_draw_grace_ms(flower_revision))
	return ""


func _after_result(op: String, data: Dictionary) -> String:
	if _game == null or _game.phase != "result" or typeof(data.get("stage")) != TYPE_INT or data.stage != _stage:
		return "请等待当前结算。"
	if op == "next":
		if not _game.next_round():
			return "本桌已打完。"
		_begin_stage(_opening_grace_ms())
		return ""
	if not _game.is_table_finished():
		return "整桌结束后可返回等候室。"
	_game = null
	_deadline_ms = -1
	_ai_due_ms = -1
	for seat in range(_seats.size()):
		if _seats[seat].get("managed", false):
			_seats[seat] = {}
	return ""


func _start_rolling() -> void:
	_game = null
	_stage = 0
	_rolling = true
	_roll_state = Rules.dealer_roll_state(_roll_rng)
	_roll_deadline_ms = -1
	_roll_ai_due_ms = -1
	_roll_lands_ms = -1
	_last_rolled_seat = -1
	_schedule_roll()


func _schedule_roll() -> void:
	_roll_deadline_ms = -1
	_roll_ai_due_ms = -1
	if not _rolling:
		return
	var seat := Rules.dealer_roll_current(_roll_state)
	if seat < 0:
		return
	var now := maxi(Time.get_ticks_msec(), _roll_lands_ms)
	if _seats[seat].get("kind", "ai") == "ai":
		_roll_ai_due_ms = now + ROLL_AI_MS
	else:
		_roll_deadline_ms = now + ROLL_HUMAN_MS


func _process_roll(now: int) -> void:
	if _roll_state.get("finished", false):
		if now >= _roll_lands_ms + ROLL_RESULT_HOLD_MS:
			_finish_rolling()
			_publish()
	elif _roll_lands_ms >= 0 and now >= _roll_lands_ms:
		_roll_lands_ms = -1
		if _roll_deadline_ms >= 0:
			_publish()
	elif _roll_ai_due_ms >= 0 and now >= _roll_ai_due_ms:
		_roll_current()
	elif _roll_deadline_ms >= 0 and now >= _roll_deadline_ms:
		_roll_current()


func _roll_current() -> void:
	var seat := Rules.dealer_roll_current(_roll_state)
	if seat < 0:
		return
	_roll_apply(seat)
	_publish()


func _roll_apply(seat: int) -> void:
	if not _rolling:
		return
	Rules.dealer_roll_apply(_roll_state, _roll_rng)
	_last_rolled_seat = seat
	_roll_lands_ms = Time.get_ticks_msec() + OpeningIntro.DICE_DURATION_MS
	_schedule_roll()


func _finish_rolling() -> void:
	_rolling = false
	_roll_deadline_ms = -1
	_roll_ai_due_ms = -1
	_game = Game.new(-1, _rounds, "normal", true, int(_roll_state.winner))
	_game.dealer_rolls = _roll_state.duplicate(true)
	_begin_stage(_opening_grace_ms())


func _opening_grace_ms() -> int:
	var initial_flowers := _game.deal_flowers.filter(func(event): return event.round == 0).size()
	var seconds := OpeningIntro.FLOWER_HOLD + initial_flowers * OpeningIntro.FLOWER_STEP
	seconds += _game.deal_draws.size() * OpeningIntro.REPLACEMENT_STEP
	return INTRO_MS + ceili(seconds * 1000.0)


func _draw_grace_ms(previous_revision: int) -> int:
	if _game.flower_revision == previous_revision:
		return 0
	var seconds := OpeningIntro.FLOWER_HOLD + _game.last_flowers.size() * OpeningIntro.FLOWER_STEP
	return ceili((seconds + OpeningIntro.REPLACEMENT_STEP) * 1000.0)


func _begin_stage(intro_ms := 0) -> void:
	_stage += 1
	var actor := _game.online_actor()
	var now := Time.get_ticks_msec()
	_deadline_ms = now + intro_ms + _turn_seconds * 1000 if actor >= 0 and _turn_seconds > 0 else -1
	_ai_due_ms = now + intro_ms + AI_DELAY_MS if actor >= 0 and _seats[actor].kind == "ai" else -1


func _process_stage(now: int) -> void:
	if _game == null:
		return
	var actor := _game.online_actor()
	if actor < 0:
		return
	var move: Dictionary
	if _ai_due_ms >= 0 and now >= _ai_due_ms:
		move = Opponent.choose(_game.view(actor), _game.actions(actor), _seats[actor].difficulty)
	elif _deadline_ms >= 0 and now >= _deadline_ms:
		move = _game.online_timeout_action()
	else:
		return
	var flower_revision := _game.flower_revision
	if not move.is_empty() and _game.act(actor, move.id):
		_begin_stage(_draw_grace_ms(flower_revision))
		_publish()


func _snapshot(seat: int) -> Dictionary:
	var owner := _owner_seat()
	var public_seats: Array[Dictionary] = []
	for player in _seats:
		if player.is_empty():
			public_seats.append({})
		else:
			public_seats.append({"name": player.name, "kind": player.kind, "difficulty": player.difficulty, "seat_id": player.seat_id,
				"connected": player.kind == "ai" or player.get("peer", 0) != 0, "managed": player.get("managed", false)})
	var snapshot := {"phase": "rolling" if _rolling else ("lobby" if _game == null else "playing"),
		"my_seat": seat, "owner": owner, "host_seat": _seat_for_peer(SERVER), "seats": public_seats, "rounds": _rounds,
		"turn_seconds": _turn_seconds, "port": _port}
	if seat == owner:
		snapshot.local_addresses = _local_addresses.duplicate()
	if _rolling:
		snapshot.roll = _roll_state.duplicate(true)
		snapshot.last_rolled_seat = _last_rolled_seat
		snapshot.roll_ready = _roll_lands_ms < 0
		snapshot.roll_remaining_ms = -1 if _roll_deadline_ms < 0 else maxi(0, _roll_deadline_ms - Time.get_ticks_msec())
		return snapshot
	if _game != null:
		var actor := _game.online_actor()
		snapshot.view = _game.view(seat).duplicate(true)
		snapshot.moves = _game.actions(seat).duplicate(true) if seat == actor else []
		snapshot.stage = _stage
		snapshot.actor = actor if _game.phase == "turn" or actor == seat else -1
		snapshot.remaining_ms = -1 if _deadline_ms < 0 else maxi(0, _deadline_ms - Time.get_ticks_msec())
		if _game.phase == "result":
			snapshot.standings = _game.standings()
	return snapshot


func _publish(skip_peer := -1) -> void:
	for seat in range(_seats.size()):
		var peer_id: int = _seats[seat].get("peer", 0)
		if peer_id != 0 and peer_id != SERVER and peer_id != skip_peer:
			_wire_snapshot.rpc_id(peer_id, _snapshot(seat))
	_apply_snapshot(_snapshot(_seat_for_peer(SERVER)))


func _apply_snapshot(snapshot: Dictionary) -> void:
	state = snapshot
	var remaining: int = state.get("remaining_ms", -1)
	if remaining >= 0 and _role == "client":
		# Approximate the snapshot's transit time without comparing machine clocks.
		var round_trip_ms := _peer.get_peer(SERVER).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		remaining = maxi(0, remaining - roundi(round_trip_ms / 2.0))
	_local_deadline_ms = -1 if remaining < 0 else Time.get_ticks_msec() + remaining
	state_changed.emit()
