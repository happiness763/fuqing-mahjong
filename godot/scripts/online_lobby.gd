extends Control

const Art = preload("res://scripts/table_art.gd")
const DEFAULT_PORT := 36712
const INK := Color("#f3e5cb")
const GOLD := Color("#edc780")
const MUTED := Color("#b0bd9e")
const ERROR := Color("#f0a18d")
const CARD := Color("#203a2e")
const BORDER := Color("#6c7553")
const DIFFICULTIES := ["easy", "normal", "hard"]
const DIFFICULTY_NAMES := ["简单", "普通", "困难"]
const WINDS := ["东", "南", "西", "北"]
const TURN_SECONDS := [15, 30, 60, 0]
const TURN_LABELS := ["15 秒", "30 秒", "60 秒", "不限时"]

var desk
var room
var text_font: Font
var title: Label
var subtitle: Label
var back_button: Button
var settings_button: Button
var notice: Label
var entry_screen: Control
var room_screen: Control
var entry_name: LineEdit
var host_port: LineEdit
var join_endpoint: LineEdit
var host_button: Button
var join_button: Button
var seat_rows: Array[Dictionary] = []
var seat_summary: Label
var host_controls: Control
var guest_controls: Control
var listen_label: Label
var lan_address: OptionButton
var lan_copy: Button
var external_address: LineEdit
var external_port: LineEdit
var round_field: LineEdit
var turn_menu: OptionButton
var save_button: Button
var guest_settings: Label
var start_button: Button
var confirm: ConfirmationDialog
var pending_confirmation: Dictionary
var previous_rounds := -1
var previous_turn := -1
var addresses := PackedStringArray()
var can_start := false
var joining_nickname := ""
var arranging_seat := -1
var arranging_id := -1


