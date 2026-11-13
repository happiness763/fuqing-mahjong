extends Control

const Art = preload("res://scripts/table_art.gd")
const GOLD := Color("#edc780")
const INK := Color("#f3e5cb")
const MUTED := Color("#b0bd9e")

var desk
var slider: HSlider
var round_field: LineEdit
var round_error: Label
var start_button: Button
var online_button: Button
var settings_button: Button
var selections: Dictionary
var choice_buttons := {}


func setup(table, settings: Dictionary) -> void:
	desk = table
	selections = settings.duplicate()
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color("#14291f")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	desk.panel(self, Rect2(40, 40, 1200, 720), Color("#1a3328"), Color("#605a40"), 24)
	desk.panel(self, Rect2(668, 75, 530, 650), Color("#203a2e"), Color("#6c7553"), 17)
	desk.panel(self, Rect2(90, 91, 66, 60), Color("#9b4133"), Color("#d78569"), 10)
	desk.label(self, "福", Rect2(90, 91, 66, 60), 38, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	desk.label(self, "福清麻将", Rect2(90, 170, 490, 85), 68, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.label(self, "融城茶馆", Rect2(94, 263, 450, 38), 26, GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.panel(self, Rect2(90, 344, 500, 214), Color("#23503e"), Color("#8b7951"), 18)
	desk.panel(self, Rect2(102, 356, 476, 190), Color.TRANSPARENT, Color("#667b58"), 12)
	var display := [0, 9, 18, 22]
	for index in range(display.size()):
		var number: int = display[index]
		var node: Control = desk.tile(self, number, Rect2(130 + 106 * index, 387, 87, 116), 9)
		node.rotation_degrees = [-8, -3, 4, 8][index]
	desk.label(self, "你与三位 AI 同桌", Rect2(94, 587, 430, 31), 20, INK)
	var version := str(ProjectSettings.get_setting("application/config/version"))
	desk.label(self, "v" + version, Rect2(94, 680, 250, 24), 15, MUTED)

	desk.label(self, "开桌设置", Rect2(704, 103, 400, 45), 32, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	desk.label(self, "模式", Rect2(704, 163, 112, 36), 18, INK)
	desk.button(self, "单机模式", Rect2(809, 163, 168, 42), Callable(), "primary")
	online_button = desk.button(self, "联机模式", Rect2(987, 163, 175, 42), desk.show_online)

	desk.label(self, "局数", Rect2(704, 250, 95, 36), 18, INK)
	slider = HSlider.new()
	slider.position = Vector2(809, 255)
	slider.size = Vector2(246, 29)
	slider.min_value = 1
	slider.max_value = 32
	slider.step = 1
	slider.value = selections.rounds
	slider.add_theme_stylebox_override("slider", Art.box(Color("#172f24"), Color("#597158"), 5))
	slider.add_theme_stylebox_override("grabber_area", Art.box(Color("#92a378"), Color("#92a378"), 5))
	slider.add_theme_stylebox_override("grabber_area_highlight", Art.box(Color("#b5c08e"), Color("#b5c08e"), 5))
	add_child(slider)
	round_field = LineEdit.new()
	round_field.position = Vector2(1068, 249)
	round_field.size = Vector2(94, 42)
	round_field.text = str(selections.rounds)
	round_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_field.max_length = 12
	round_field.add_theme_font_override("font", desk.session_font)
	round_field.add_theme_font_size_override("font_size", 19)
	round_field.add_theme_color_override("font_color", INK)
	round_field.add_theme_stylebox_override("normal", Art.box(Color("#192e25"), Color("#75906d")))
	round_field.add_theme_stylebox_override("focus", Art.box(Color.TRANSPARENT, GOLD, 8, 2))
	add_child(round_field)
	round_error = desk.label(self, "1–32 局", Rect2(809, 294, 353, 24), 14, MUTED)
	slider.value_changed.connect(change_slider)
	round_field.text_changed.connect(change_input)
	round_field.text_submitted.connect(func(_value): start())

	choice_row("难度", "difficulty", ["简单", "普通", "困难"], ["easy", "normal", "hard"], 355)
	choice_row("运气", "luck", ["非酋", "普通", "欧皇"], ["unlucky", "normal", "lucky"], 451)
	start_button = desk.button(self, "开始游戏", Rect2(704, 570, 458, 58), start, "primary")
	start_button.add_theme_font_size_override("font_size", 23)
	settings_button = desk.button(self, "设置", Rect2(704, 652, 222, 39), desk.show_settings)
	desk.button(self, "玩法规则", Rect2(940, 652, 222, 39), desk.show_rules)
	start_button.grab_focus()


func choice_row(title: String, key: String, labels: Array, values: Array, y: int) -> void:
	desk.label(self, title, Rect2(704, y, 95, 42), 18, INK)
	var group := ButtonGroup.new()
	choice_buttons[key] = {}
	for index in range(labels.size()):
		var node: Button = desk.button(self, labels[index], Rect2(809 + index * 119, y, 113, 42), Callable())
		node.toggle_mode = true
		node.button_group = group
		node.button_pressed = selections[key] == values[index]
		choice_buttons[key][values[index]] = node
		node.add_theme_stylebox_override("pressed", Art.box(Color("#48694e"), GOLD, 8, 2))
		node.pressed.connect(select.bind(key, values[index]))


func select(key: String, value: String) -> void:
	if desk.save_preferences({key: value}):
		selections[key] = value
	elif choice_buttons.has(key):
		choice_buttons[key][selections[key]].set_pressed_no_signal(true)


func change_slider(value: float) -> void:
	round_field.text = str(int(value))
	change_input(round_field.text)


func change_input(raw: String) -> void:
	var value := raw.strip_edges()
	var valid := value.is_valid_int() and value.to_int() >= 1 and value.to_int() <= 32
	start_button.disabled = not valid
	round_error.text = "1–32 局" if valid else "请输入 1–32 的整数"
	round_error.add_theme_color_override("font_color", MUTED if valid else Color("#f0a18d"))
	if valid:
		var rounds := value.to_int()
		if desk.save_preferences({"rounds": rounds}):
			selections.rounds = rounds
		else:
			round_field.text = str(selections.rounds)
		slider.set_value_no_signal(selections.rounds)


func show_save_error() -> void:
	round_error.text = "无法保存设置，原设置已保留。"
	round_error.add_theme_color_override("font_color", Color("#f0a18d"))


func start() -> void:
	if not start_button.disabled:
		desk.begin_game(selections)
