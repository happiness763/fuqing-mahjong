extends Node

signal state_changed
signal notice(message: String)

const Game = preload("res://scripts/game.gd")
const Opponent = preload("res://scripts/opponent.gd")
const VERSION := "1.2.2"
const SERVER := 1
const DEFAULT_PORT := 36712
const CONNECT_MS := 8000
const RESUME_MS := 60000
const RETRY_MS := 800
const AI_DELAY_MS := 320
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
var _owner := 0
var _seat_order := 0
var _seats: Array[Dictionary] = []
var _pending_peers: Dictionary = {}
var _rounds := 15
var _turn_seconds := 60
var _game: Game
var _stage := 0
var _deadline_ms := -1
var _ai_due_ms := -1
var _local_deadline_ms := -1
var _connect_until_ms := -1
var _resume_until_ms := -1
var _retry_at_ms := -1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_connection_failed)


func _exit_tree() -> void:
	if _role == "host":
		_end_host()
	_close_transport()


func host(nick: String, port: int = DEFAULT_PORT) -> String:
	if not _can_open():
		return "请先离开当前房间。"
	nick = nick.strip_edges()
	if not _valid_name(nick):
		return "昵称须为 1–12 个可见字符。"
	if not _valid_port(port):
		return "端口须为 1–65535。"
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 8) != OK:
		return "无法监听 UDP %d，端口可能已被占用。" % port
	_role = "host"
	_port = port
	_local_addresses = _find_local_addresses(IP.get_local_addresses())
	_owner = 0
	_seat_order = 0
	_rounds = 15
	_turn_seconds = 60
	_game = null
	_seats = [_human_seat(nick, SERVER), {}, {}, {}]
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
	if _role == "host":
		_handle_request(SERVER, op, data)
	elif _role == "client":
		_wire_request.rpc_id(SERVER, op, data)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	match _role:
		"host":
			_expire_seats(now)
			for peer_id in _pending_peers.keys():
				if now >= _pending_peers[peer_id]:
					_pending_peers.erase(peer_id)
					_drain_peer(peer_id, "入房验证超时。")
			_process_stage(now)
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
	_game = null
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
	if seat == _owner:
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
		for seat in range(1, _seats.size()):
			if _seats[seat].get("token", "") != token:
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
	if _game != null:
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
		notice.emit("已恢复原座位。")


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
func _wire_request(op: String, data: Dictionary) -> void:
	if _role == "host":
		_handle_request(multiplayer.get_remote_sender_id(), op, data)


@rpc("any_peer", "call_remote", "reliable")
func _wire_depart() -> void:
	if _role != "host":
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var seat := _seat_for_peer(peer_id)
	if seat > 0:
		_release_seat(seat)
		_drain_peer(peer_id)
		_publish()


func _human_seat(nick: String, peer_id: int) -> Dictionary:
	var seat := {"name": nick, "kind": "human", "difficulty": "normal", "peer": peer_id,
		"token": Crypto.new().generate_random_bytes(24).hex_encode(), "expires_at": -1, "order": _seat_order}
	_seat_order += 1
	return seat


func _seat_for_peer(peer_id: int) -> int:
	if peer_id <= 0:
		return -1
	for seat in range(_seats.size()):
		if _seats[seat].get("peer", 0) == peer_id:
			return seat
	return -1


func _release_seat(seat: int) -> void:
	if _game == null:
		_seats[seat] = {}
	else:
		_seats[seat] = {"name": _seats[seat].name, "kind": "ai", "difficulty": "normal", "managed": true}
		if _game.online_actor() == seat:
			_ai_due_ms = Time.get_ticks_msec() + AI_DELAY_MS
	if seat == _owner:
		_reassign_owner()


func _reassign_owner() -> void:
	var earliest := _seat_order
	for seat in range(_seats.size()):
		var player := _seats[seat]
		if player.get("peer", 0) != 0 and player.order < earliest:
			_owner = seat
			earliest = player.order


func _expire_seats(now: int) -> void:
	var changed := false
	for seat in range(1, _seats.size()):
		var expiry: int = _seats[seat].get("expires_at", -1)
		if expiry >= 0 and now >= expiry:
			_release_seat(seat)
			changed = true
	if changed:
		_publish()


func _handle_request(peer_id: int, op: String, data: Dictionary) -> void:
	var received_at := Time.get_ticks_msec()
	var seat := _seat_for_peer(peer_id)
	if seat < 0:
		return
	var error := _apply_request(seat, op, data, received_at)
	if error.is_empty():
		_publish()
	elif peer_id == SERVER:
		notice.emit(error)
	else:
		_wire_notice.rpc_id(peer_id, error)


