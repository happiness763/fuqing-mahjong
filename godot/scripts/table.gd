extends Control

const Rules = preload("res://scripts/rules.gd")
const Game = preload("res://scripts/game.gd")
const Opponent = preload("res://scripts/opponent.gd")
const Art = preload("res://scripts/table_art.gd")
const CenterDial = preload("res://scripts/center_dial.gd")
const Preferences = preload("res://scripts/preferences.gd")
const Skins = preload("res://scripts/tile_skins.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const Tile = preload("res://scripts/tile_view.gd")
const Lobby = preload("res://scripts/lobby.gd")
const OnlineLobby = preload("res://scripts/online_lobby.gd")
const OnlineRoom = preload("res://scripts/online_room.gd")
const OnlineTableView = preload("res://scripts/online_table_view.gd")
const OpeningIntro = preload("res://scripts/opening_intro.gd")
const Stats = preload("res://scripts/stats.gd")
const StatsPanel = preload("res://scripts/stats_panel.gd")
const TableWall = preload("res://scripts/table_wall.gd")
const Interactions = preload("res://scripts/table_interaction.gd")
const Effects = preload("res://scripts/table_effects.gd")
const SLIDE_DURATION := 0.23
const SLIDE_FADE := 0.16
const UI_FONT = preload("res://assets/fonts/NotoSansSC.woff2")
const ACTION_FONT = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const DESIGN_SIZE := Vector2(1280, 800)
const NAMES := ["你", "阿岚", "阿榕", "阿屿"]
const MARKS := ["你", "岚", "榕", "屿"]
const WINDS = OnlineTableView.WINDS
const PORTRAITS := [Color("#d8ab70"), Color("#a2b38e"), Color("#87aa99"), Color("#bf9b8a")]
const INK := Color("#f3e5cb")
const MUTED := Color("#b0bd9e")
const GOLD := Color("#edc780")
const REDEAL_NOTICE := "首巡四家同牌 · 流局"
const BUTTON := Color("#294638")
const FONT_DARK := Color("#202e25")
const GOLD_AREA := Rect2(842, 52, 194, 112)
const SEAT_POSITIONS := [Vector2(63, 640), Vector2(915, 290), Vector2(472, 40), Vector2(58, 290)]

var game
var action_font: FontVariation
var windowed_bounds := Rect2i()
var windowed_mode := Window.MODE_WINDOWED
var fx: Control
var effects := "full"
var fx_result_hand := -1
var winning_tile_rect := Rect2()
var fx_hold_active := false
var fx_hold_results := true
var fx_hold_timer: Timer
var board_art: Control
var center_dial: CenterDial
var wall_art: TableWall
var wall_flights: Control
var wall_hand := -1
var wall_gold_from := Vector2.INF
var wall_draw_from := Vector2.INF
var interactions: Interactions
var lobby: Control
var header: Control
var menu_button: Button
var menu_panel: Panel
var menu_backdrop: Control
var status_label: Label
var room
var online_lobby: Control
var online_view := {}
var online_stage := -1
var online_owner := -1
var online_reconnecting := false
var pending_stage := -1
var last_notice := ""
var notice_until := 0
var room_notice_label: Label
var countdown_label: Label
var chooser_countdown: Label
var modal_tracks_stage := false
var transfer_button: Button
var leave_button: Button
var nickname_font: Font
var settings := {"rounds": 25, "difficulty": "normal", "luck": "normal"}
var preferences_root := "user://"
var preferences: Preferences
var stats
var stats_table_id := ""
var stats_round_hand_id := -1
var stats_round_started_ms := 0
var stats_round_started_at := 0
var stats_recorded_hand_id := -1
var stats_panel: Control
var settings_panel: Control
var applied_skin := ""
var selected_index := -1
var selected_tile := -1
var intro
var intro_timer: Timer
var intro_visible_hand := -1
var intro_flowers := true
var intro_gold := true
var flower_timer: Timer
var flower_fx: Control
var flower_sequence: Array = []
var flower_index := 0
var flower_done: Callable
var flower_active := false
var flower_preview := false
var flower_preview_hand: Array = []
var flower_hold_drawn := false
var flower_slide_index := -1
var flower_slide_started := 0
var flower_slide_from := Vector2.INF
var flower_status_text := ""
var draw_flower_active := false
var last_flower_revision := -1
var dealer_roll_panel: Panel
var dealer_roll_timer: Timer
var dealer_roll_callback: Callable
var dealer_roll_shown_round := -1
var dealer_roll_state: Dictionary = {}
var dealer_roll_rows: Array = []
var dealer_roll_status: Label
var dealer_roll_button: Button
var dealer_roll_start_button: Button
var dealer_roll_dice_label: Label
var dealer_roll_online := false
var dealer_roll_online_ready := false
var dealer_roll_animating := false
var dealer_roll_auto_roll := false
var dealer_roll_rng := RandomNumberGenerator.new()
var online_roll_names: Array = []
var online_rolling := false
var session_font: Font
var title_font: Font
var faces: Array[Texture2D] = []
var dynamic: Control
var modal: Control
var ai_timer: Timer
var redeal_timer: Timer
var redeal_notice: Panel
var audio: AudioStreamPlayer
var sounds: Dictionary
var sound_button: Button
var muted := false
var log_lines: Array[String] = []
var action_banner: Panel
var action_messages: Array[Dictionary] = []
var last_revision := -1
var shown_round := -1
var human_buttons: Array[Button] = []
var controls: Dictionary = {}
var suspended_focus: Array[Control] = []


func _ready() -> void:
	anchors_preset = Control.PRESET_TOP_LEFT
	size = DESIGN_SIZE
	session_font = UI_FONT
	action_font = FontVariation.new()
	action_font.base_font = ACTION_FONT
	action_font.fallbacks = [UI_FONT]
	title_font = system_font(["KaiTi", "SimSun", "Microsoft YaHei", "Noto Serif CJK SC"])
	nickname_font = system_font(["Microsoft YaHei UI", "Microsoft YaHei", "SimSun", "Segoe UI"])
	preferences = Preferences.new(preferences_root)
	stats = Stats.new(preferences_root)
	for key in settings:
		settings[key] = preferences.values[key]
	board_art = Art.new()
	add_child(board_art)
	center_dial = CenterDial.new()
	center_dial.setup(session_font)
	center_dial.position = Art.CENTER - CenterDial.MIDPOINT
	center_dial.hide()
	board_art.add_child(center_dial)
	countdown_label = center_dial.clock
	wall_art = TableWall.new()
	wall_art.name = "TileWall"
	wall_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall_art)
	wall_flights = Control.new()
	wall_flights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_flights.z_index = 1
	add_child(wall_flights)
	build_header()
	fx = Effects.new()
	fx.setup(self, action_font, session_font, SEAT_POSITIONS, Art.CENTER)
	add_child(fx)
	configure_display()
	apply_saved_appearance()
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	add_child(ai_timer)
	ai_timer.timeout.connect(run_ai)
	redeal_timer = Timer.new()
	redeal_timer.one_shot = true
	add_child(redeal_timer)
	redeal_timer.timeout.connect(restart_after_draw)
	intro_timer = Timer.new()
	intro_timer.one_shot = true
	add_child(intro_timer)
	intro_timer.timeout.connect(advance_intro)
	fx_hold_timer = Timer.new()
	fx_hold_timer.one_shot = true
	add_child(fx_hold_timer)
	fx_hold_timer.timeout.connect(_finish_fx_hold)
	flower_fx = Control.new()
	flower_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flower_fx.z_index = 15
	add_child(flower_fx)
	flower_timer = Timer.new()
	flower_timer.one_shot = true
	add_child(flower_timer)
	flower_timer.timeout.connect(advance_flower)
	dealer_roll_timer = Timer.new()
	dealer_roll_timer.one_shot = true
	add_child(dealer_roll_timer)
	dealer_roll_timer.timeout.connect(_dealer_roll_tick)
	audio = AudioStreamPlayer.new()
	audio.volume_db = -12.0
	add_child(audio)
	sounds = {
		"pick": strike(380.0, 0.045, 18),
		"discard": strike(266.0, 0.097, 42),
		"claim": strike(520.0, 0.150, 64),
		"interaction": strike(315.0, 0.095, 31),
		"win": chime([523.25, 659.25, 783.99], 0.55),
		"win_gold": chime([783.99, 1046.5, 1318.5], 0.5),
		"win_jade": chime([659.25, 830.61], 0.55),
		"win_stamp": chime([130.81, 196.0], 0.24),
		"win_heaven": chime([523.25, 784.0, 1046.5, 1568.0], 0.95),
		"win_coin": chime([1046.5, 1318.5], 0.2),
	}
	interactions = Interactions.new()
	add_child(interactions)
	interactions.setup(self)
	room = OnlineRoom.new()
	room.name = "OnlineRoom"
	room.state_changed.connect(room_state_changed)
	room.notice.connect(show_room_notice)
	room.preferences_confirmed.connect(save_preferences)
	room.interaction.connect(func(source: int, target: int, kind: String):
		if not online_view.is_empty() and not online_reconnecting:
			var local: int = room.state.my_seat
			interactions.play(posmod(source - local, 4), posmod(target - local, 4), kind))
	add_child(room)
	show_lobby()


func system_font(names: PackedStringArray) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = names
	font.fallbacks = [UI_FONT]
	return font


