extends Control

const Skins = preload("res://scripts/tile_skins.gd")
const SKIN_IDS := ["riichi", "guobiao"]
const SAMPLE_TILES := [3, 13, 18, 27, 34]
const INK := Color("#f3e5cb")
const GOLD := Color("#edc780")
const MUTED := Color("#b0bd9e")

var desk
var nickname: LineEdit
var initial_nickname := ""
var interaction_effects: CheckButton
var fullscreen: CheckButton
var effects_menu: OptionButton
var skin: OptionButton
var table_menu: OptionButton
var notice: Label
var remove_button: Button
var apply_button: Button
var preview_tiles: Control
var preview_table: TextureRect
var picker: FileDialog
var table_ids: Array[String] = []
var removed_tables: Array[String] = []
var preview_skin := ""
var pending_image: Image
var pending_name := ""


func setup(table) -> void:
	desk = table
	var preferences: Dictionary = desk.preferences.values
	desk.label(self, "默认昵称", Rect2(28, 97, 188, 38), 18, INK)
	nickname = LineEdit.new()
	nickname.position = Vector2(140, 97)
	nickname.size = Vector2(266, 38)
	initial_nickname = preferences.nickname
	nickname.text = initial_nickname
	nickname.placeholder_text = "输入昵称（最多 12 字）"
	nickname.max_length = 12
	nickname.add_theme_font_override("font", desk.nickname_font)
	nickname.add_theme_font_size_override("font_size", 17)
	add_child(nickname)
	desk.label(self, "下次开房或加入时自动填入", Rect2(425, 97, 274, 38), 15, MUTED)
	desk.label(self, "麻将皮肤", Rect2(28, 159, 108, 38), 18, INK)
	skin = make_menu(Rect2(140, 159, 220, 38))
	skin.add_item("日麻")
	skin.add_item("国标")
	skin.select(SKIN_IDS.find(preferences.skin))
	skin.item_selected.connect(func(_index): refresh_preview())
	interaction_effects = CheckButton.new()
	interaction_effects.text = "显示互动特效"
	interaction_effects.button_pressed = preferences.interaction_effects
	interaction_effects.position = Vector2(425, 157)
	interaction_effects.add_theme_font_override("font", desk.session_font)
	interaction_effects.add_theme_font_size_override("font_size", 16)
	add_child(interaction_effects)
	if OS.get_name() == "Windows":
		fullscreen = CheckButton.new()
		fullscreen.text = "全屏（F11）"
		fullscreen.button_pressed = preferences.fullscreen
		fullscreen.position = Vector2(425, 207)
		fullscreen.add_theme_font_override("font", desk.session_font)
		fullscreen.add_theme_font_size_override("font_size", 16)
		add_child(fullscreen)
	desk.label(self, "特效强度", Rect2(425, 247, 100, 24), 15, MUTED)
	effects_menu = make_menu(Rect2(525, 240, 145, 34))
	effects_menu.add_item("完整")
	effects_menu.add_item("简洁")
	effects_menu.add_item("关闭")
	effects_menu.select(["full", "simple", "off"].find(preferences.effects))
	preview_tiles = Control.new()
	preview_tiles.position = Vector2(28, 211)
	add_child(preview_tiles)
	desk.label(self, "牌桌", Rect2(28, 327, 108, 38), 18, INK)
	table_menu = make_menu(Rect2(140, 327, 278, 38))
	table_menu.item_selected.connect(func(_index): refresh_preview())
	desk.button(self, "导入牌桌", Rect2(430, 327, 130, 38), open_picker)
	remove_button = desk.button(self, "移除", Rect2(572, 327, 98, 38), remove_selected_table)
	var felt: Panel = desk.panel(self, Rect2(28, 386, 290, 212), Color("#23523f"), Color("#997454"), 8)
	preview_table = TextureRect.new()
	preview_table.position = Vector2(3, 3)
	preview_table.size = Vector2(284, 206)
	preview_table.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_table.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview_table.modulate = Color(0.83, 0.83, 0.83)
	preview_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_child(preview_table)
	desk.label(self, "PNG 或 JPEG · 最长边 4096 像素\n等比铺满桌布，图片只保存在本机。", Rect2(345, 399, 325, 72), 16, MUTED)
	notice = desk.label(self, "", Rect2(345, 483, 325, 104), 16, GOLD)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desk.button(self, "取消", Rect2(462, 616, 100, 39), desk.close_modal)
	apply_button = desk.button(self, "应用", Rect2(574, 616, 100, 39), apply, "primary")
	var picker_theme := Theme.new()
	picker_theme.default_font = desk.nickname_font
	picker = FileDialog.new()
	picker.theme = picker_theme
	picker.title = "导入牌桌"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.png ; PNG", "*.jpg, *.jpeg ; JPEG"])
	picker.file_selected.connect(select_image)
	add_child(picker)
	rebuild_tables(preferences.table_id)