func setup(table, online_room) -> void:
	desk = table
	room = online_room
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system := SystemFont.new()
	system.font_names = ["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"]
	system.fallbacks = [desk.session_font]
	text_font = system

	var backdrop := ColorRect.new()
	backdrop.color = Color("#14291f")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	desk.panel(self, Rect2(40, 40, 1200, 720), Color("#1a3328"), Color("#605a40"), 24)
	desk.panel(self, Rect2(76, 73, 54, 54), Color("#9b4133"), Color("#d78569"), 9)
	desk.label(self, "福", Rect2(76, 73, 54, 54), 32, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	title = desk.label(self, "", Rect2(148, 63, 750, 48), 39, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	subtitle = desk.label(self, "", Rect2(151, 112, 870, 28), 17, GOLD)
	back_button = desk.button(self, "返回首页", Rect2(1053, 79, 153, 42), desk.exit_online)
	settings_button = desk.button(self, "设置", Rect2(939, 79, 102, 42), desk.show_settings)
	entry_screen = _section(self)
	room_screen = _section(self)
	room_screen.hide()
	_build_entry()
	_build_room()
	notice = desk.label(self, "", Rect2(78, 684, 931, 52), 17, ERROR)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.clip_text = true

	confirm = ConfirmationDialog.new()
	confirm.ok_button_text = "确认"
	confirm.cancel_button_text = "取消"
	confirm.title = "房间管理"
	var dialog_theme := Theme.new()
	dialog_theme.default_font = text_font
	dialog_theme.default_font_size = 17
	confirm.theme = dialog_theme
	confirm.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm.confirmed.connect(_submit_confirmation)
	add_child(confirm)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			confirm.hide())
	refresh()
	if entry_screen.visible:
		entry_name.grab_focus()


func _section(parent: Control) -> Control:
	var section := Control.new()
	section.size = size
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(section)
	return section


func _field(parent: Control, rect: Rect2, placeholder: String, value := "", limit := 0) -> LineEdit:
	var field := LineEdit.new()
	field.position = rect.position
	field.size = rect.size
	field.placeholder_text = placeholder
	field.text = value
	field.max_length = limit
	field.add_theme_font_override("font", text_font)
	field.add_theme_font_size_override("font_size", 17)
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("font_placeholder_color", MUTED)
	var box := Art.box(Color("#192e25"), Color("#75906d"))
	box.content_margin_left = 11
	box.content_margin_right = 11
	field.add_theme_stylebox_override("normal", box)
	field.add_theme_stylebox_override("focus", Art.box(Color.TRANSPARENT, GOLD, 8, 2))
	parent.add_child(field)
	return field


func _menu(parent: Control, rect: Rect2, captions: Array) -> OptionButton:
	var menu := OptionButton.new()
	menu.position = rect.position
	menu.size = rect.size
	menu.fit_to_longest_item = false
	menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.add_theme_font_override("font", text_font)
	menu.add_theme_font_size_override("font_size", 16)
	menu.add_theme_color_override("font_color", INK)
	menu.add_theme_stylebox_override("normal", Art.box(Color("#294638"), Color("#75906d")))
	menu.add_theme_stylebox_override("hover", Art.box(Color("#385647"), Color("#8a9d77")))
	menu.add_theme_stylebox_override("focus", Art.box(Color.TRANSPARENT, GOLD, 8, 2))
	menu.get_popup().add_theme_font_override("font", text_font)
	menu.get_popup().add_theme_font_size_override("font_size", 16)
	for caption in captions:
		menu.add_item(caption)
	parent.add_child(menu)
	return menu


func _build_entry() -> void:
	desk.label(entry_screen, "你的昵称", Rect2(89, 159, 128, 42), 18, INK)
	entry_name = _field(entry_screen, Rect2(218, 159, 274, 42), "输入昵称", desk.preferences.values.nickname)
	desk.label(entry_screen, "1–12 个字符，同一房间内不能重名", Rect2(507, 159, 660, 42), 16, MUTED)
	desk.panel(entry_screen, Rect2(76, 223, 451, 429), CARD, BORDER, 16)
	desk.panel(entry_screen, Rect2(550, 223, 654, 429), CARD, BORDER, 16)
	desk.label(entry_screen, "开房间", Rect2(101, 245, 350, 44), 28, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.label(entry_screen, "开房后可复制房间地址，让朋友加入。", Rect2(101, 297, 401, 29), 17, MUTED)
	desk.label(entry_screen, "监听端口（UDP）", Rect2(101, 346, 395, 28), 17, INK)
	host_port = _field(entry_screen, Rect2(101, 381, 401, 43), "1–65535", str(desk.preferences.values.host_port))
	desk.label(entry_screen, "房间由你的电脑承载，请保持游戏运行。", Rect2(101, 445, 401, 29), 16, MUTED)
	host_button = desk.button(entry_screen, "开房间", Rect2(101, 565, 401, 53), _host, "primary")
	host_port.text_submitted.connect(func(_value): _host())

	desk.label(entry_screen, "加入房间", Rect2(576, 245, 510, 44), 28, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.label(entry_screen, "房间地址", Rect2(576, 297, 500, 28), 17, INK)
	join_endpoint = _field(entry_screen, Rect2(576, 331, 602, 43), "frp-ice.com:45939")
	join_endpoint.text_submitted.connect(func(_value): _join())
	desk.label(entry_screen, "粘贴房主发来的地址和 UDP 端口，可用局域网或穿透地址。",
		Rect2(576, 389, 602, 29), 16, MUTED)
	join_button = desk.button(entry_screen, "加入房间", Rect2(576, 565, 602, 53), _join, "primary")


func _build_room() -> void:
	desk.panel(room_screen, Rect2(76, 162, 658, 493), CARD, BORDER, 16)
	desk.panel(room_screen, Rect2(754, 162, 450, 493), CARD, BORDER, 16)
	desk.label(room_screen, "房间座位", Rect2(99, 180, 610, 38), 25, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	for seat in range(4):
		_build_seat(seat)
	seat_summary = desk.label(room_screen, "", Rect2(99, 613, 611, 26), 16, MUTED)

	host_controls = _section(room_screen)
	desk.label(host_controls, "房间地址", Rect2(776, 180, 402, 38), 25, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	listen_label = desk.label(host_controls, "", Rect2(776, 225, 402, 28), 18, GOLD)
	lan_address = _menu(host_controls, Rect2(776, 261, 250, 40), [])
	lan_copy = desk.button(host_controls, "复制局域网地址", Rect2(1037, 261, 144, 40), _copy_lan)
	desk.label(host_controls, "UDP 穿透（可选）", Rect2(776, 313, 405, 24), 17, INK)
	external_address = _field(host_controls, Rect2(776, 344, 251, 39), "外部 IP 或域名")
	external_port = _field(host_controls, Rect2(1038, 344, 143, 39), "外部 UDP 端口")
	desk.button(host_controls, "复制穿透地址", Rect2(776, 393, 405, 38), _copy_external)
	desk.panel(host_controls, Rect2(776, 446, 405, 1), BORDER, BORDER, 0)
	desk.label(host_controls, "本桌设置", Rect2(776, 455, 404, 38), 25, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.label(host_controls, "局数", Rect2(776, 502, 47, 40), 17, INK)
	round_field = _field(host_controls, Rect2(826, 502, 62, 40), "1–32")
	desk.label(host_controls, "出牌时间", Rect2(931, 502, 72, 40), 17, INK)
	turn_menu = _menu(host_controls, Rect2(1004, 502, 177, 40), TURN_LABELS)
	desk.label(host_controls, "运气  普通（固定）", Rect2(776, 552, 238, 39), 17, MUTED)
	save_button = desk.button(host_controls, "保存设置", Rect2(1045, 552, 136, 39), _save_settings)
	round_field.text_changed.connect(func(_value): _refresh_settings_actions())
	round_field.text_submitted.connect(func(_value): _save_settings())
	turn_menu.item_selected.connect(func(_index): _refresh_settings_actions())

	guest_controls = _section(room_screen)
	desk.label(guest_controls, "本桌设置", Rect2(776, 180, 402, 38), 25, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	guest_settings = desk.label(guest_controls, "", Rect2(776, 237, 405, 136), 20, INK)
	desk.label(guest_controls, "等待房主开局", Rect2(776, 402, 405, 28), 17, MUTED)
	start_button = desk.button(room_screen, "开始游戏", Rect2(1026, 682, 178, 48), _start, "primary")


func _build_seat(seat: int) -> void:
	var row := Control.new()
	row.position = Vector2(99, 226 + seat * 94)
	row.size = Vector2(612, 82)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_screen.add_child(row)
	desk.panel(row, Rect2(0, 0, 612, 82), Color("#1a3328"), Color("#506b54"), 11)
	desk.panel(row, Rect2(12, 12, 58, 58), Color("#294638"), BORDER, 9)
	desk.label(row, WINDS[seat], Rect2(12, 12, 58, 58), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	var caption: Label = desk.label(row, "", Rect2(85, 10, 312, 33), 20, INK)
	caption.add_theme_font_override("font", text_font)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var detail: Label = desk.label(row, "", Rect2(85, 48, 382, 25), 15, MUTED)
	var name := _field(row, Rect2(85, 10, 192, 36), "昵称")
	var difficulty := _menu(row, Rect2(287, 10, 99, 36), DIFFICULTY_NAMES)
	var add: Button = desk.button(row, "添加 AI", Rect2(479, 20, 116, 40), _add_ai.bind(seat))
	var rename: Button = desk.button(row, "改名", Rect2(287, 10, 99, 36), _save_seat.bind(seat, "rename"))
	var save: Button = desk.button(row, "保存 AI", Rect2(396, 10, 94, 36), _save_seat.bind(seat, "update_ai"))
	var transfer: Button = desk.button(row, "转交房主", Rect2(387, 8, 103, 34), _confirm_seat.bind(seat, "transfer"))
	var remove: Button = desk.button(row, "移出座位", Rect2(500, 8, 95, 34), _confirm_seat.bind(seat, "remove"))
	var move: Button = desk.button(row, "", Rect2(479, 43, 116, 33), _change_seat.bind(seat))
	name.text_submitted.connect(func(_value):
		if rename.visible:
			_save_seat(seat, "rename")
		elif save.visible:
			_save_seat(seat, "update_ai"))
	seat_rows.append({
		"caption": caption, "detail": detail, "name": name, "difficulty": difficulty, "add": add,
		"rename": rename, "save": save, "transfer": transfer, "remove": remove, "move": move, "previous": {},
	})


func refresh() -> void:
	var state: Dictionary = room.state
	var active: bool = state.get("phase") == "lobby"
	if active != room_screen.visible:
		confirm.hide()
		if active:
			show_notice("")
		else:
			_clear_arrangement()
			previous_rounds = -1
			previous_turn = -1
			for row in seat_rows:
				row.previous = {}
	room_screen.visible = active
	entry_screen.visible = not active
	back_button.text = "离开房间" if active else "返回首页"
	title.text = "联机等候室" if active else "联机模式"
	subtitle.text = "福清麻将 · 融城茶馆"
	if not active:
		host_button.disabled = room.is_connecting()
		join_button.disabled = host_button.disabled
		if not room.is_connecting():
			joining_nickname = ""
		return
	var reconnecting: bool = state.get("reconnecting", false)
	if reconnecting:
		subtitle.text = "连接中断，正在尝试恢复座位…"
	var owner: bool = state.my_seat == state.owner
	if arranging_seat >= 0:
		if not owner or reconnecting:
			_clear_arrangement()
		elif state.seats[arranging_seat].get("seat_id", -1) != arranging_id:
			_clear_arrangement()
			_set_notice("选中的座位已变化，请重新选座。")
	var occupied := 0
	var ready := 0
	for seat in range(4):
		var occupant: Dictionary = state.seats[seat]
		_refresh_seat(seat, occupant, state, owner)
		if not occupant.is_empty():
			occupied += 1
			if occupant.kind == "ai" or occupant.get("connected", true):
				ready += 1
	seat_summary.text = "已入座 %d / 4" % occupied
	if ready < occupied:
		seat_summary.text += "   ·   等待断线玩家"
	if arranging_seat >= 0:
		seat_summary.text = "正在调整%s座 · 选择目标座位" % WINDS[arranging_seat]
	can_start = owner and not reconnecting and ready == 4
	host_controls.visible = owner
	guest_controls.visible = not owner
	start_button.visible = owner
	_refresh_addresses(state)
	_refresh_settings(state)
	if not joining_nickname.is_empty() and state.seats[state.my_seat].name == joining_nickname:
		desk.save_preferences({"nickname": joining_nickname})
		joining_nickname = ""


func _refresh_seat(seat: int, occupant: Dictionary, state: Dictionary, owner: bool) -> void:
	var row: Dictionary = seat_rows[seat]
	var previous: Dictionary = row.previous
	var kind: String = occupant.get("kind", "")
	var empty := kind.is_empty()
	var ai := kind == "ai"
	var own: bool = seat == state.my_seat
	var can_edit: bool = not state.get("reconnecting", false)
	var arranging := arranging_seat >= 0
	var show_editor := not arranging
	var name: String = occupant.get("name", "")
	var edit_name := show_editor and (own or (owner and ai))
	row.caption.visible = not edit_name
	row.caption.text = "空座" if empty else name
	row.name.visible = edit_name
	var previous_name: String = previous.get("name", "")
	var changed_occupant: bool = occupant.get("seat_id", -1) != previous.get("seat_id", -1)
	if changed_occupant or (name != previous_name
		and (row.name.text == previous_name or row.name.text.strip_edges() == name)):
		row.name.text = name
	row.difficulty.visible = show_editor and owner and ai
	var difficulty := maxi(0, DIFFICULTIES.find(occupant.get("difficulty", "normal")))
	var old_difficulty := DIFFICULTIES.find(previous.get("difficulty", "normal"))
	if changed_occupant or (difficulty != old_difficulty and row.difficulty.selected == old_difficulty):
		row.difficulty.select(difficulty)
	row.add.visible = show_editor and owner and empty
	row.rename.visible = show_editor and own
	row.save.visible = show_editor and owner and ai
	row.remove.visible = show_editor and owner and not empty and not own and seat != state.host_seat
	row.transfer.visible = show_editor and owner and not empty and not own and not ai and occupant.get("connected", true)
	row.move.visible = (arranging or not empty) if owner else empty
	if arranging:
		row.move.text = "取消调座" if arranging_seat == seat else ("移到此座" if empty else "交换座位")
	else:
		row.move.text = "调座" if owner else "换到此座"
	for action in [row.add, row.rename, row.save, row.remove, row.transfer, row.move]:
		action.disabled = not can_edit
	var detail := ""
	if ai:
		detail = "AI · " + DIFFICULTY_NAMES[difficulty]
	elif not empty:
		detail = "真人" if occupant.get("connected", true) else "真人 · 断线保留"
		if own:
			detail += " · 你"
		if seat == state.owner:
			detail += " · 房主"
	row.detail.text = detail
	row.previous = occupant.duplicate()


func _refresh_addresses(state: Dictionary) -> void:
	listen_label.text = "承载端监听 UDP %d" % state.get("port", DEFAULT_PORT)
	var new_addresses := PackedStringArray(state.get("local_addresses", []))
	if addresses != new_addresses:
		var selected := "" if lan_address.selected < 0 else lan_address.get_item_text(lan_address.selected)
		addresses = new_addresses
		lan_address.clear()
		for address in addresses:
			lan_address.add_item(address)
		if addresses.has(selected):
			lan_address.select(addresses.find(selected))
	if addresses.is_empty() and lan_address.item_count == 0:
		lan_address.add_item("未检测到局域网地址")
	lan_address.disabled = addresses.is_empty()
	lan_copy.disabled = addresses.is_empty()


func _refresh_settings(state: Dictionary) -> void:
	var rounds: int = state.get("rounds", 15)
	var seconds: int = state.get("turn_seconds", 60)
	var turn_index := maxi(0, TURN_SECONDS.find(seconds))
	if previous_rounds < 0 or (rounds != previous_rounds and _number(round_field.text, 1, 32) in [previous_rounds, rounds]):
		round_field.text = str(rounds)
	if previous_turn < 0 or (turn_index != previous_turn and turn_menu.selected == previous_turn):
		turn_menu.select(turn_index)
	previous_rounds = rounds
	previous_turn = turn_index
	guest_settings.text = "局数  %d 局\n出牌时间  %s\n运气  普通（固定）" % [rounds, TURN_LABELS[turn_index]]
	_refresh_settings_actions()


func _refresh_settings_actions() -> void:
	var rounds := _number(round_field.text, 1, 32)
	var changed := rounds != previous_rounds or turn_menu.selected != previous_turn
	save_button.disabled = not changed or room.state.get("reconnecting", false)
	start_button.disabled = not can_start or changed
	if changed:
		start_button.tooltip_text = "请先保存本桌设置"
	elif not can_start:
		start_button.tooltip_text = "四个座位就绪后可以开始"
	else:
		start_button.tooltip_text = ""


func show_notice(message: String) -> void:
	_set_notice(message)
	if entry_screen.visible:
		host_button.disabled = room.is_connecting()
		join_button.disabled = host_button.disabled


func _set_notice(message: String, color := ERROR) -> void:
	notice.text = message
	notice.add_theme_color_override("font_color", color)


func _number(raw: String, minimum: int, maximum: int) -> int:
	var value := raw.strip_edges()
	if not value.is_valid_int() or value.length() > 6:
		return -1
	var number := value.to_int()
	return number if number >= minimum and number <= maximum else -1


func _nickname(raw: String, except_seat := -1) -> String:
	var value := raw.strip_edges()
	if value.length() < 1 or value.length() > 12:
		_set_notice("请输入 1–12 个字符的昵称。")
		return ""
	for seat in range(room.state.get("seats", []).size()):
		var occupant: Dictionary = room.state.seats[seat]
		if seat != except_seat and value.nocasecmp_to(occupant.get("name", "")) == 0:
			_set_notice("这个昵称已被占用，请换一个。")
			return ""
	return value


func _address(raw: String) -> String:
	var value := raw.strip_edges()
	if value.begins_with("[") and value.ends_with("]"):
		value = value.substr(1, value.length() - 2)
		return value if ":" in value and value.is_valid_ip_address() else ""
	if value.is_valid_ip_address():
		return value
	if value.is_empty() or value.length() > 253:
		return ""
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.":
			return ""
	return value


func _host() -> void:
	if host_button.disabled:
		return
	var nick := _nickname(entry_name.text)
	if nick.is_empty():
		return
	var port := _number(host_port.text, 1, 65535)
	if port < 0:
		_set_notice("监听端口应为 1–65535 的整数。")
		return
	_set_notice("")
	var preferences: Dictionary = desk.preferences.values
	var error: String = room.host(nick, port, preferences.room_rounds, preferences.turn_seconds)
	if error.is_empty():
		desk.save_preferences({"nickname": nick, "host_port": port})
		refresh()
	else:
		show_notice(error)


func parse_endpoint(raw: String) -> Dictionary:
	var value := raw.strip_edges()
	var separator := value.rfind(":")
	if separator < 1:
		return {}
	var host := value.left(separator)
	if ":" in host and not host.begins_with("["):
		return {}
	var address := _address(host)
	var port := _number(value.substr(separator + 1), 1, 65535)
	if address.is_empty() or port < 0:
		return {}
	return {"address": address, "port": port}


func _join() -> void:
	if join_button.disabled:
		return
	var nick := _nickname(entry_name.text)
	if nick.is_empty():
		return
	var endpoint := parse_endpoint(join_endpoint.text)
	if endpoint.is_empty():
		_set_notice("请输入有效的房间地址（frp-ice.com:45939）。")
		return
	_set_notice("正在连接房间…", MUTED)
	joining_nickname = nick
	var error: String = room.join(nick, endpoint.address, endpoint.port)
	if error.is_empty():
		refresh()
	else:
		joining_nickname = ""
		show_notice(error)


func _copy_lan() -> void:
	if lan_address.selected >= 0 and lan_address.selected < addresses.size():
		_copy_endpoint(addresses[lan_address.selected], int(room.state.port))


func _copy_external() -> void:
	var address := _address(external_address.text)
	var port := _number(external_port.text, 1, 65535)
	if address.is_empty() or port < 0:
		_set_notice("请填写有效的外部 IP 或域名，以及 1–65535 的 UDP 端口。")
	else:
		_copy_endpoint(address, port)


func _copy_endpoint(address: String, port: int) -> void:
	var host := "[%s]" % address if ":" in address else address
	DisplayServer.clipboard_set("%s:%d" % [host, port])
	_set_notice("已复制房间地址，可直接发给朋友。", MUTED)


func _add_ai(seat: int) -> void:
	var taken := PackedStringArray()
	for occupant in room.state.seats:
		taken.append(str(occupant.get("name", "")).to_lower())
	var number := seat + 1
	while ("ai %d" % number) in taken:
		number += 1
	_request("add_ai", {"seat": seat, "name": "AI %d" % number, "difficulty": "normal"})


func _save_seat(seat: int, operation: String) -> void:
	if room.state.get("reconnecting", false):
		return
	var row: Dictionary = seat_rows[seat]
	var name := _nickname(row.name.text, seat)
	if name.is_empty():
		return
	var data := {"name": name}
	if operation == "update_ai":
		data["seat"] = seat
		data["seat_id"] = row.previous.get("seat_id", -1)
		data["difficulty"] = DIFFICULTIES[row.difficulty.selected]
	_request(operation, data)


func _clear_arrangement() -> void:
	arranging_seat = -1
	arranging_id = -1


func _change_seat(seat: int) -> void:
	var state: Dictionary = room.state
	if state.get("phase") != "lobby" or state.get("reconnecting", false) or not seat_rows[seat].move.visible:
		return
	if state.my_seat != state.owner:
		_request("move_seat", {"from": state.my_seat, "seat": seat})
		return
	var seat_id: int = state.seats[seat].get("seat_id", -1)
	if arranging_seat < 0:
		arranging_seat = seat
		arranging_id = seat_id
		_set_notice("")
	elif arranging_seat == seat:
		_clear_arrangement()
	else:
		var data := {"from": arranging_seat, "seat": seat, "from_id": arranging_id, "seat_id": seat_id}
		_clear_arrangement()
		_request("arrange_seats", data)
	refresh()


func _confirm_seat(seat: int, operation: String) -> void:
	var occupant: Dictionary = room.state.seats[seat]
	pending_confirmation = {"seat": seat, "op": operation, "name": occupant.name, "seat_id": occupant.seat_id}
	if operation == "transfer":
		confirm.dialog_text = "将房主权限转交给「%s」？承载房间的电脑需要继续运行游戏。" % occupant.name
	elif occupant.kind == "ai":
		confirm.dialog_text = "将 AI「%s」移出座位？" % occupant.name
	else:
		confirm.dialog_text = "将「%s」移出房间？" % occupant.name
	confirm.popup_centered(Vector2i(470, 174))


func _submit_confirmation() -> void:
	var state: Dictionary = room.state
	if state.get("phase") != "lobby" or state.my_seat != state.owner or state.get("reconnecting", false):
		return
	var seat: int = pending_confirmation.seat
	if state.seats[seat].get("seat_id") != pending_confirmation.seat_id or state.seats[seat].get("name") != pending_confirmation.name:
		_set_notice("座位已变化，请确认后再操作。")
		return
	_request(pending_confirmation.op, {"seat": seat, "seat_id": pending_confirmation.seat_id})


func _save_settings() -> void:
	if room.state.get("reconnecting", false):
		return
	var rounds := _number(round_field.text, 1, 32)
	if rounds < 0:
		_set_notice("请输入 1–32 的整数作为局数。")
		return
	var seconds: int = TURN_SECONDS[turn_menu.selected]
	_request("settings", {"rounds": rounds, "turn_seconds": seconds})


func _start() -> void:
	if not start_button.disabled:
		_request("start")


func _request(operation: String, data := {}) -> void:
	_set_notice("")
	room.request(operation, data)