func strike(pitch: float, duration: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	var samples := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in range(samples):
		var t := float(index) / stream.mix_rate
		var resonances := sin(TAU * pitch * t) * 0.36 + sin(TAU * pitch * 2.43 * t) * 0.26
		var attack := rng.randf_range(-1.0, 1.0) * exp(-t * 180) * 0.38
		var sample := (resonances * exp(-t * 43) + attack) * minf(1.0, index / 12.0)
		data.encode_s16(index * 2, int(sample * 26000))
	stream.data = data
	return stream


func play_sound(kind: String) -> void:
	if muted:
		return
	audio.stream = sounds[kind]
	audio.play()


func chime(frequencies: Array, duration: float, volume := 0.62) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	var samples := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in range(samples):
		var t := float(index) / stream.mix_rate
		var amplitude := 0.0
		for frequency: Variant in frequencies:
			amplitude += sin(TAU * float(frequency) * t)
		amplitude /= maxf(1.0, float(frequencies.size()))
		var envelope := exp(-t * 2.6) * minf(1.0, index / 36.0)
		data.encode_s16(index * 2, int(amplitude * envelope * volume * 28000))
	stream.data = data
	return stream


func label(parent: Node, copy: String, rect: Rect2, font_size: int, color := INK,
		align := HORIZONTAL_ALIGNMENT_LEFT, display_font := false) -> Label:
	var node := Label.new()
	node.text = copy
	node.position = rect.position
	node.size = rect.size
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", title_font if display_font else session_font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


func panel(parent: Node, rect: Rect2, fill: Color, border: Color, radius := 8) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", Art.box(fill, border, radius))
	parent.add_child(node)
	return node


func button(parent: Node, copy: String, rect: Rect2, handler: Callable, style := "normal") -> Button:
	var node := Button.new()
	node.text = copy
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", session_font)
	node.add_theme_font_size_override("font_size", 15)
	var base := BUTTON
	var border := Color("#587159")
	var text_color := INK
	if style == "primary":
		base = Color("#d2a663")
		border = Color("#edc780")
		text_color = FONT_DARK
	elif style == "win":
		base = Color("#9e4234")
		border = Color("#d28065")
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", text_color)
	node.add_theme_color_override("font_pressed_color", text_color)
	node.add_theme_color_override("font_focus_color", text_color)
	node.add_theme_color_override("font_disabled_color", Color("#81917a"))
	node.add_theme_stylebox_override("normal", Art.box(base, border))
	node.add_theme_stylebox_override("hover", Art.box(base.lightened(0.12), border.lightened(0.1)))
	node.add_theme_stylebox_override("pressed", Art.box(base.darkened(0.12), border))
	node.add_theme_stylebox_override("disabled", Art.box(Color("#293e32"), Color("#405747")))
	node.add_theme_stylebox_override("focus", Art.box(Color.TRANSPARENT, GOLD, 8, 2))
	if handler.is_valid():
		node.pressed.connect(handler)
	parent.add_child(node)
	return node


func build_header() -> void:
	header = Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	menu_button = button(header, "菜单", Rect2(1083, 16, 169, 44), toggle_menu)
	menu_button.z_index = 20
	menu_panel = panel(header, Rect2(1083, 64, 169, 272), Color("#203a2e"), Color("#ab8852"), 12)
	menu_panel.visible = false
	menu_panel.z_index = 21
	sound_button = menu_row(menu_panel, 0, "声音  开", _menu_sound)
	menu_row(menu_panel, 1, "玩法规则", _menu_rules)
	menu_row(menu_panel, 2, "数据统计", _menu_stats)
	transfer_button = menu_row(menu_panel, 3, "移交房主", _menu_transfer)
	transfer_button.hide()
	menu_row(menu_panel, 4, "设置", show_settings)
	leave_button = menu_row(menu_panel, 5, "返回首页", _menu_leave)


func menu_row(parent: Control, index: int, copy: String, handler: Callable) -> Button:
	var node := button(parent, copy, Rect2(10, 10 + index * 42, 149, 36), handler)
	node.z_index = 22
	return node


func toggle_menu() -> void:
	if menu_open():
		close_menu()
		return
	menu_panel.visible = true
	interactions.close()
	if not is_instance_valid(menu_backdrop):
		menu_backdrop = Control.new()
		menu_backdrop.position = board_art.background_area.position
		menu_backdrop.size = board_art.background_area.size
		menu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		menu_backdrop.z_index = 19
		menu_backdrop.gui_input.connect(_menu_backdrop_input)
		header.add_child(menu_backdrop)
		header.move_child(menu_panel, header.get_child_count() - 1)
	menu_button.grab_focus()


func _menu_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_menu()


func close_menu() -> void:
	if is_instance_valid(menu_backdrop):
		menu_backdrop.get_parent().remove_child(menu_backdrop)
		menu_backdrop.queue_free()
		menu_backdrop = null
	if is_instance_valid(menu_panel):
		menu_panel.visible = false


func menu_open() -> bool:
	return is_instance_valid(menu_panel) and menu_panel.visible


func _menu_sound() -> void:
	toggle_sound()
	close_menu()


func _menu_rules() -> void:
	close_menu()
	show_rules()


func _menu_stats() -> void:
	close_menu()
	show_stats("overview")


func _menu_transfer() -> void:
	close_menu()
	show_transfer()


func _menu_leave() -> void:
	close_menu()
	show_reset()


func toggle_sound() -> void:
	if not save_preferences({"muted": not muted}):
		return
	muted = preferences.values.muted
	if muted:
		audio.stop()
	sound_button.text = "声音  关" if muted else "声音  开"


func save_preferences(changes: Dictionary) -> bool:
	if preferences.update(changes) == OK:
		for key in changes:
			if settings.has(key):
				settings[key] = preferences.values[key]
		if changes.has("nickname") and is_instance_valid(online_lobby):
			online_lobby.entry_name.text = preferences.values.nickname
		return true
	if is_instance_valid(lobby):
		lobby.show_save_error()
	elif is_instance_valid(online_lobby) and online_lobby.visible:
		online_lobby.show_notice("无法保存设置，原设置已保留。")
	else:
		last_notice = "无法保存设置，原设置已保留。"
		notice_until = Time.get_ticks_msec() + 4000
		if online_view.is_empty():
			var warning := label(self, last_notice, Rect2(780, 67, 288, 38), 16, GOLD)
			warning.z_index = 40
			warning.create_tween().tween_callback(warning.queue_free).set_delay(4.0)
	return false


func show_settings() -> void:
	if is_instance_valid(modal):
		return
	close_menu()
	var dialog := open_modal("设置", 706, 679, false)
	modal.z_index = 40
	settings_panel = SettingsPanel.new()
	dialog.add_child(settings_panel)
	settings_panel.setup(self)


func show_stats(initial_tab := "overview", entry := {}) -> void:
	close_menu()
	if board_view().get("phase") == "result":
		shown_round = -1
	var dialog := open_modal("数据统计", 1040, 700)
	modal.z_index = 40
	stats_panel = StatsPanel.new()
	dialog.add_child(stats_panel)
	stats_panel.setup(self, initial_tab, entry)


func effective_effects() -> String:
	var mode := str(preferences.values.get("effects", "full"))
	if mode == "off":
		return "off"
	if OS.get_name() == "Android" and OS.get_processor_count() <= 4:
		return "simple"
	return mode


func apply_saved_appearance() -> void:
	apply_fullscreen(bool(preferences.values.fullscreen))
	effects = effective_effects()
	if is_instance_valid(fx):
		fx.set_mode(effects)
	if is_instance_valid(board_art):
		board_art.set_ambience(effects == "full")
	muted = preferences.values.muted
	sound_button.text = "声音  关" if muted else "声音  开"
	board_art.set_table_texture(preferences.table_texture(preferences.values.table_id))
	if applied_skin != preferences.values.skin:
		applied_skin = preferences.values.skin
		faces = Skins.faces(applied_skin)
		for node in find_children("*", "Button", true, false):
			if node is Tile and node.number >= 0 and node.number < faces.size():
				node.texture = faces[node.number]
				node.guobiao_face = applied_skin == "guobiao"
				node.queue_redraw()


func configure_display() -> void:
	var window := get_window()
	window.size_changed.connect(layout_screen)
	if OS.get_name() == "Windows" and DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		if usable.has_area():
			var available := (usable.size - Vector2i(32, 48)).max(Vector2i(320, 200))
			window.min_size = Vector2i(864, 540).min(available)
			var fit := minf(1.0, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
			window.size = Vector2i(DESIGN_SIZE * fit)
			window.position = usable.position + (usable.size - window.size) / 2
	layout_screen()


func layout_screen() -> void:
	var canvas := get_viewport_rect().size
	var area := Rect2(Vector2.ZERO, canvas)
	if OS.get_name() == "Android":
		var window := get_window()
		var safe_pixels := DisplayServer.get_display_safe_area()
		if safe_pixels.has_area() and window.size.x > 0 and window.size.y > 0:
			var ratio := canvas / Vector2(window.size)
			area = area.intersection(Rect2(Vector2(safe_pixels.position - window.position) * ratio,
				Vector2(safe_pixels.size) * ratio))
			if not area.has_area():
				area = Rect2(Vector2.ZERO, canvas)
	var factor := minf(1.0, minf(area.size.x / DESIGN_SIZE.x, area.size.y / DESIGN_SIZE.y))
	if factor <= 0.0:
		return
	scale = Vector2.ONE * factor
	position = area.position + (area.size - DESIGN_SIZE * factor) * 0.5
	var background := Rect2(-position / factor, canvas / factor)
	board_art.set_background_area(background)
	if is_instance_valid(menu_backdrop):
		menu_backdrop.position = background.position
		menu_backdrop.size = background.size


func apply_fullscreen(enabled: bool) -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if enabled and window.mode != Window.MODE_FULLSCREEN:
		windowed_mode = window.mode
		windowed_bounds = Rect2i(window.position, window.size)
		window.mode = Window.MODE_FULLSCREEN
	elif not enabled and window.mode == Window.MODE_FULLSCREEN:
		window.mode = windowed_mode
		if windowed_mode == Window.MODE_WINDOWED and windowed_bounds.has_area():
			window.size = windowed_bounds.size
			window.position = windowed_bounds.position


func _input(event: InputEvent) -> void:
	if OS.get_name() != "Windows" or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_F11:
		var enabled := get_window().mode != Window.MODE_FULLSCREEN
		if preferences.update({"fullscreen": enabled}) == OK:
			apply_fullscreen(enabled)
			if is_instance_valid(settings_panel) and is_instance_valid(settings_panel.fullscreen):
				settings_panel.fullscreen.set_pressed_no_signal(enabled)
		get_viewport().set_input_as_handled()


func show_lobby() -> void:
	interactions.reset()
	close_modal(false)
	close_menu()
	cancel_dealer_roll()
	cancel_flower_sequence()
	draw_flower_active = false
	last_flower_revision = -1
	dealer_roll_shown_round = -1
	intro = null
	intro_timer.stop()
	board_art.set_dice(Vector2i.ZERO)
	ai_timer.stop()
	redeal_timer.stop()
	game = null
	stats_table_id = ""
	stats_round_hand_id = -1
	stats_recorded_hand_id = -1
	_reset_wall()
	clear_selection()
	clear_board()
	clear_action_banner()
	if is_instance_valid(fx):
		fx_result_hand = -1
		fx_hold_active = false
		if is_instance_valid(fx_hold_timer):
			fx_hold_timer.stop()
		fx.stop_win()
		fx.set_active(-1)
		fx.set_urgent(false)
	transfer_button.hide()
	leave_button.text = "返回首页"
	header.hide()
	lobby = Lobby.new()
	add_child(lobby)
	lobby.setup(self, settings)


func clear_board() -> void:
	if is_instance_valid(dynamic):
		remove_child(dynamic)
		dynamic.queue_free()
		dynamic = null
	human_buttons.clear()
	controls.clear()
	center_dial.hide()
	redeal_notice = null
	room_notice_label = null
	status_label = null


func show_online() -> void:
	if is_instance_valid(online_lobby):
		return
	close_modal(false)
	if is_instance_valid(lobby):
		remove_child(lobby)
		lobby.queue_free()
		lobby = null
	last_notice = ""
	online_lobby = OnlineLobby.new()
	add_child(online_lobby)
	online_lobby.setup(self, room)


func exit_online() -> void:
	if is_instance_valid(online_lobby):
		remove_child(online_lobby)
		online_lobby.queue_free()
		online_lobby = null
	cancel_dealer_roll()
	cancel_flower_sequence()
	draw_flower_active = false
	last_flower_revision = -1
	dealer_roll_shown_round = -1
	online_rolling = false
	online_view = {}
	online_stage = -1
	online_owner = -1
	online_reconnecting = false
	pending_stage = -1
	room.leave()
	show_lobby()


func room_state_changed() -> void:
	if not is_instance_valid(online_lobby):
		return
	var snapshot: Dictionary = room.state
	var phase: String = snapshot.get("phase", "")
	if phase == "rolling":
		if not online_rolling:
			online_lobby.refresh()
			online_lobby.hide()
		online_rolling = true
		header.show()
		leave_button.text = "退出房间"
		show_online_dealer_roll(snapshot)
		return
	if phase != "playing":
		stats_table_id = ""
		stats_round_hand_id = -1
		stats_recorded_hand_id = -1
		var was_rolling := online_rolling
		online_rolling = false
		close_online_dealer_roll()
		if not online_view.is_empty():
			_reset_wall()
			intro = null
			intro_timer.stop()
			cancel_flower_sequence()
			draw_flower_active = false
			interactions.reset()
			cancel_dealer_roll()
			dealer_roll_shown_round = -1
			close_modal(false)
			clear_board()
			clear_action_banner()
			clear_selection()
			online_view = {}
			online_stage = -1
			online_owner = -1
			online_reconnecting = false
			pending_stage = -1
			header.hide()
			online_lobby.show()
		elif was_rolling:
			header.hide()
			online_lobby.show()
		online_lobby.refresh()
		if snapshot.is_empty() and not last_notice.is_empty():
			online_lobby.show_notice(last_notice)
		return

	var entering := online_view.is_empty()
	if entering and stats_table_id.is_empty():
		stats_table_id = _new_stats_table_id()
		stats_round_hand_id = -1
		stats_recorded_hand_id = -1
	if entering and dealer_roll_online and dealer_roll_animating:
		return
	var stage: int = snapshot.stage
	var owner: int = snapshot.owner
	var reconnecting: bool = snapshot.get("reconnecting", false)
	var next_view := OnlineTableView.from_room(snapshot)
	var hand_changed: bool = entering or next_view.round != online_view.round or hand_key(next_view) != hand_key(online_view)
	var stage_changed := online_stage != stage
	var owner_changed := owner != online_owner
	var resync := reconnecting or online_reconnecting or (not entering and stage > online_stage + 1)
	if not (hand_changed or stage_changed or owner_changed or reconnecting != online_reconnecting
		or next_view.seat_info != online_view.seat_info):
		return
	if stage_changed or reconnecting:
		if modal_tracks_stage:
			close_modal(false)
		clear_selection()
		pending_stage = -1
	if not hand_changed and (resync or (stage_changed and (intro_active() or flower_active))):
		cancel_hand_animations(next_view)
	if owner_changed and next_view.phase == "result":
		if modal_tracks_stage:
			close_modal(false)
		shown_round = -1
	online_view = next_view
	online_stage = stage
	online_owner = owner
	online_reconnecting = reconnecting
	if entering:
		last_notice = ""
		online_lobby.hide()
		header.show()
		leave_button.text = "退出房间"
		online_rolling = false
		close_online_dealer_roll()
		if is_instance_valid(fx):
			fx.play_entrance()
	transfer_button.visible = is_room_owner() and not reconnecting
	var fresh_opening := hand_changed and not resync and (not entering or stage == 1)
	if fresh_opening and next_view.latest.type == "start" \
		and next_view.phase not in ["result", "redeal"]:
		start_intro()
	else:
		if hand_changed:
			reset_hand_presentation(next_view)
		refresh(stage_changed and not hand_changed and not resync)


func show_room_notice(message: String) -> void:
	last_notice = message
	if online_view.is_empty():
		if is_instance_valid(online_lobby):
			online_lobby.show_notice(message)
	else:
		pending_stage = -1
		notice_until = Time.get_ticks_msec() + 4000
		if not is_instance_valid(modal) or is_instance_valid(settings_panel):
			refresh()


func is_room_owner() -> bool:
	return room.state.get("owner", -1) == room.state.get("my_seat", -2)


func board_view() -> Dictionary:
	if not online_view.is_empty():
		return online_view
	return game.view(0) if game != null else {}


func hand_key(view: Dictionary) -> int:
	return int(view.get("hand_id", view.get("round", -1)))


func local_moves() -> Array:
	if intro_active() or draw_flower_active or flower_active or is_instance_valid(dealer_roll_panel):
		return []
	if not online_view.is_empty():
		if online_reconnecting or pending_stage == online_stage or online_view.phase == "redeal":
			return []
		return room.state.get("moves", [])
	return game.actions(0) if game != null else []


func player_name(seat: int) -> String:
	return NAMES[seat] if online_view.is_empty() else online_view.seat_info[seat].name


func seat_wind(seat: int) -> String:
	var viewer: int = room.state.get("my_seat", 0) if online_rolling or not online_view.is_empty() else 0
	return WINDS[posmod(viewer + seat, 4)]


func player_mark(seat: int) -> String:
	return MARKS[seat] if online_view.is_empty() else player_name(seat).left(1)


func set_player_font(node: Label) -> void:
	if not online_view.is_empty():
		node.add_theme_font_override("font", nickname_font)
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func begin_game(selections: Dictionary) -> void:
	if not is_instance_valid(lobby):
		return
	settings = selections.duplicate()
	stats_table_id = _new_stats_table_id()
	stats_round_hand_id = -1
	stats_recorded_hand_id = -1
	fx_result_hand = -1
	remove_child(lobby)
	lobby.queue_free()
	lobby = null
	header.show()
	if is_instance_valid(fx):
		fx.play_entrance()
	dealer_roll_shown_round = -1
	dealer_roll_rng.randomize()
	var state := Rules.dealer_roll_state(dealer_roll_rng)
	show_dealer_roll(state, func():
		game = Game.new(-1, settings.rounds, settings.luck, false, int(state.winner))
		game.dealer_rolls = state
		start_intro())


func _new_stats_table_id() -> String:
	return "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]


func _track_stats(view: Dictionary) -> void:
	if stats == null:
		return
	var phase := str(view.get("phase", ""))
	var hand_id := int(view.get("hand_id", -1))
	if phase not in ["result", "redeal"] and hand_id != stats_round_hand_id:
		stats_round_hand_id = hand_id
		stats_round_started_ms = Time.get_ticks_msec()
		stats_round_started_at = int(Time.get_unix_time_from_system())
	if phase in ["result", "redeal"] and hand_id != stats_recorded_hand_id:
		if stats_table_id.is_empty():
			stats_table_id = _new_stats_table_id()
		stats.record_round(_build_stats_entry(view))
		stats_recorded_hand_id = hand_id


func _build_stats_entry(view: Dictionary) -> Dictionary:
	var result: Dictionary = view.get("result", {})
	var winner := int(result.get("winner", -1))
	var from_seat := int(result.get("from", -1))
	var method := str(result.get("method", result.get("kind", "")))
	var gold := int(view.get("gold", -1))
	var deltas: Array = result.get("deltas", [0, 0, 0, 0])
	var names: Array = []
	var players: Array = []
	for seat in range(4):
		var player: Dictionary = view.players[seat]
		var meld_counts := {"chow": 0, "pong": 0, "kong": 0, "addedKong": 0, "concealedKong": 0}
		for meld in player.melds:
			if meld is Dictionary and meld_counts.has(meld.get("type", "")):
				meld_counts[meld.type] = int(meld_counts.get(meld.type, 0)) + 1
		var shown_hand: Array = Array(player.get("hand", [])).duplicate()
		names.append(player_name(seat))
		players.append({
			"hand": shown_hand if seat == winner else [],
			"melds": Array(player.get("melds", [])).duplicate(true),
			"flowers": Array(player.get("flowers", [])).duplicate(),
			"meld_counts": meld_counts,
			"flower_count": Array(player.get("flowers", [])).size(),
			"gold_count": Rules.gold_count(shown_hand, gold),
			"discarded_gold": bool(player.get("discarded_gold", false)),
			"gold_discards": int(player.get("gold_discards", 0)),
			"gold_gap": Array(player.get("gold_gap", [])).duplicate(),
			"pass_pong": int(player.get("pass_pong", 0)),
			"pass_win": int(player.get("pass_win", 0)),
			"discard_count": int(player.get("discard_count", 0)),
			"draw_count": int(player.get("draw_count", 0)),
			"delta": int(deltas[seat]) if seat < deltas.size() else 0,
			"score": int(view.scores[seat]) if seat < view.scores.size() else 0,
			"is_dealer": seat == int(view.get("dealer", -1)),
			"is_winner": seat == winner,
			"is_deal_in": seat == from_seat and method == "discard",
			"is_robbed": seat == from_seat and method == "rob",
		})
	var mode := "online" if not online_view.is_empty() else "single"
	var difficulty := "normal"
	var luck := "normal"
	if mode == "single":
		difficulty = str(settings.get("difficulty", "normal"))
		luck = str(settings.get("luck", "normal"))
	var now := Time.get_ticks_msec()
	var duration := maxi(0, now - stats_round_started_ms) if stats_round_started_ms > 0 else 0
	var finished := bool(view.get("table_finished", false))
	var standings: Array = []
	var rank := 0
	if finished:
		if online_view.is_empty() and game != null:
			standings = game.standings()
		else:
			standings = Array(view.get("standings", [])).duplicate(true)
		for row in standings:
			if row is Dictionary and int(row.get("seat", -1)) == 0:
				rank = int(row.get("rank", 0))
	var winner_hand: Array = []
	var winner_melds: Array = []
	var winner_flowers: Array = []
	if winner >= 0 and winner < players.size():
		winner_hand = Array(players[winner].get("hand", [])).duplicate()
		winner_melds = Array(players[winner].get("melds", [])).duplicate(true)
		winner_flowers = Array(players[winner].get("flowers", [])).duplicate()
	return {
		"table_id": stats_table_id, "round": int(view.get("round", 0)),
		"hand_id": int(view.get("hand_id", -1)),
		"mode": mode, "round_limit": int(view.get("round_limit", 0)),
		"difficulty": difficulty, "luck": luck,
		"dealer": int(view.get("dealer", -1)),
		"started_ms": stats_round_started_ms, "started_at": stats_round_started_at,
		"ended_ms": now,
		"ended_at": int(Time.get_unix_time_from_system()), "duration_ms": duration,
		"discards": int(view.get("discard_count", 0)), "tile_draws": int(view.get("draw_count", 0)),
		"remaining": int(view.get("remaining", 0)),
		"result": result.duplicate(true), "scores": view.scores.duplicate(),
		"table_finished": finished, "table_rank": rank, "standings": standings.duplicate(true),
		"redeal": str(result.get("kind", "")) == "firstCycleDraw",
		"gold": gold, "indicator": int(view.get("indicator", -1)),
		"gold_dice": Array(view.get("gold_dice", [])).duplicate(),
		"gold_index": int(view.get("gold_index", -1)),
		"dealer_rolls": view.get("dealer_rolls", {}).duplicate(true),
		"names": names, "players": players,
		"winner_hand": winner_hand, "winner_melds": winner_melds, "winner_flowers": winner_flowers,
	}


func show_dealer_roll(state: Dictionary, on_done: Callable) -> void:
	cancel_dealer_roll()
	dealer_roll_shown_round = 1
	dealer_roll_callback = on_done
	dealer_roll_state = state
	dealer_roll_online = false
	_build_dealer_roll_panel()
	_update_dealer_roll_panel()
	_schedule_dealer_roll()


func _build_dealer_roll_panel() -> void:
	board_art.set_dice(Vector2i(1, 2))
	var dialog := panel(self, Rect2(390, 470, 500, 300), Color("#233c30"), Color("#ab8852"), 16)
	dialog.z_index = 30
	dealer_roll_panel = dialog
	label(dialog, "掷骰定庄", Rect2(24, 14, 300, 36), 26, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	label(dialog, "点数最大者坐庄", Rect2(24, 48, 300, 22), 14, MUTED)
	dealer_roll_rows = []
	for seat in range(4):
		var y := 82 + seat * 34
		var name_text: String = online_roll_names[seat] if seat < online_roll_names.size() else player_name(seat)
		var name_label := label(dialog, name_text, Rect2(24, y, 140, 28), 17, INK)
		set_player_font(name_label)
		var dice_label := label(dialog, "—", Rect2(168, y, 250, 28), 17, MUTED)
		dealer_roll_rows.append({"name": name_label, "dice": dice_label})
	dealer_roll_dice_label = label(dialog, "等待掷骰", Rect2(24, 220, 452, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	dealer_roll_status = label(dialog, "", Rect2(24, 258, 320, 24), 14, MUTED)
	dealer_roll_button = button(dialog, "掷骰", Rect2(366, 254, 110, 34), _dealer_roll_press, "primary")
	dealer_roll_button.hide()
	dealer_roll_start_button = button(dialog, "开始发牌", Rect2(366, 254, 110, 34), finish_dealer_roll, "primary")
	dealer_roll_start_button.hide()


func _update_dealer_roll_panel() -> void:
	if not is_instance_valid(dealer_roll_panel) or dealer_roll_state.is_empty():
		return
	var finished: bool = dealer_roll_state.get("finished", false)
	var current := Rules.dealer_roll_current(dealer_roll_state)
	var winner := int(dealer_roll_state.get("winner", -1))
	for seat in range(4):
		var row: Dictionary = dealer_roll_rows[seat]
		var pair: Array = dealer_roll_state.dice[seat]
		var total := int(dealer_roll_state.sums[seat])
		var name_text: String = online_roll_names[seat] if seat < online_roll_names.size() else player_name(seat)
		if pair.size() == 2 and total >= 0:
			row.dice.text = "%d + %d = %d" % [int(pair[0]), int(pair[1]), total]
			row.dice.add_theme_color_override("font_color", GOLD if seat == winner else INK)
		else:
			row.dice.text = "—"
			row.dice.add_theme_color_override("font_color", MUTED)
		var active: bool = seat == current and not finished
		row.name.text = seat_wind(seat) + " · " + name_text + (" · 庄" if seat == winner else "")
		row.name.add_theme_color_override("font_color", GOLD if seat == winner or active else INK)
	if finished:
		var winner_name := ""
		if winner >= 0:
			winner_name = online_roll_names[winner] if winner < online_roll_names.size() else player_name(winner)
		dealer_roll_status.text = winner_name + " 坐庄"
		dealer_roll_button.hide()
		if dealer_roll_online:
			dealer_roll_start_button.hide()
			dealer_roll_dice_label.text = "准备发牌…"
		else:
			dealer_roll_start_button.show()
			dealer_roll_dice_label.text = "等待开始发牌"
		return
	var round_text := ""
	if int(dealer_roll_state.get("round", 1)) > 1:
		round_text = "平局重掷 · 第 %d 轮 · " % int(dealer_roll_state.round)
	var current_name: String = online_roll_names[current] if current >= 0 and current < online_roll_names.size() else player_name(current)
	dealer_roll_status.text = round_text + ("轮到你掷骰" if current == 0 else "%s 掷骰中…" % current_name)
	dealer_roll_button.visible = current == 0
	dealer_roll_button.disabled = dealer_roll_animating or (dealer_roll_online and not dealer_roll_online_ready)
	dealer_roll_start_button.hide()


func _schedule_dealer_roll() -> void:
	if dealer_roll_online or not is_instance_valid(dealer_roll_panel):
		return
	if dealer_roll_state.get("finished", false):
		dealer_roll_auto_roll = false
		_update_dealer_roll_panel()
		dealer_roll_timer.start(1.8)
		return
	var current := Rules.dealer_roll_current(dealer_roll_state)
	if current <= 0:
		dealer_roll_auto_roll = false
		dealer_roll_timer.stop()
		_update_dealer_roll_panel()
		return
	dealer_roll_auto_roll = true
	_update_dealer_roll_panel()
	dealer_roll_timer.start(0.6)


func _dealer_roll_tick() -> void:
	if not is_instance_valid(dealer_roll_panel):
		return
	if dealer_roll_state.get("finished", false):
		finish_dealer_roll()
	elif dealer_roll_auto_roll:
		_dealer_roll_press()


func _dealer_roll_press() -> void:
	if dealer_roll_state.is_empty() or dealer_roll_state.get("finished", false) or dealer_roll_animating:
		return
	if dealer_roll_online:
		if not dealer_roll_online_ready:
			return
		if is_instance_valid(dealer_roll_button):
			dealer_roll_button.disabled = true
		room.request("roll")
		return
	var current := Rules.dealer_roll_current(dealer_roll_state)
	if current != 0 and not dealer_roll_auto_roll:
		return
	Rules.dealer_roll_apply(dealer_roll_state, dealer_roll_rng)
	dealer_roll_auto_roll = false
	var pair: Array = dealer_roll_state.dice[current]
	var total := int(dealer_roll_state.sums[current])
	_animate_roll_dice(pair, total, func():
		_update_dealer_roll_panel()
		_schedule_dealer_roll())


func _animate_roll_dice(pair: Array, total: int, on_done: Callable) -> void:
	dealer_roll_animating = true
	if is_instance_valid(dealer_roll_button):
		dealer_roll_button.disabled = true
	dealer_roll_dice_label.text = "骰子翻滚中…"
	var faces := Vector2i(int(pair[0]), int(pair[1]))
	board_art.animate_dice(faces, func():
		dealer_roll_animating = false
		dealer_roll_dice_label.text = "%d + %d = %d" % [faces.x, faces.y, total]
		if on_done.is_valid():
			on_done.call()
		if dealer_roll_online and room.state.get("phase", "") == "playing":
			room_state_changed())


func _dealer_roll_apply_now() -> void:
	if dealer_roll_state.is_empty() or dealer_roll_state.get("finished", false):
		return
	Rules.dealer_roll_apply(dealer_roll_state, dealer_roll_rng)
	_update_dealer_roll_panel()


func show_online_dealer_roll(snapshot: Dictionary) -> void:
	var viewer := int(snapshot.get("my_seat", 0))
	var roll: Dictionary = OnlineTableView.rotate_roll(snapshot.get("roll", {}), viewer)
	var seats: Array = OnlineTableView.rotate_seats(snapshot.get("seats", []), viewer)
	var names: Array = seats.map(func(entry): return String(entry.get("name", "")))
	var last_rolled := OnlineTableView.local_seat(int(snapshot.get("last_rolled_seat", -1)), viewer)
	if not (is_instance_valid(dealer_roll_panel) and dealer_roll_online):
		cancel_dealer_roll()
		online_roll_names = names
		dealer_roll_online = true
		dealer_roll_online_ready = bool(snapshot.get("roll_ready", true))
		dealer_roll_state = roll
		_build_dealer_roll_panel()
		if last_rolled >= 0 and roll.dice[last_rolled].size() == 2:
			var pair: Array = roll.dice[last_rolled]
			board_art.set_dice(Vector2i(int(pair[0]), int(pair[1])))
			dealer_roll_dice_label.text = "%d + %d = %d" % [int(pair[0]), int(pair[1]), int(roll.sums[last_rolled])]
		_update_dealer_roll_panel()
		return
	online_roll_names = names
	dealer_roll_online_ready = bool(snapshot.get("roll_ready", true))
	var previous: Dictionary = dealer_roll_state
	dealer_roll_state = roll
	var advanced: bool = previous.round != roll.round or previous.index != roll.index or previous.finished != roll.finished
	if advanced and last_rolled >= 0 and roll.dice[last_rolled].size() == 2:
		var pair: Array = roll.dice[last_rolled]
		var total := int(roll.sums[last_rolled])
		_animate_roll_dice(pair, total, func(): _update_dealer_roll_panel())
	elif not dealer_roll_animating:
		_update_dealer_roll_panel()


func close_online_dealer_roll() -> void:
	if dealer_roll_online:
		cancel_dealer_roll()


func cancel_dealer_roll() -> void:
	if dealer_roll_animating and is_instance_valid(board_art):
		board_art.cancel_dice_roll()
	if is_instance_valid(dealer_roll_panel):
		dealer_roll_panel.queue_free()
	dealer_roll_panel = null
	dealer_roll_rows = []
	dealer_roll_status = null
	dealer_roll_button = null
	dealer_roll_start_button = null
	dealer_roll_dice_label = null
	dealer_roll_state = {}
	dealer_roll_callback = Callable()
	dealer_roll_online = false
	dealer_roll_online_ready = false
	dealer_roll_animating = false
	dealer_roll_auto_roll = false
	online_roll_names = []
	if is_instance_valid(dealer_roll_timer):
		dealer_roll_timer.stop()


func finish_dealer_roll() -> void:
	if not is_instance_valid(dealer_roll_panel):
		return
	if not dealer_roll_state.get("finished", false):
		while not dealer_roll_state.get("finished", false):
			Rules.dealer_roll_apply(dealer_roll_state, dealer_roll_rng)
	var callback := dealer_roll_callback
	cancel_dealer_roll()
	if callback.is_valid():
		callback.call()


func start_intro() -> void:
	var view := board_view()
	if view.is_empty():
		return
	reset_hand_presentation(view)
	if board_art.dice == Vector2i.ZERO:
		board_art.set_dice(Vector2i(1, 2))
	intro = OpeningIntro.new()
	intro.start(int(view.get("dealer", 0)))
	intro_timer.stop()
	intro_timer.start(_intro_delay(intro.stage))
	refresh()


func _intro_delay(stage: String) -> float:
	match stage:
		"deal":
			return 0.35
		"dealer_extra":
			return 0.35
		"gold":
			return 0.55
		"flowers":
			return 0.6
	return 0.0


func advance_intro() -> void:
	if not intro_active():
		return
	intro.advance()
	if not intro.is_active():
		finish_intro()
		return
	if intro.stage == "flowers":
		var view := board_view()
		var sequence := _opening_flower_steps(view)
		if sequence.is_empty():
			intro.advance()
			finish_intro()
		else:
			start_flower_sequence(sequence, "opening", view.get("deal_initial_hand", []), func():
				if is_instance_valid(intro):
					intro.advance()
				finish_intro())
		return
	refresh()
	if intro.stage == "dice":
		_animate_gold_dice()
	else:
		intro_timer.start(_intro_delay(intro.stage))


func _opening_flower_steps(view: Dictionary) -> Array:
	var sequence: Array = []
	for event in view.get("deal_flowers", []):
		if int(event.round) == 0:
			sequence.append({"kind": "initial", "seat": event.seat, "tile": event.tile, "round": 0})
	var draws: Array = view.get("deal_draws", [])
	if draws.any(func(event): return not event.has("slot")):
		for event in draws:
			sequence.append({"kind": "draw", "seat": event.seat, "tile": event.tile,
				"flower": event.flower, "round": event.round})
		return sequence
	var faces_by_slot := {}
	for event in draws:
		faces_by_slot[event.slot] = event.tile
	for event in view.get("wall", {}).get("opening", []):
		if event.end == "tail":
			sequence.append({"kind": "draw", "seat": event.seat, "tile": faces_by_slot.get(event.slot, -1),
				"flower": event.kind == "flower", "round": event.round, "slot": event.slot})
	return sequence


func _draw_flower_steps(view: Dictionary, flowers: Array) -> Array:
	var sequence: Array = []
	var takes: Array = view.get("wall", {}).get("takes", [])
	var replacement: Dictionary = takes.back() if not takes.is_empty() and takes.back().kind == "draw" else {}
	var first := takes.size() - flowers.size() - int(not replacement.is_empty())
	for index in range(flowers.size()):
		var event: Dictionary = flowers[index]
		var slot: int = takes[first + index].slot if first >= 0 else -1
		sequence.append({"kind": "draw_flower", "seat": event.seat, "tile": event.tile,
			"round": event.round, "slot": slot})
	if int(view.drawn) >= 0 or not replacement.is_empty():
		sequence.append({"kind": "replacement", "seat": replacement.get("seat", 0),
			"tile": view.drawn, "slot": replacement.get("slot", -1)})
	return sequence


func _clear_wall_flights() -> void:
	for child in wall_flights.get_children():
		wall_flights.remove_child(child)
		child.queue_free()


func _reset_wall() -> void:
	_clear_wall_flights()
	wall_art.set_slots([], 0)
	wall_hand = -1


func _wall_source(slot: int) -> Vector2:
	if slot < 0:
		return Vector2.INF
	return TableWall.slot_rect(slot, wall_art.dealer).get_center()


func _fly_wall_back(source: Vector2, seat: int, offset := Vector2.ZERO) -> void:
	var destination: Vector2 = SEAT_POSITIONS[seat] + Vector2(27, 20) + offset
	var card := tile(wall_flights, -1, Rect2(source - Vector2(6, 8), Vector2(12, 16)), -1)
	var flight := card.create_tween()
	flight.tween_property(card, "position", destination, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(card, "modulate:a", 0.0, 0.06)
	flight.tween_callback(card.queue_free)


func _refresh_wall(view: Dictionary, animate: bool) -> void:
	wall_draw_from = Vector2.INF
	wall_gold_from = Vector2.INF
	var wall: Dictionary = view.get("wall", {})
	if wall.is_empty():
		wall_art.set_slots([], 0)
		return
	var values: Array = wall.slots.duplicate()
	var events: Array = wall.takes
	if intro_active():
		var replacements := 0
		for index in range(flower_index + 1 if flower_active else 0):
			if flower_sequence[index].kind == "draw":
				replacements += 1
		if not wall.opening.is_empty():
			var dealt := mini(intro.deal_round * 16, 64) + int(intro.stage in ["dice", "gold", "flowers"])
			values = TableWall.opening_slots(wall, dealt, intro_gold, replacements)
		events = wall.opening
	elif flower_active:
		for index in range(flower_index + 1, flower_sequence.size()):
			var slot := int(flower_sequence[index].get("slot", -1))
			if slot >= 0:
				values.append(slot)
		values.sort()
	var previous := wall_art.slots
	wall_art.set_slots(values, int(view.dealer))
	var same_hand := wall_hand == hand_key(view)
	wall_hand = hand_key(view)
	if not same_hand or not (animate or intro_active() or flower_active):
		return
	var flights := [0, 0, 0, 0]
	for event in events:
		if event.slot not in previous or event.slot in values:
			continue
		var source := TableWall.slot_rect(event.slot, int(view.dealer)).get_center()
		match event.kind:
			"gold":
				wall_gold_from = source
			"deal":
				var seat: int = event.seat
				_fly_wall_back(source, seat, Vector2(4 * flights[seat], 0))
				flights[seat] += 1
			"draw", "replacement":
				if event.seat == 0 and (int(view.drawn) >= 0 or flower_preview):
					wall_draw_from = source
				else:
					_fly_wall_back(source, event.seat)


func _animate_gold_dice() -> void:
	board_art.animate_dice(_gold_dice(board_view()), func():
		if intro_active() and intro.stage == "dice":
			intro_timer.start(0.10))


func _gold_dice(view: Dictionary) -> Vector2i:
	var pair: Array = view.get("gold_dice", [])
	return Vector2i(int(pair[0]), int(pair[1])) if pair.size() == 2 else Vector2i(1, 1)


func start_flower_sequence(sequence: Array, mode: String, preview_hand: Array, on_done: Callable, hold_drawn := false) -> void:
	cancel_flower_sequence()
	flower_sequence = sequence.duplicate(true)
	flower_index = 0
	flower_preview = mode == "opening"
	flower_preview_hand = preview_hand.duplicate()
	flower_done = on_done
	flower_active = true
	flower_hold_drawn = hold_drawn
	flower_status_text = "摸到花"
	if flower_sequence.is_empty():
		_finish_flower_sequence()
		return
	flower_index = -1
	refresh()
	flower_timer.start(OpeningIntro.FLOWER_HOLD)


func _show_flower_step() -> void:
	if not flower_active or flower_index < 0 or flower_index >= flower_sequence.size():
		return
	flower_slide_index = -1
	var event: Dictionary = flower_sequence[flower_index]
	var seat := int(event.get("seat", 0))
	var tile_number := int(event.get("tile", -1))
	var round_number := int(event.get("round", 0))
	var kind: String = String(event.get("kind", "draw_flower"))
	flower_slide_from = _wall_source(int(event.get("slot", -1)))
	if kind == "initial":
		flower_status_text = "摸到花"
		if seat == 0 and flower_preview:
			flower_preview_hand.erase(tile_number)
		pop_flower(seat, tile_number)
	elif kind == "draw" and not bool(event.get("flower", false)):
		flower_status_text = "第 %d 轮补花" % round_number
		if seat == 0 and flower_preview and tile_number >= 0:
			flower_preview_hand.append(tile_number)
			flower_slide_index = flower_preview_hand.filter(func(number): return number <= tile_number).size() - 1
	elif kind == "replacement":
		if seat == 0 and tile_number >= 0:
			flower_hold_drawn = false
			flower_slide_index = board_view().players[0].hand.size() - 1
	else:
		flower_status_text = ("第 %d 轮补花" % round_number) if flower_preview else ("第 %d 次补花" % round_number)
		pop_flower(seat, tile_number, flower_slide_from)
	if flower_slide_index >= 0:
		flower_slide_started = Time.get_ticks_msec()
	refresh()


func advance_flower() -> void:
	if not flower_active:
		return
	flower_index += 1
	if flower_index >= flower_sequence.size():
		_finish_flower_sequence()
	else:
		_show_flower_step()
		flower_timer.start(OpeningIntro.REPLACEMENT_STEP if flower_slide_index >= 0 else OpeningIntro.FLOWER_STEP)


func _finish_flower_sequence() -> void:
	if not flower_active:
		return
	flower_active = false
	flower_timer.stop()
	flower_preview = false
	flower_preview_hand = []
	flower_hold_drawn = false
	flower_slide_index = -1
	flower_sequence = []
	var callback := flower_done
	flower_done = Callable()
	if callback.is_valid():
		callback.call()


func cancel_flower_sequence() -> void:
	flower_active = false
	flower_timer.stop()
	flower_sequence = []
	flower_preview = false
	flower_preview_hand = []
	flower_hold_drawn = false
	flower_slide_index = -1
	flower_status_text = ""
	flower_done = Callable()
	if is_instance_valid(flower_fx):
		for child in flower_fx.get_children():
			flower_fx.remove_child(child)
			child.queue_free()


func pop_flower(seat: int, tile_number: int, source := Vector2.INF) -> void:
	if tile_number < 0 or not is_instance_valid(flower_fx):
		return
	var positions := [Vector2(990, 700), Vector2(930, 355), Vector2(760, 80), Vector2(120, 355)]
	var pos: Vector2 = positions[clampi(seat, 0, 3)]
	var node := tile(flower_fx, tile_number, Rect2(pos, Vector2(52, 69)), int(board_view().get("gold", -1)))
	node.z_index = 16
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.6, 0.6)
	var animation := node.create_tween()
	if source.is_finite():
		node.position = source - node.size * 0.5
		animation.tween_property(node, "position", pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animation.parallel().tween_property(node, "scale", Vector2.ONE, 0.2)
		animation.tween_property(node, "modulate:a", 0.0, 0.13)
		animation.tween_callback(node.queue_free)
		return
	animation.tween_property(node, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)
	animation.tween_interval(0.12)
	animation.tween_property(node, "modulate:a", 0.0, 0.12)
	animation.tween_callback(node.queue_free)


func finish_intro() -> void:
	intro = null
	intro_timer.stop()
	refresh(true)


func skip_intro() -> void:
	_clear_wall_flights()
	if flower_active:
		_finish_flower_sequence()
		return
	if not is_instance_valid(intro):
		return
	intro = null
	intro_timer.stop()
	refresh(true)


func intro_active() -> bool:
	return is_instance_valid(intro) and intro.is_active()


func clear_selection() -> void:
	selected_index = -1
	selected_tile = -1


func choose_tile(index: int, tile: int) -> void:
	if is_instance_valid(modal):
		return
	if selected_index == index:
		confirm_discard()
		return
	selected_index = index
	selected_tile = tile
	play_sound("pick")
	refresh()
	if index < human_buttons.size():
		human_buttons[index].grab_focus()


func cancel_selection() -> void:
	clear_selection()
	refresh()


func confirm_discard() -> void:
	if selected_tile < 0 or is_instance_valid(modal):
		return
	for move in local_moves():
		if (move.type == "discard" or is_swap(move)) and move.tile == selected_tile:
			perform(0, move)
			return


func is_swap(move: Dictionary) -> bool:
	return move.type == "win" and move.kind == "grab" and move.has("tile")


func perform(seat: int, move: Dictionary) -> void:
	if is_instance_valid(modal) and (seat == 0 or not is_instance_valid(settings_panel)):
		return
	var discards_tile: bool = move.type in ["discard", "declareGoldGap"]
	if not online_view.is_empty():
		if seat != 0 or not local_moves().any(func(choice): return choice.id == move.id):
			return
		var stage := online_stage
		pending_stage = stage
		clear_selection()
		play_sound("discard" if discards_tile else "claim")
		refresh()
		room.request("play", {"id": move.id, "stage": stage})
		return
	var revision: int = game.revision
	if not game.act(seat, move.id):
		return
	if seat == 0:
		clear_selection()
	if discards_tile:
		play_sound("discard")
	elif game.revision != revision or game.phase == "result":
		play_sound("claim")
	refresh(true)


func run_ai() -> void:
	if is_instance_valid(modal) and not is_instance_valid(settings_panel):
		return
	for seat in range(1, 4):
		var moves: Array = game.actions(seat)
		if not moves.is_empty():
			perform(seat, Opponent.choose(game.view(seat), moves, settings.difficulty))
			return


func next_round() -> void:
	if not online_view.is_empty():
		room.request("next", {"stage": online_stage})
		return
	if not game.next_round():
		return
	start_intro()


func cancel_hand_animations(view: Dictionary) -> void:
	intro = null
	intro_timer.stop()
	board_art.cancel_dice_roll()
	cancel_flower_sequence()
	draw_flower_active = false
	last_flower_revision = int(view.get("flower_revision", 0))
	_clear_wall_flights()


func reset_hand_presentation(view: Dictionary) -> void:
	clear_hand_activity(view)
	_reset_wall()
	pending_stage = -1
	shown_round = -1
	last_revision = -1
	log_lines.clear()


func clear_hand_activity(view: Dictionary) -> void:
	cancel_hand_animations(view)
	close_menu()
	close_modal(false)
	clear_selection()
	clear_action_banner()
	interactions.reset()


func restart_after_draw() -> void:
	if game != null and game.restart_after_draw():
		start_intro()


func refresh(animate := false) -> void:
	ai_timer.stop()
	var view := board_view()
	if view.is_empty():
		return
	_track_stats(view)
	var redealing: bool = view.phase == "redeal"
	if redealing and not is_instance_valid(redeal_notice):
		clear_hand_activity(view)
		if online_view.is_empty():
			redeal_timer.start(Game.REDEAL_DELAY_MS / 1000.0)
	var intro_running := intro_active()
	if not intro_running:
		board_art.set_dice(Vector2i.ZERO if redealing else _gold_dice(view))
	intro_visible_hand = -1
	intro_flowers = not intro_running or intro.stage in ["flowers", "done"]
	intro_gold = not intro_running or intro.stage in ["gold", "flowers", "done"]
	if intro_running and view.players.size() > 0 and view.players[0].has("hand"):
		intro_visible_hand = intro.visible_count(0, view.players[0].hand.size())
	var render_view := view
	if intro_running and not intro_gold:
		render_view = view.duplicate(true)
		render_view.gold = -1
	if not intro_running and not flower_active and int(view.get("flower_revision", 0)) != last_flower_revision:
		last_flower_revision = int(view.get("flower_revision", 0))
		var events: Array = view.get("last_flowers", [])
		if not events.is_empty():
			draw_flower_active = true
			var sequence := _draw_flower_steps(view, events)
			var local_replacement := int(view.get("drawn", -1)) >= 0
			start_flower_sequence(sequence, "draw", [], func():
				draw_flower_active = false
				refresh(), local_replacement)
			return
	_refresh_wall(view, animate)
	clear_board()
	dynamic = Control.new()
	dynamic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dynamic)
	if is_instance_valid(modal):
		move_child(dynamic, modal.get_index())
	var moves := local_moves()
	var fresh: bool = last_revision != view.latest.revision
	var deal: bool = animate and fresh and view.latest.type == "start"
	if fresh:
		record(view)
	render_board(render_view, moves, deal, animate and fresh)
	render_sidebar(view)
	render_controls(view, moves)
	if is_instance_valid(modal):
		suspend_focus(dynamic)
	if redealing:
		return
	if view.phase == "result":
		if shown_round != view.round and not is_instance_valid(modal) and not flower_active and not intro_running:
			if not _begin_result_hold(view):
				show_result()
	elif online_view.is_empty() and (not is_instance_valid(modal) or is_instance_valid(settings_panel)) and not intro_running and not draw_flower_active and not flower_active:
		for seat in range(1, 4):
			if not game.actions(seat).is_empty():
				ai_timer.start(0.54 if view.phase == "turn" else 0.25)
				break


func record(view: Dictionary) -> void:
	var event: Dictionary = view.latest
	var previous: Dictionary = event.get("previous", {})
	if not previous.is_empty() and previous.revision != last_revision:
		record_event(view, previous, false)
	last_revision = event.revision
	record_event(view, event)


func record_event(view: Dictionary, event: Dictionary, announce := true) -> void:
	var actor := player_name(event.seat)
	var copy := actor
	if event.type == "start":
		clear_action_banner()
		copy = "第 %02d 局   %s坐庄" % [view.round, copy]
	elif event.type == "discard":
		copy += " 打出 " + Rules.tile_name(event.tile)
		if event.get("gold_gap", false):
			copy += " · 报听金坎"
			if announce:
				queue_action_banner(actor, "报听金坎")
	elif event.type == "win":
		var caption := result_caption(view.result)
		copy += " " + caption
		clear_action_banner()
		queue_action_banner(actor, caption, true)
	elif Rules.MELD_NAMES.has(event.type):
		var caption: String = Rules.MELD_NAMES[event.type]
		copy += " " + caption
		if event.tile >= 0:
			copy += " " + Rules.tile_name(event.tile)
		if announce:
			queue_action_banner(actor, caption)
	log_lines.push_front(copy)
	if log_lines.size() > 4:
		log_lines.pop_back()


func queue_action_banner(actor: String, caption: String, win := false) -> void:
	action_messages.append({"actor": actor, "caption": caption, "win": win})
	if not is_instance_valid(action_banner):
		show_action_banner()


func show_action_banner() -> void:
	if action_messages.is_empty():
		return
	var message: Dictionary = action_messages.pop_front()
	var accent := Color("#ffe298") if message.win else Color("#cff7b9")
	var fill := Color("#633023") if message.win else Color("#184734")
	var banner := panel(self, Rect2(65, 103, 188, 54), fill, accent, 10)
	var style := banner.get_theme_stylebox("panel") as StyleBoxFlat
	style.shadow_color = Color(0.02, 0.10, 0.07, 0.55)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	banner.name = "ActionBanner"
	banner.z_index = 11
	action_banner = banner
	var actor_label := label(banner, message.actor, Rect2(8, 1, 172, 19), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
	actor_label.name = "Actor"
	set_player_font(actor_label)
	var badge := Rect2(6, 23, 176, 26)
	panel(banner, badge, accent, accent, 7)
	var caption_size := clampi(floori(160.0 / maxi(1, message.caption.length())), 12, 22)
	var caption_label := label(banner, message.caption, badge, caption_size, fill,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	caption_label.name = "Caption"
	caption_label.add_theme_font_override("font", action_font)
	var animation := banner.create_tween()
	animation.tween_interval(1.6 if message.win else 1.05)
	animation.tween_property(banner, "modulate:a", 0.0, 0.22)
	animation.tween_callback(func():
		banner.queue_free()
		action_banner = null
		show_action_banner())


func clear_action_banner() -> void:
	action_messages.clear()
	if is_instance_valid(action_banner):
		remove_child(action_banner)
		action_banner.queue_free()
		action_banner = null


func tile(parent: Node, number: int, rect: Rect2, gold: int, on_press := Callable(),
		chosen := false, highlighted := false) -> Button:
	var node := Tile.new()
	node.position = rect.position
	var face: Texture2D = faces[number] if number >= 0 and number < faces.size() else null
	node.setup(number, rect.size, face, session_font, Rules.is_gold(number, gold),
		on_press.is_valid(), chosen, highlighted, applied_skin == "guobiao")
	if on_press.is_valid():
		node.pressed.connect(on_press)
	parent.add_child(node)
	if number >= Rules.NUMBERED and face == null:
		var face_rect := Rect2(Vector2.ZERO, rect.size * Vector2(1.0, 0.90))
		label(node, Rules.tile_name(number), face_rect, maxi(9, int(rect.size.x * 0.64)),
			Color("#954132"), HORIZONTAL_ALIGNMENT_CENTER, true)
	return node


func slide(node: Control, offset: Vector2, delay := 0.0) -> void:
	var destination := node.position
	node.position += offset
	node.modulate.a = 0.0
	var motion := node.create_tween().set_parallel()
	motion.tween_property(node, "position", destination, SLIDE_DURATION).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(node, "modulate:a", 1.0, SLIDE_FADE).set_delay(delay)


func slide_flower_replacement(node: Control) -> void:
	# Board redraws can happen during the animation, for example on a room update.
	var elapsed := float(Time.get_ticks_msec() - flower_slide_started) / 1000.0
	var time_left := SLIDE_DURATION - elapsed
	if time_left <= 0.0:
		return
	var destination := node.position
	var source := flower_slide_from - node.size * 0.5 if flower_slide_from.is_finite() else destination + Vector2(70, 0)
	node.position = destination.lerp(source, pow(time_left / SLIDE_DURATION, 3))
	node.modulate.a = minf(1.0, elapsed / SLIDE_FADE)
	var motion := node.create_tween().set_parallel()
	motion.tween_property(node, "position", destination, time_left).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(node, "modulate:a", 1.0, maxf(0.0, SLIDE_FADE - elapsed))


func _flip_wall_gold(card: Control, gold_display: Control) -> void:
	var destination := card.position
	var source := wall_gold_from - gold_display.position - card.size * 0.5
	var flip_point := source.lerp(destination, 0.2)
	var back := tile(gold_display, -1, Rect2(source, card.size), -1)
	back.pivot_offset = back.size * 0.5
	back.scale = Vector2(0.44, 0.44)
	var turn := back.create_tween()
	turn.tween_property(back, "position", flip_point, 0.085)
	turn.parallel().tween_property(back, "scale:x", 0.02, 0.085)
	turn.tween_callback(back.queue_free)
	card.pivot_offset = card.size * 0.5
	card.position = flip_point
	card.scale = Vector2(0.02, 0.44)
	card.modulate.a = 0.0
	var reveal := card.create_tween()
	reveal.tween_interval(0.085)
	reveal.tween_property(card, "modulate:a", 1.0, 0.035)
	reveal.parallel().tween_property(card, "scale", Vector2.ONE, 0.18)
	reveal.parallel().tween_property(card, "position", destination, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func render_board(view: Dictionary, moves: Array, deal: bool, animate_discard: bool) -> void:
	winning_tile_rect = Rect2()
	label(dynamic, "第 %02d / %02d 局" % [view.round, view.round_limit], Rect2(71, 40, 170, 27), 17, GOLD)
	var playable: int = view.remaining
	if intro_active() or flower_active:
		playable = maxi(0, wall_art.slots.size() - Rules.RESERVE)
	label(dynamic, "可摸 %d 张" % playable, Rect2(71, 67, 135, 25), 14, MUTED)
	center_dial.visible = not intro_active() and view.phase != "redeal"
	var public_turn: bool = view.phase == "turn" and not online_reconnecting
	center_dial.set_seats(view.get("winds", WINDS), int(view.current) if public_turn else -1)
	if is_instance_valid(fx):
		fx.set_active(int(view.current) if public_turn else -1)
	if not online_view.is_empty():
		room_notice_label = label(dynamic, "", Rect2(216, 30, 230, 30), 13, GOLD)
		room_notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		update_online_clock()
	else:
		countdown_label.text = ""
	if intro_gold:
		var gold_display := panel(dynamic, GOLD_AREA, Color("#1d4938"), Color("#668064"), 9)
		gold_display.name = "GoldDisplay"
		label(gold_display, "本局金牌", Rect2(0, 4, 194, 22), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		var golds: Array = Rules.gold_tiles(view.gold)
		var gold_width := 44 if golds.size() == 1 else 35
		var gold_step := gold_width + 5
		var gold_left := (194.0 - (golds.size() * gold_step - 5)) * 0.5
		for index in range(golds.size()):
			var card := tile(gold_display, golds[index], Rect2(gold_left + index * gold_step, 27, gold_width, 59),
				view.gold, Callable(), false, golds.size() > 1 and golds[index] == view.gold)
			if golds[index] == view.indicator and wall_gold_from.is_finite():
				_flip_wall_gold(card, gold_display)
		var gold_name := Rules.tile_name(view.gold)
		if golds.size() > 1:
			gold_name = "花金 · 翻 " + gold_name
		elif view.gold >= Rules.NUMBERED:
			gold_name += " · 花金"
		label(gold_display, gold_name + (" · 已抢" if view.indicator < 0 else ""),
			Rect2(0, 87, 194, 22), 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var rob_tile: int = view.get("rob_tile", -1)
	if view.phase == "robKong" and rob_tile >= 0 and moves.any(func(move): return move.type == "win"):
		var offer := panel(dynamic, Rect2(604, 623, 130, 55), Color("#1a3d31"), GOLD, 10)
		offer.name = "RobKongOffer"
		label(offer, "可抢的补杠牌", Rect2(45, 0, 80, 55), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		tile(offer, rob_tile, Rect2(8, 5, 32, 44), view.gold, Callable(), false, true)

	for seat in range(4):
		draw_seat(view, seat, SEAT_POSITIONS[seat])
		draw_river(view, seat, animate_discard)
	draw_hand(view, moves, deal)
	if view.phase == "redeal":
		var bounds := Rect2(Art.CENTER - Vector2(90, 23), Vector2(180, 46))
		redeal_notice = panel(dynamic, bounds, Color("#21392e"), GOLD, 12)
		redeal_notice.name = "RedealNotice"
		label(redeal_notice, REDEAL_NOTICE, Rect2(Vector2.ZERO, bounds.size), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


func draw_seat(view: Dictionary, seat: int, origin: Vector2) -> void:
	var player: Dictionary = view.players[seat]
	var wide := seat in [0, 2]
	var width := 154 if wide else 126
	var active: bool = view.phase == "turn" and view.current == seat
	panel(dynamic, Rect2(origin, Vector2(width, 39)), Color("#173b2e"),
		Color("#d7b46a") if active else Color("#678367"))
	var portrait := Rect2(origin + Vector2(5, 5), Vector2(29, 29))
	interactions.portrait_rects[seat] = portrait
	panel(dynamic, portrait, PORTRAITS[seat], PORTRAITS[seat])
	if seat != 0 and view.phase not in ["result", "redeal"]:
		var hitbox := Button.new()
		hitbox.name = "InteractionSeat%d" % seat
		hitbox.position = portrait.position
		hitbox.size = portrait.size
		hitbox.flat = true
		hitbox.focus_mode = Control.FOCUS_NONE
		hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hitbox.tooltip_text = "互动 · " + player_name(seat)
		hitbox.pressed.connect(interactions.open.bind(seat))
		dynamic.add_child(hitbox)
	set_player_font(label(dynamic, player_mark(seat), Rect2(origin + Vector2(5, 5), Vector2(29, 29)),
		17, FONT_DARK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var wind := seat_wind(seat) + (" · 庄" if seat == view.dealer else "")
	set_player_font(label(dynamic, player_name(seat),
		Rect2(origin + Vector2(41, 2), Vector2(width - 42, 18)), 14, GOLD if active else INK))
	var flower_count: int = player.flowers.size() if intro_flowers else 0
	var seat_caption := label(dynamic, "%s · %d 花" % [wind, flower_count],
		Rect2(origin + Vector2(41, 20), Vector2(width - 42, 16)), 12, GOLD if seat == view.dealer else MUTED)
	seat_caption.name = "SeatWind%d" % seat
	var gold_gap: Array = player.get("gold_gap", [])
	if seat != 0 and player.has("hand"):
		var values: Array = player.hand.duplicate()
		var winning := winning_tile_for(view, seat, values)
		if winning >= 0:
			values.erase(winning)
		values.sort()
		if winning >= 0:
			values.append(winning)
		var columns := 17 if wide else 8
		for index in range(values.size()):
			var items_in_row := mini(columns, values.size() - (index - index % columns))
			var row: int = floori(float(index) / columns)
			var left := origin.x + (width - items_in_row * 14) * 0.5
			var bounds := Rect2(left + (index % columns) * 14, origin.y + 43 + row * 21, 12, 18)
			tile(dynamic, values[index], bounds, view.gold)
			if winning >= 0 and index == values.size() - 1:
				winning_tile_rect = bounds
	if not player.melds.is_empty():
		var anchor := origin + Vector2(width * 0.5, 61 if wide else 112)
		if seat == 0:
			anchor = Vector2(228, 615 if player.melds.size() > 3 else 648)
		elif not wide and gold_gap.size() == 2 and player.has("hand"):
			anchor.y += 17
		draw_melds(player.melds, view.gold, anchor, seat)
	if gold_gap.size() == 2:
		var gap_origins := [Vector2(66, 594), Vector2(916, 359), Vector2(644, 40), Vector2(59, 359)]
		var gap_origin: Vector2 = gap_origins[seat]
		if not wide and player.has("hand"):
			gap_origin.y += 14
		var gap := panel(dynamic, Rect2(gap_origin, Vector2(110, 39)), Color("#244435"), GOLD)
		gap.name = "GoldGap%d" % seat
		label(gap, "金坎", Rect2(5, 0, 38, 39), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		for index in range(gold_gap.size()):
			tile(gap, gold_gap[index], Rect2(47 + index * 28, 4, 23, 31), view.gold)


func meld_width(meld: Dictionary) -> float:
	var count: int = 3 if meld.type == "addedKong" else meld.tiles.size()
	return count * 25.0 + (0.0 if meld.type == "concealedKong" else 8.0)


func draw_melds(melds: Array, gold: int, origin: Vector2, seat: int) -> void:
	var columns := 3 if seat == 0 else (melds.size() if seat == 2 else 1)
	for first in range(0, melds.size(), columns):
		var row := floori(float(first) / columns)
		var groups := melds.slice(first, first + columns)
		var span := -8.0
		for meld in groups:
			span += meld_width(meld) + 8.0
		var x := origin.x if seat == 0 else origin.x - span * 0.5
		var y := origin.y + row * 34
		for meld in groups:
			draw_meld(meld, gold, Vector2(x, y), seat)
			x += meld_width(meld) + 8.0


func draw_meld(meld: Dictionary, gold: int, origin: Vector2, seat: int) -> void:
	var numbers: Array = meld.tiles.slice(0, 3) if meld.type == "addedKong" else meld.tiles
	var sideways := -1
	if meld.type == "chow":
		sideways = numbers.find(meld.get("claimed", numbers[0]))
	elif meld.type != "concealedKong":
		var relative: int = posmod(meld.from - seat, 4)
		sideways = 0 if relative == 3 else (1 if relative == 2 else numbers.size() - 1)
	var x := origin.x
	for index in range(numbers.size()):
		var y := origin.y
		if index == sideways:
			if meld.type == "addedKong":
				var added := tile(dynamic, meld.tiles[3], Rect2(x + 32, y + 1, 24, 32), gold)
				added.rotation_degrees = 90
				y += 7
			var node := tile(dynamic, numbers[index], Rect2(x + 32, y + 8, 24, 32), gold)
			node.rotation_degrees = 90
			x += 33
		else:
			tile(dynamic, numbers[index], Rect2(x, y, 24, 32), gold)
			x += 25


func river_slots(seat: int, count: int) -> Array[Rect2]:
	var region: Rect2 = Art.RIVERS[seat].grow(-6)
	var side := seat in [1, 3]
	var columns := 5 if side else 14
	var rows := 3 if side else 2
	var spacing := Vector2(29, 38)
	if count > columns * rows:
		var best_scale := 0.0
		for candidate_columns in range(1, count + 1):
			var candidate_rows := ceili(float(count) / candidate_columns)
			var fit := minf(region.size.x / (candidate_columns * spacing.x), region.size.y / (candidate_rows * spacing.y))
			if fit > best_scale:
				best_scale = fit
				columns = candidate_columns
				rows = candidate_rows
	var grid_size := Vector2(columns, rows) * spacing
	var scale := minf(1.0, minf(region.size.x / grid_size.x, region.size.y / grid_size.y))
	var step := spacing * scale
	var dimensions := Vector2(25, 34) * scale
	var grid_origin := region.get_center() - (grid_size * scale - step + dimensions) * 0.5
	var slots: Array[Rect2] = []
	for index in range(count):
		var column := floori(float(index) / rows) if side else index % columns
		var row := index % rows if side else floori(float(index) / columns)
		if seat == 1:
			column = columns - 1 - column
		var pos := grid_origin + Vector2(column, row) * step
		slots.append(Rect2(pos, dimensions))
	return slots


func draw_river(view: Dictionary, seat: int, animate: bool) -> void:
	var entry := [Vector2(0, 68), Vector2(88, 0), Vector2(0, -65), Vector2(-88, 0)]
	var river: Array = view.players[seat].river
	if river.is_empty():
		return
	var slots := river_slots(seat, river.size())
	for index in range(river.size()):
		var last: bool = view.last_discard.get("seat", -1) == seat and index == river.size() - 1
		var bounds := slots[index]
		var node := tile(dynamic, river[index], bounds, view.gold, Callable(), false, last)
		if last:
			var arrow := Polygon2D.new()
			arrow.polygon = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(0, 4)])
			arrow.color = GOLD
			arrow.position = Vector2(bounds.size.x * 0.5, -2)
			node.add_child(arrow)
			if animate and view.latest.type == "discard":
				slide(node, entry[seat])
				if is_instance_valid(fx):
					fx.discard_landing(seat, bounds.get_center())


func draw_hand(view: Dictionary, moves: Array, deal: bool) -> void:
	var playable := moves.filter(func(move): return move.type == "discard" or is_swap(move)).map(
		func(move): return move.tile)
	var hand: Array
	if flower_preview:
		hand = flower_preview_hand.duplicate()
	else:
		hand = view.players[0].hand.duplicate()
		if intro_visible_hand >= 0:
			var initial: Array = view.get("deal_initial_hand", [])
			if not initial.is_empty():
				hand = initial.duplicate()
			hand = hand.slice(0, mini(intro_visible_hand, hand.size()))
		if flower_hold_drawn and view.drawn >= 0:
			hand.pop_back()
	var winning := winning_tile_for(view, 0, hand)
	var separate := int(view.drawn) if not flower_hold_drawn and not flower_preview else -1
	if winning >= 0:
		separate = winning
	if separate >= 0:
		hand.erase(separate)
	hand.sort()
	if separate >= 0:
		hand.append(separate)
	var has_draw := separate >= 0
	var reserve_draw_slot: bool = flower_hold_drawn and view.drawn >= 0
	var slot_count := hand.size() + int(reserve_draw_slot)
	var cursor := 549.0 - (slot_count * 59 - 3 + (10 if has_draw or reserve_draw_slot else 0)) * 0.5
	for index in range(hand.size()):
		var number: int = hand[index]
		var chosen := selected_index == index
		var drawn := has_draw and index == hand.size() - 1
		if drawn:
			cursor += 10
		var handler := choose_tile.bind(index, number) if playable.has(number) else Callable()
		var node := tile(dynamic, number, Rect2(cursor, 700 - (9 if chosen else 0), 56, 76),
			view.gold, handler, chosen, drawn)
		node.name = "HandTile%d" % index
		human_buttons.append(node)
		if winning >= 0 and index == hand.size() - 1:
			winning_tile_rect = node.get_rect()
		if index == flower_slide_index:
			slide_flower_replacement(node)
		elif deal:
			slide(node, Vector2(0, 18), index * 0.017)
		elif drawn and wall_draw_from.is_finite():
			slide(node, wall_draw_from - node.get_rect().get_center())
		cursor += 59


func render_sidebar(view: Dictionary) -> void:
	label(dynamic, "本桌积分", Rect2(1094, 80, 100, 31), 21, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	label(dynamic, "累计", Rect2(1200, 85, 40, 22), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	for seat in range(4):
		var y := 120 + seat * 55
		panel(dynamic, Rect2(1093, y, 149, 46), Color("#213c30"), Color("#395543"))
		panel(dynamic, Rect2(1099, y + 9, 27, 28), PORTRAITS[seat], PORTRAITS[seat])
		set_player_font(label(dynamic, player_mark(seat), Rect2(1099, y + 9, 27, 28), 16, FONT_DARK, HORIZONTAL_ALIGNMENT_CENTER, true))
		set_player_font(label(dynamic, player_name(seat), Rect2(1133, y + 4, 63, 21), 13))
		var status := ""
		if not online_view.is_empty():
			var entry: Dictionary = view.seat_info[seat]
			if entry.get("managed", false):
				status = "AI 托管"
			elif not entry.get("connected", true) and entry.kind == "human":
				status = "断线"
			elif posmod(seat + room.state.my_seat, 4) == online_owner:
				status = "房主"
			elif entry.kind == "ai":
				status = "AI"
		var direction := seat_wind(seat) + (" · 庄" if seat == view.dealer else "")
		var score_caption := label(dynamic, direction if status.is_empty() else direction + " · " + status,
			Rect2(1133, y + 24, 76, 17), 11, GOLD if seat == view.dealer else MUTED)
		score_caption.name = "ScoreWind%d" % seat
		label(dynamic, points(view.scores[seat]), Rect2(1190, y + 7, 45, 32), 16,
			score_color(view.scores[seat]), HORIZONTAL_ALIGNMENT_RIGHT)
	label(dynamic, "行牌动态", Rect2(1094, 368, 146, 28), 21, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	for index in range(log_lines.size()):
		var shade := GOLD if index == 0 else MUTED
		var line := label(dynamic, log_lines[index], Rect2(1096, 400 + index * 27, 143, 23), 13, shade)
		set_player_font(line)


func points(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func score_color(value: int) -> Color:
	if value > 0:
		return Color("#add3a0")
	if value < 0:
		return Color("#ec9a83")
	return INK


func win_name(kind: String) -> String:
	return Rules.WIN_NAMES.get(kind, "胡牌")


func win_caption(move: Dictionary) -> String:
	var method: String = move.get("kind", "self")
	var pattern: String = move.get("pattern", method)
	if method in ["self", "discard"]:
		return "胡" if pattern == method else win_name(pattern)
	var caption := win_name(method)
	if pattern != method:
		caption += "·" + win_name(pattern)
	return caption


func result_caption(result: Dictionary) -> String:
	var method: String = result.get("method", result.kind)
	var caption := "胡牌" if method == "discard" else win_name(method)
	if result.kind != method:
		caption += " · " + win_name(result.kind)
	return caption


func result_title(result: Dictionary) -> String:
	if result.winner < 0:
		return "本局流局"
	var title := player_name(result.winner) + result_caption(result)
	if result.from >= 0:
		title += " · " + player_name(result.from)
		title += "被抢杠" if result.get("method", result.kind) == "rob" else "点炮"
	return title


func render_controls(view: Dictionary, moves: Array) -> void:
	var options: Array = []
	var detail := ""
	var intro_running := intro_active()
	if flower_active:
		detail = flower_status_text if not flower_status_text.is_empty() else "补花中…"
		options = []
	elif draw_flower_active:
		detail = "补花中…"
		options = []
	elif intro_running:
		detail = intro.status_text()
		options = []
	elif view.phase == "redeal":
		detail = "即将重新发牌"
	elif view.phase == "result":
		detail = result_title(view.result)
		if fx_hold_active:
			detail += "  ·  胡牌演出"
			options.append(["跳过演出", _finish_fx_hold, "normal", "skip"])
		else:
			options.append(["结算明细", show_result, "normal", "result"])
			if not online_view.is_empty() and not is_room_owner():
				detail += " · 等待房主"
			elif view.table_finished:
				options.append([end_table_text(), end_table, "primary", "home"])
			else:
				options.append(["下一局", next_round, "primary", "next"])
	elif view.phase == "opening":
		detail = "等待中" if moves.is_empty() else "开局" + win_name(view.opening)
		if moves.any(is_swap):
			detail += "  ·  " + ("选择一张手牌换金" if selected_tile < 0 else "已选 " + Rules.tile_name(selected_tile))
	elif view.phase == "reaction":
		detail = "%s打出 %s" % [player_name(view.last_discard.seat), Rules.tile_name(view.last_discard.tile)]
		if moves.is_empty():
			detail += "  ·  等待中"
	elif view.phase == "robKong":
		detail = "等待中" if moves.is_empty() else "可以抢杠"
	elif view.current == 0:
		detail = "轮到你出牌"
		if selected_tile >= 0:
			detail += "  ·  已选 " + Rules.tile_name(selected_tile)
		elif view.drawn >= 0:
			detail += "  ·  摸到 " + Rules.tile_name(view.drawn)
	else:
		detail = "%s正在行牌" % player_name(view.current)
	var discards := moves.any(func(move): return move.type == "discard")
	var swaps := moves.any(is_swap)
	var declarations := moves.filter(func(move): return move.type == "declareGoldGap")
	var selected_declarations := declarations if selected_tile < 0 else declarations.filter(
		func(move): return move.tile == selected_tile)
	if discards or swaps:
		if selected_tile >= 0:
			options.append(["取消选择", cancel_selection, "normal", "clear"])
		if not declarations.is_empty():
			options.append(["报听金坎", choose_action.bind("declareGoldGap", selected_declarations), "normal", "gold_gap"])
		if discards:
			options.append(["出牌", confirm_discard, "primary", "discard"])

	if stats != null and not stats_table_id.is_empty():
		var table_stats: Dictionary = stats.table_summary(stats_table_id)
		if int(table_stats.get("rounds", 0)) > 0:
			var table_seats: Array = table_stats.get("seats", [])
			var my_table: Dictionary = table_seats[0] if not table_seats.is_empty() else {}
			label(dynamic, "本桌统计", Rect2(1094, 518, 149, 16), 11, MUTED)
			label(dynamic, "你 胡%d 点%d · %d 局" % [
				int(my_table.get("wins", 0)), int(my_table.get("deal_ins", 0)),
				int(table_stats.get("rounds", 0))], Rect2(1094, 535, 149, 18), 12, INK)
	label(dynamic, "牌桌状态", Rect2(1094, 570, 149, 22), 16, MUTED)
	status_label = label(dynamic, detail, Rect2(1093, 596, 149, 56), 15,
		GOLD if not moves.is_empty() else INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	set_player_font(status_label)
	var cursor := 654.0
	for index in range(options.size()):
		var entry: Array = options[index]
		var node := button(dynamic, entry[0], Rect2(1093, cursor, 149, 36), entry[1], entry[2])
		controls[entry[3]] = node
		if entry[3] == "discard":
			node.disabled = not moves.any(func(move): return move.type == "discard" and move.tile == selected_tile)
		elif entry[3] == "gold_gap" and selected_declarations.is_empty():
			node.disabled = true
			node.tooltip_text = "所选牌无法报听。取消选择后可查看报听弃牌。"
		cursor += 40.0
	render_floating(moves)


func render_floating(moves: Array) -> void:
	var entries := []
	for entry in [
		["过", "pass", ["pass"], "pass"],
		["吃", "chow", ["chow"], "meld"],
		["碰", "pong", ["pong"], "meld"],
		["杠", "kong", ["kong", "concealedKong", "addedKong"], "meld"],
		["胡", "win", ["win"], "win"],
	]:
		var group: Array = moves.filter(func(move): return move.type in entry[2])
		if group.is_empty():
			continue
		var caption: String = entry[0]
		if entry[1] == "win":
			caption = win_caption(group[0])
		var handler := confirm_discard if group.any(is_swap) else choose_action.bind(entry[1], group)
		entries.append([caption, entry[1], entry[3], handler, group.any(is_swap)])
	var right := 1037.0
	for index in range(entries.size() - 1, -1, -1):
		var entry: Array = entries[index]
		var width := maxf(77.0, 24.0 * entry[0].length() + 30.0)
		right -= width
		var node := floating_button(entry[0], Rect2(right, 615, width, 64), entry[3], entry[4], entry[2])
		controls[entry[1]] = node
		right -= 9


func floating_button(caption: String, rect: Rect2, handler: Callable, needs_selection: bool, style: String) -> Button:
	var node := button(dynamic, caption, rect, handler)
	var colors: Array = {
		"pass": [Color("#4b514e"), Color("#bfc5ba"), Color("#f2f0e8")],
		"meld": [Color("#28694c"), Color("#95c492"), Color("#edffe5")],
		"win": [Color("#a93d30"), Color("#efa073"), Color("#ffe0a3")],
	}[style]
	var base: Color = colors[0]
	var border: Color = colors[1]
	for state in ["normal", "hover", "pressed"]:
		var fill := base if state == "normal" else (base.lightened(0.14) if state == "hover" else base.darkened(0.14))
		var shape := Art.box(fill, border, 15, 2)
		shape.shadow_color = Color(0.03, 0.08, 0.05, 0.8)
		shape.shadow_size = 5
		shape.shadow_offset = Vector2(0, 4)
		node.add_theme_stylebox_override(state, shape)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, colors[2])
	node.add_theme_color_override("font_outline_color", base.darkened(0.55))
	node.add_theme_constant_override("outline_size", 5)
	node.add_theme_font_size_override("font_size", 25 if caption.length() > 1 else 35)
	node.add_theme_font_override("font", action_font)
	node.disabled = needs_selection and selected_tile < 0
	return node


func choose_action(kind: String, moves: Array) -> void:
	if moves.is_empty():
		return
	var declaration := kind == "declareGoldGap"
	if moves.size() == 1 and not declaration:
		perform(0, moves[0])
		return
	var width := 395
	var rows := mini(moves.size(), 7)
	var height := 130 + 73 * rows
	var title: String = {"chow": "选择吃法", "kong": "选择杠法", "declareGoldGap": "选择报听弃牌"}[kind]
	var dialog := open_modal(title, width, height)
	modal_tracks_stage = not online_view.is_empty()
	if modal_tracks_stage:
		chooser_countdown = label(dialog, "", Rect2(width - 152, 54, 120, 28), 15, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		update_online_clock()
	var context = room if modal_tracks_stage else game
	var gold: int = board_view().gold
	var list: Control = dialog
	var row_origin := Vector2(24, 89)
	if moves.size() > rows:
		var scroll := ScrollContainer.new()
		scroll.position = row_origin
		scroll.size = Vector2(width - 30, 73 * rows)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		dialog.add_child(scroll)
		list = Control.new()
		list.custom_minimum_size = Vector2(width - 48, 73 * moves.size())
		scroll.add_child(list)
		row_origin = Vector2.ZERO
	for index in range(moves.size()):
		var move: Dictionary = moves[index]
		var choice := button(list, "", Rect2(row_origin + Vector2(0, index * 73), Vector2(width - 48, 63)),
			submit_choice.bind(move, context, modal))
		if declaration:
			label(choice, "打出", Rect2(18, 0, 38, 63), 16, INK)
			tile(choice, move.tile, Rect2(62, 5, 38, 51), gold, Callable(), false, true)
			label(choice, "亮牌", Rect2(152, 0, 40, 63), 16, GOLD)
			for tile_index in range(move.tiles.size()):
				tile(choice, move.tiles[tile_index], Rect2(200 + 44 * tile_index, 5, 38, 51), gold)
			choice.tooltip_text = "打出" + Rules.tile_name(move.tile) + "并报听金坎"
			continue
		var numbers: Array = move.get("tiles", [move.tile, move.tile, move.tile, move.tile]).duplicate()
		if kind == "chow":
			numbers.append(move.tile)
			numbers.sort()
		var marked := numbers.find(move.tile) if kind == "chow" else -1
		for tile_index in range(numbers.size()):
			var number: int = numbers[tile_index]
			tile(choice, number, Rect2(17 + 44 * tile_index, 5, 38, 51), gold,
				Callable(), false, tile_index == marked)
		if kind == "chow":
			label(choice, "来牌 " + Rules.tile_name(move.tile), Rect2(167, 13, 150, 38), 15, GOLD)
		else:
			label(choice, Rules.MELD_NAMES[move.type], Rect2(209, 13, 113, 38), 17, INK)
		choice.tooltip_text = "、".join(numbers.map(Rules.tile_name))
	button(dialog, "返回", Rect2(width - 124, height - 40, 100, 32), close_modal)


func submit_choice(move: Dictionary, owner, chooser: Control) -> void:
	var context = game if online_view.is_empty() else room
	if owner != context or chooser != modal:
		return
	close_modal(false)
	if local_moves().any(func(available): return available.id == move.id):
		perform(0, move)
	else:
		refresh()


func open_modal(title: String, width: int, height: int, pause_ai := true) -> Panel:
	interactions.close()
	close_modal(false)
	if pause_ai:
		ai_timer.stop()
	suspend_focus(self)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.05, 0.04, 0.78)
	backdrop.size = Vector2(1280, 800)
	backdrop.z_index = 10
	add_child(backdrop)
	modal = backdrop
	var dialog := panel(backdrop, Rect2((1280 - width) * 0.5, (800 - height) * 0.5, width, height),
		Color("#233c30"), Color("#ab8852"), 16)
	label(dialog, "融城茶馆", Rect2(24, 18, width - 60, 19), 13, GOLD)
	var heading := label(dialog, title, Rect2(24, 40, width - 82, 42), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button(dialog, "×", Rect2(width - 60, 21, 36, 36), close_modal).grab_focus()
	return dialog


func suspend_focus(branch: Node) -> void:
	for control in branch.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL:
			suspended_focus.append(control)
			control.focus_mode = Control.FOCUS_NONE


func close_modal(resume := true) -> void:
	if is_instance_valid(modal):
		var closing_settings := is_instance_valid(settings_panel)
		var closing_stats := is_instance_valid(stats_panel)
		remove_child(modal)
		modal.queue_free()
		modal = null
		settings_panel = null
		stats_panel = null
		modal_tracks_stage = false
		chooser_countdown = null
		for control in suspended_focus:
			if is_instance_valid(control):
				control.focus_mode = Control.FOCUS_ALL
		suspended_focus.clear()
		if resume:
			if closing_stats or not closing_settings:
				refresh()
			else:
				var view := board_view()
				if view.get("phase") == "result" and shown_round != view.round:
					show_result()


func show_reset() -> void:
	if game == null and online_view.is_empty() and not online_rolling:
		show_lobby()
		return
	if not online_view.is_empty() or online_rolling:
		var dialog := open_modal("退出房间？", 440, 192)
		var explanation := "关闭承载端会结束当前房间。" if room.state.my_seat == room.state.get("host_seat", 0) else "退出后由 AI 接管你的座位。"
		label(dialog, explanation, Rect2(24, 90, 391, 28), 16, MUTED)
		button(dialog, "继续本桌", Rect2(188, 138, 104, 36), close_modal)
		button(dialog, "退出房间", Rect2(302, 138, 114, 36), exit_online, "primary")
		return
	if game.is_table_finished():
		show_lobby()
		return
	var dialog := open_modal("返回首页？", 408, 192)
	label(dialog, "返回首页后，本桌对局结束。", Rect2(24, 90, 365, 28), 16, MUTED)
	button(dialog, "继续本桌", Rect2(156, 138, 104, 36), close_modal)
	button(dialog, "返回首页", Rect2(270, 138, 114, 36), show_lobby, "primary")


func show_transfer() -> void:
	var targets: Array[int] = []
	for seat in range(4):
		var entry: Dictionary = room.state.seats[seat]
		if seat != room.state.my_seat and entry.get("kind") == "human" and entry.get("connected", false):
			targets.append(seat)
	var dialog := open_modal("移交房主", 440, 140 + 45 * targets.size())
	if targets.is_empty():
		label(dialog, "当前没有其他在线真人。", Rect2(24, 92, 391, 27), 16, MUTED)
	for index in range(targets.size()):
		var seat := targets[index]
		var node := button(dialog, room.state.seats[seat].name, Rect2(24, 90 + index * 45, 392, 37),
			confirm_transfer.bind(seat))
		node.add_theme_font_override("font", nickname_font)


func confirm_transfer(seat: int) -> void:
	close_modal(false)
	room.request("transfer", {"seat": seat})


func _process(_delta: float) -> void:
	if not online_view.is_empty():
		update_online_clock()


func update_online_clock() -> void:
	var remaining: int = room.seconds_left()
	var limit: int = room.state.get("turn_seconds", 0)
	var timed: bool = limit > 0 and remaining >= 0 and not online_reconnecting and online_view.phase not in ["result", "redeal"]
	var seconds := mini(limit, remaining)
	var digits := "%02d" % seconds if timed and center_dial.visible else ""
	if countdown_label.text != digits:
		countdown_label.text = digits
	var urgent := timed and seconds <= 5
	if is_instance_valid(fx):
		fx.set_urgent(urgent)
	var clock_color := Color("#ff9a7a") if urgent else Color("#97eafa")
	if countdown_label.get_theme_color("font_color") != clock_color:
		countdown_label.add_theme_color_override("font_color", clock_color)
	if is_instance_valid(chooser_countdown):
		var caption := "正在重连" if online_reconnecting else ("%d 秒" % seconds if timed else "不限时")
		if chooser_countdown.text != caption:
			chooser_countdown.text = caption
	if is_instance_valid(room_notice_label):
		var message := last_notice if Time.get_ticks_msec() < notice_until else ""
		if room_notice_label.text != message:
			room_notice_label.text = message


func show_rules() -> void:
	var dialog := open_modal("玩法规则", 640, 595)
	var body := RichTextLabel.new()
	body.position = Vector2(24, 93)
	body.size = Vector2(592, 465)
	body.bbcode_enabled = true
	body.add_theme_font_override("normal_font", session_font)
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_color_override("default_color", INK)
	body.add_theme_constant_override("line_separation", 6)
	body.text = """
[color=#edc780]开局与金牌[/color]
全副 144 张，四人逆时针行牌。庄家摸 17 张，闲家各摸 16 张，然后开金、补花。翻到数牌时，同牌为普通金。翻到东南西北中发白时，同牌为花金。翻到春夏秋冬任一张时，四季都作花金。梅兰竹菊同理。花金留在手中，其余花照常补。补花和杠后从牌尾补，保留最后 18 张，无法摸补时流局。庄家胡或流局连庄，闲家胡则由庄家下家接庄。

开局依次处理天胡、三金倒、抢金。闲家按行牌顺序优先抢金，直接拿桌面金成胡。闲家都放弃后，符合条件的庄家可用一张手牌换金成胡。

[color=#edc780]争牌与抢杠[/color]
吃只限上家。胡优先于碰杠，碰杠优先于吃，同级从出牌者下家起依次处理。打出的金不能被认领。打过金的玩家只能自摸，手中只有一张金且单吊该金的玩家也只能自摸。有人补杠时，其他牌手可按座次用第四张牌抢杠胡。

庄家上家手中无金时，可照常响应自己上家的弃牌。其余两家的弃牌可胡，也可在碰后能听时碰。例外碰牌后须打出一张能保持听牌的牌，此后锁牌并摸打，仍可胡、暗杠、补杠和抢杠。锁牌后摸到金立即自摸。

[color=#edc780]首巡流局[/color]
从庄家第一次正常出牌起，若四家首张弃牌的牌面完全相同，第四张打出时立即流局。前三张照常争牌。首巡实际吃、碰、明杠或补杠会取消判定。暗杠、补花和放弃争牌不影响判定。短暂提示后自动重发，庄家、局号和积分照旧。

[color=#edc780]报听金坎[/color]
金为数牌时，可打出听牌弃牌并亮出同花色、夹着金牌的两张坎搭子。报听后摸打，不能吃碰杠，只能自摸金补成这副顺子胡牌。

[color=#edc780]胡牌与结算[/color]
平胡由五组加一对将组成。平胡分 P = 底分 ＋ 花分 ＋ 普通金张数 ＋ 2 × 花金张数。胡家为庄底分 3，闲家底分 1。每张实际花、每个明杠或补杠各计 1 花，暗杠计 2 花。

闲金要求在自摸前留出一张金单吊，余牌连同副露和杠能凑齐五组。手中有两张金时，另一张可补成顺子或刻子。自摸非金成将即符合闲金。

平胡 P，自摸和抢杠 2P，闲金 2P＋10，三金倒、抢金和碰碰胡 3P，金雀和金坎 4P＋40，金龙、天胡、正清和单吊 5P＋50。金雀用双金作将，金龙用三金作一组刻子，碰碰胡为五组刻子加一对将，单吊为五副明牌全部亮出、手中只留最后一张与来牌成将，按正清计分，正清允许金代替同一花色的数牌。多种牌型成立时取最高分。多家同时能胡同一张牌时，牌型大的优先，不能截胡；牌型相同时，从出牌者下家起按行牌顺序决定。点炮由出牌者付，抢杠由被抢杠者付，自摸及开局特殊胡法由其他三家各付。
""".strip_edges()
	dialog.add_child(body)


func winning_tile_for(view: Dictionary, seat: int, hand: Array) -> int:
	var result: Dictionary = view.get("result", {})
	var number := int(result.get("tile", -1))
	if effects != "off" and view.phase == "result" and int(result.get("winner", -1)) == seat and number in hand:
		return number
	return -1


func _play_result_effects(view: Dictionary) -> void:
	if not is_instance_valid(fx) or int(view.hand_id) == fx_result_hand:
		return
	fx_result_hand = int(view.hand_id)
	var result: Dictionary = view.get("result", {})
	var source := Rect2()
	var from := int(result.get("from", -1))
	if from in range(4) and result.get("method", result.get("kind")) == "discard" and result.has("tile"):
		# The engine has already transferred the winning discard out of the river.
		source = river_slots(from, view.players[from].river.size() + 1).back()
	fx.play_win(view, source, winning_tile_rect)
	for seat in range(4):
		var delta := int(result.get("deltas", [0, 0, 0, 0])[seat])
		if delta != 0:
			fx.score_delta(seat, delta)


func _begin_result_hold(view: Dictionary) -> bool:
	if not fx_hold_results or not is_instance_valid(fx) or effects == "off":
		return false
	var result: Dictionary = view.get("result", {})
	if int(result.get("winner", -1)) < 0:
		return false
	if fx_hold_active:
		return true
	_play_result_effects(view)
	if is_instance_valid(action_banner):
		action_banner.hide()
	fx_hold_active = true
	shown_round = view.round
	var delay := clampf(float(fx.win_duration) + 0.2, 1.0, 2.0)
	fx_hold_timer.start(delay)
	refresh()
	return true


func _finish_fx_hold() -> void:
	if not fx_hold_active:
		return
	fx_hold_active = false
	fx_hold_timer.stop()
	if is_instance_valid(fx):
		fx.stop_win()
	refresh()
	var view := board_view()
	if view.get("phase") == "result":
		show_result()


func show_result() -> void:
	var view := board_view()
	if view.get("phase") != "result":
		return
	var result: Dictionary = view.get("result", {})
	if result.is_empty():
		return
	shown_round = view.round
	_play_result_effects(view)
	var finished: bool = view.table_finished
	var title := result_title(result)
	if finished:
		title = "整桌结算 · " + title
	var dialog_width := 720 if finished else 626
	var dialog := open_modal(title, dialog_width, 463)
	modal_tracks_stage = not online_view.is_empty()
	var copy := "已到保留牌尾，本局积分不变。"
	if result.winner >= 0:
		var winner: Dictionary = view.players[result.winner]
		var hand: Array = winner.hand.duplicate()
		hand.sort()
		for meld in winner.melds:
			hand.append_array(meld.tiles)
		for index in range(hand.size()):
			tile(dialog, hand[index], Rect2(24 + index * 25, 93, 23, 32), view.gold)
		var payers := "、".join(result.payers.map(player_name))
		var method: String = result.get("method", result.kind)
		var source := ""
		if method == "rob":
			source = " · 被抢杠者 " + player_name(result.from)
		elif method == "discard":
			source = " · 点炮者 " + player_name(result.from)
		var flower_golds: int = result.get("flower_golds", 0)
		var ordinary_gold_points: int = result.gold_points - flower_golds * 2
		copy = "胡法 %s · 最高分牌型 %s%s\n底分 %d ＋ 花分 %d ＋ 普通金 %d ＋ 花金 %d × 2 = %d\n%d × %d ＋ %d = 每家应付 %d 分。付款方 %s" % [
			win_name(method), "平胡" if result.kind == "discard" else win_name(result.kind), source,
			result.base_points, result.flower_points, ordinary_gold_points, flower_golds, result.base,
			result.base, result.multiplier, result.offset, result.per_payer, payers]
	var copy_label := label(dialog, copy, Rect2(24, 136, dialog_width - 48, 82), 15, MUTED)
	if not online_view.is_empty():
		copy_label.add_theme_font_override("font", nickname_font)
	copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel(dialog, Rect2(24, 222, dialog_width - 48, 169), Color("#1c3228"), Color("#47604d"))
	var table_stats: Dictionary = stats.table_summary(stats_table_id) if stats != null else {}
	var table_seats: Array = table_stats.get("seats", [])
	if finished:
		label(dialog, "牌手", Rect2(40, 231, 130, 20), 13, MUTED)
		label(dialog, "排名", Rect2(176, 231, 46, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		var hu_heading := label(dialog, "胡牌", Rect2(228, 231, 50, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		hu_heading.tooltip_text = "本桌胡牌次数"
		var dian_heading := label(dialog, "点炮", Rect2(284, 231, 50, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		dian_heading.tooltip_text = "本桌点炮次数，不含被抢杠"
		label(dialog, "本局", Rect2(344, 231, 80, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		label(dialog, "累计", Rect2(452, 231, 80, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		label(dialog, "牌手", Rect2(40, 231, 130, 20), 13, MUTED)
		label(dialog, "本局", Rect2(349, 231, 85, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		label(dialog, "累计", Rect2(497, 231, 85, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var standings: Array = []
	if finished:
		standings = game.standings() if online_view.is_empty() else view.standings
	for index in range(4):
		var seat: int = standings[index].seat if finished else index
		var y := 257 + index * 30
		set_player_font(label(dialog, player_name(seat), Rect2(40, y, 150, 25), 16))
		if finished:
			label(dialog, str(standings[index].rank), Rect2(176, y, 46, 25), 16, GOLD,
				HORIZONTAL_ALIGNMENT_RIGHT)
			var table_seat: Dictionary = table_seats[seat] if seat < table_seats.size() else {}
			label(dialog, str(int(table_seat.get("wins", 0))), Rect2(228, y, 50, 25), 16, INK,
				HORIZONTAL_ALIGNMENT_RIGHT)
			label(dialog, str(int(table_seat.get("deal_ins", 0))), Rect2(284, y, 50, 25), 16, INK,
				HORIZONTAL_ALIGNMENT_RIGHT)
			label(dialog, points(result.deltas[seat]), Rect2(344, y, 80, 25),
				17, score_color(result.deltas[seat]), HORIZONTAL_ALIGNMENT_RIGHT)
			label(dialog, points(view.scores[seat]), Rect2(452, y, 80, 25),
				17, score_color(view.scores[seat]), HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			label(dialog, points(result.deltas[seat]), Rect2(349, y, 85, 25),
				17, score_color(result.deltas[seat]), HORIZONTAL_ALIGNMENT_RIGHT)
			label(dialog, points(view.scores[seat]), Rect2(497, y, 85, 25),
				17, score_color(view.scores[seat]), HORIZONTAL_ALIGNMENT_RIGHT)
	button(dialog, "本局统计", Rect2(24, 410, 106, 35), show_stats.bind("round"))
	button(dialog, "查看牌桌", Rect2(372, 410, 106, 35), close_modal)
	if not online_view.is_empty() and not is_room_owner():
		label(dialog, "等待房主", Rect2(488, 410, 114, 35), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	elif finished:
		button(dialog, end_table_text(), Rect2(488, 410, 114, 35), end_table, "primary")
	else:
		button(dialog, "下一局", Rect2(488, 410, 114, 35), next_round, "primary")


func end_table_text() -> String:
	return "返回首页" if online_view.is_empty() else "返回房间"


func end_table() -> void:
	if online_view.is_empty():
		show_lobby()
	else:
		room.request("lobby", {"stage": online_stage})


func _unhandled_input(event: InputEvent) -> void:
	if fx_hold_active:
		var skip_hold := false
		if event is InputEventMouseButton and event.pressed:
			skip_hold = true
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			skip_hold = true
		if skip_hold:
			_finish_fx_hold()
			get_viewport().set_input_as_handled()
		return
	if flower_active:
		var finish := false
		if event is InputEventMouseButton and event.pressed:
			finish = true
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			finish = true
		if finish:
			_finish_flower_sequence()
			get_viewport().set_input_as_handled()
		return
	if not intro_active():
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		skip = true
	if skip:
		skip_intro()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if menu_open():
			close_menu()
		elif is_instance_valid(modal):
			close_modal()
		elif selected_tile >= 0:
			cancel_selection()
	elif event.keycode == KEY_ENTER and not is_instance_valid(modal):
		confirm_discard()