func _apply_request(seat: int, op: String, data: Dictionary, received_at: int) -> String:
	if op == "play":
		return _play(seat, data, received_at)
	if op == "rename":
		return "本桌已开局，结算后可修改昵称。" if _game != null else _rename(seat, data)
	if seat != _owner:
		return "只有房主可以执行这项操作。"
	var target: Variant = data.get("seat", -1)
	var has_target: bool = typeof(target) == TYPE_INT and target >= 0 and target < _seats.size()
	if op == "transfer":
		if not has_target or _seats[target].get("peer", 0) == 0 or target == _owner:
			return "请选择另一位在线真人接任房主。"
		_owner = target
		return ""
	if op in ["next", "lobby"]:
		return _after_result(op, data)
	if _game != null:
		return "本桌进行中，结算后可调整房间。"
	match op:
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
			_game = Game.new(-1, _rounds, "normal", true)
			_begin_stage()
		"add_ai", "update_ai":
			if not has_target:
				return "请选择有效座位。"
			return _set_ai(target, op == "update_ai", data)
		"remove":
			if not has_target or target == 0 or target == _owner or _seats[target].is_empty():
				return "请选择可移除的座位。"
			var player := _seats[target]
			_seats[target] = {}
			if player.kind == "human" and player.peer != 0:
				_drain_peer(player.peer, "房主已将你移出房间。")
		_:
			return "房间不支持这项操作。"
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
	_seats[seat] = {"name": nick, "kind": "ai", "difficulty": difficulty}
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
	if typeof(id) != TYPE_STRING or not _game.act(seat, id):
		return "这项操作当前无效。"
	_begin_stage()
	return ""


func _after_result(op: String, data: Dictionary) -> String:
	if _game == null or _game.phase != "result" or typeof(data.get("stage")) != TYPE_INT or data.stage != _stage:
		return "请等待当前结算。"
	if op == "next":
		if not _game.next_round():
			return "本桌已打完。"
		_begin_stage()
		return ""
	if not _game.is_table_finished():
		return "整桌结束后可返回等候室。"
	_game = null
	_deadline_ms = -1
	_ai_due_ms = -1
	for seat in range(1, _seats.size()):
		if _seats[seat].get("managed", false):
			_seats[seat] = {}
	return ""


func _begin_stage() -> void:
	_stage += 1
	var actor := _game.online_actor()
	var now := Time.get_ticks_msec()
	_deadline_ms = now + _turn_seconds * 1000 if actor >= 0 and _turn_seconds > 0 else -1
	_ai_due_ms = now + AI_DELAY_MS if actor >= 0 and _seats[actor].kind == "ai" else -1


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
	if not move.is_empty() and _game.act(actor, move.id):
		_begin_stage()
		_publish()


func _snapshot(seat: int) -> Dictionary:
	var public_seats: Array[Dictionary] = []
	for player in _seats:
		if player.is_empty():
			public_seats.append({})
		else:
			public_seats.append({"name": player.name, "kind": player.kind, "difficulty": player.difficulty,
				"connected": player.kind == "ai" or player.get("peer", 0) != 0, "managed": player.get("managed", false)})
	var snapshot := {"phase": "lobby" if _game == null else "playing", "my_seat": seat, "owner": _owner,
		"seats": public_seats, "rounds": _rounds, "turn_seconds": _turn_seconds, "port": _port}
	if seat == _owner:
		snapshot.local_addresses = _local_addresses.duplicate()
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
	for seat in range(1, _seats.size()):
		var peer_id: int = _seats[seat].get("peer", 0)
		if peer_id != 0 and peer_id != skip_peer:
			_wire_snapshot.rpc_id(peer_id, _snapshot(seat))
	_apply_snapshot(_snapshot(0))


func _apply_snapshot(snapshot: Dictionary) -> void:
	state = snapshot
	var remaining: int = state.get("remaining_ms", -1)
	if remaining >= 0 and _role == "client":
		# Approximate the snapshot's transit time without comparing machine clocks.
		var round_trip_ms := _peer.get_peer(SERVER).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		remaining = maxi(0, remaining - roundi(round_trip_ms / 2.0))
	_local_deadline_ms = -1 if remaining < 0 else Time.get_ticks_msec() + remaining
	state_changed.emit()