func make_menu(rect: Rect2) -> OptionButton:
	var menu := OptionButton.new()
	menu.position = rect.position
	menu.size = rect.size
	menu.fit_to_longest_item = false
	menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.add_theme_font_override("font", desk.nickname_font)
	menu.add_theme_font_size_override("font_size", 16)
	menu.get_popup().add_theme_font_override("font", desk.nickname_font)
	add_child(menu)
	return menu


func rebuild_tables(selected: String) -> void:
	table_ids = [""]
	table_menu.clear()
	table_menu.add_item("内置绿桌")
	for record in desk.preferences.list_tables():
		if record.id not in removed_tables:
			table_ids.append(record.id)
			table_menu.add_item(record.name)
	if pending_image != null:
		table_ids.append(":import")
		table_menu.add_item(pending_name + "（待导入）")
	table_menu.select(maxi(0, table_ids.find(selected)))
	refresh_preview()


func refresh_preview() -> void:
	var selected_skin: String = SKIN_IDS[skin.selected]
	if selected_skin != preview_skin:
		preview_skin = selected_skin
		for tile in preview_tiles.get_children():
			preview_tiles.remove_child(tile)
			tile.queue_free()
		var faces := Skins.faces(preview_skin)
		for index in range(SAMPLE_TILES.size()):
			var number: int = SAMPLE_TILES[index]
			var tile = desk.tile(preview_tiles, number, Rect2(index * 66, 0, 52, 71), -1)
			tile.texture = faces[number]
			tile.guobiao_face = preview_skin == "guobiao"
			tile.queue_redraw()
	var id: String = table_ids[table_menu.selected]
	preview_table.texture = ImageTexture.create_from_image(pending_image) if id == ":import" else desk.preferences.table_texture(id)
	remove_button.disabled = id.is_empty()
	var unavailable := not id.is_empty() and preview_table.texture == null
	apply_button.disabled = unavailable
	if unavailable:
		notice.text = "这张桌布无法读取，请重新导入或选择其他牌桌。"
	elif notice.text.begins_with("这张桌布"):
		notice.text = ""


func open_picker() -> void:
	picker.popup_centered_ratio(0.8)


func select_image(path: String) -> void:
	var result: Dictionary = desk.preferences.read_table_image(path)
	if not result.has("image"):
		notice.text = result.message
		return
	pending_image = result.image
	pending_name = path.get_file().get_basename().left(48)
	notice.text = ""
	rebuild_tables(":import")


func remove_selected_table() -> void:
	var id: String = table_ids[table_menu.selected]
	if id.is_empty():
		return
	if id == ":import":
		pending_image = null
	else:
		removed_tables.append(id)
	notice.text = "应用后移除此牌桌。"
	var active: String = desk.preferences.values.table_id
	rebuild_tables("" if active in removed_tables else active)


func apply() -> void:
	var name_value := nickname.text.strip_edges()
	for character in name_value:
		var code := character.unicode_at(0)
		if code < 32 or code in [127, 8232, 8233]:
			notice.text = "昵称须使用可见字符。"
			return
	var id: String = table_ids[table_menu.selected]
	var changes := {"skin": SKIN_IDS[skin.selected], "table_id": "" if id == ":import" else id,
		"interaction_effects": interaction_effects.button_pressed}
	if is_instance_valid(fullscreen):
		changes.fullscreen = fullscreen.button_pressed
	changes.effects = ["full", "simple", "off"][effects_menu.selected]
	if name_value != initial_nickname:
		changes.nickname = name_value
	var previous_name: String = desk.preferences.values.nickname
	var imported: Image = pending_image if id == ":import" else null
	var error: Error = desk.preferences.apply_appearance(changes, imported, pending_name, removed_tables)
	if error != OK:
		notice.text = "无法保存设置，原设置已保留。"
		return
	desk.apply_saved_appearance()
	if changes.has("nickname") and name_value != previous_name and is_instance_valid(desk.online_lobby):
		desk.online_lobby.entry_name.text = name_value
	desk.close_modal()
