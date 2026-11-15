extends SceneTree

var failures := 0
var root_dir := OS.get_temp_dir().path_join("mahjong-prefs-test-" + Crypto.new().generate_random_bytes(10).hex_encode())


func _initialize() -> void:
	const PREFERENCES_PATH := "res://scripts/preferences.gd"
	if not ResourceLoader.exists(PREFERENCES_PATH):
		check(false, "local preferences and table storage are available")
		quit(failures)
		return
	var preferences = load(PREFERENCES_PATH)
	test_preferences(preferences, root_dir.path_join("preferences"))
	test_table_library(preferences, root_dir.path_join("library"))
	test_invalid_images(preferences, root_dir.path_join("invalid-images"))
	test_failed_save(preferences, root_dir.path_join("failed-save"))
	clean(root_dir)
	if failures == 0:
		print("v1.2.5 preferences tests passed")
	quit(failures)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func test_preferences(preferences: Script, path: String) -> void:
	var prefs = preferences.new(path)
	check(prefs.values == {
		"nickname": "", "rounds": 15, "difficulty": "normal", "luck": "normal",
		"host_port": 36712, "room_rounds": 15, "turn_seconds": 60, "muted": false,
		"skin": "riichi", "table_id": "", "interaction_effects": true,
	}, "a fresh install starts with defaults")
	var changes := {"nickname": "榕城茶客", "rounds": 24, "difficulty": "hard", "luck": "unlucky",
		"host_port": 36720, "room_rounds": 8, "turn_seconds": 0, "muted": true, "skin": "guobiao",
		"interaction_effects": false}
	check(prefs.update(changes) == OK, "valid preferences are saved")
	check(prefs.update({"rounds": 0, "muted": false}) != OK, "invalid changes are rejected together")
	check(prefs.update({"nickname": "茶\n客"}) != OK, "nicknames with embedded control characters are rejected")
	var recovered = preferences.new(path)
	for key: String in changes:
		check(recovered.values[key] == changes[key], "restart restores " + key)
	var config_path := path.path_join("preferences.json")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	config.values.rounds = -1
	config.values.host_port = 36720.5
	config.values.skin = "unknown"
	config.values.erase("difficulty")
	config.values.table_id = "../outside"
	write_bytes(config_path, JSON.stringify(config).to_utf8_buffer())
	recovered = preferences.new(path)
	check(recovered.values.rounds == 15 and recovered.values.host_port == 36712,
		"out-of-range and noninteger settings each restore their defaults")
	check(recovered.values.skin == "riichi" and recovered.values.difficulty == "normal" and recovered.values.table_id == "",
		"unknown, missing and unsafe values restore their defaults")
	check(recovered.values.nickname == "榕城茶客" and recovered.values.muted,
		"valid neighboring settings survive corruption")
	write_bytes(config_path, "{ unfinished".to_utf8_buffer())
	check(preferences.new(path).values.rounds == 15, "an unparseable config can be opened safely")
	DirAccess.remove_absolute(config_path)
	check(prefs.update({"rounds": 9}) == OK, "a config can be recreated")
	DirAccess.rename_absolute(config_path, config_path + ".previous")
	check(preferences.new(path).values.rounds == 9, "restart recovers the previous config after interrupted replacement")


func test_table_library(preferences: Script, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var source := path.path_join("original.JPG")
	var image := Image.create_empty(30, 48, false, Image.FORMAT_RGB8)
	image.fill(Color.DARK_CYAN)
	var original := image.save_jpg_to_buffer()
	write_bytes(source, original)
	var prefs = preferences.new(path)
	var result: Dictionary = prefs.read_table_image(source)
	check(result.has("image"), "JPEG contents with an uppercase extension can be previewed")
	if not result.has("image"):
		return
	check(prefs.values.table_id == "" and prefs.list_tables().is_empty(), "preview alone does not save")
	check(prefs.apply_appearance({"skin": "guobiao"}, result.image, "../茶桌.png.JPG") == OK,
		"applying imports a copy and updates the appearance")
	DirAccess.remove_absolute(source)
	prefs = preferences.new(path)
	var table_id: String = prefs.values.table_id
	var tables: Array[Dictionary] = prefs.list_tables()
	check(tables.size() == 1 and tables[0].id == table_id and tables[0].name == "茶桌.png", "table metadata survives restart")
	var texture: Texture2D = prefs.table_texture(table_id)
	check(texture != null and texture.get_size() == Vector2(30, 48), "the table still loads after the original is deleted")
	var table_path := path.path_join("tables").path_join(table_id + ".jpg")
	check(FileAccess.get_file_as_bytes(table_path) == original, "the stored copy preserves the original bytes")
	check(prefs.remove_table(table_id) == OK, "the selected table can be deleted")
	prefs = preferences.new(path)
	check(prefs.values.table_id == "" and prefs.list_tables().is_empty() and not FileAccess.file_exists(table_path),
		"deleting the selected table persists the built-in table and removes the copy")
	check(prefs.apply_appearance({}, image, "portrait") == OK, "a decoded image can be applied")
	var old_id: String = prefs.values.table_id
	check(prefs.apply_appearance({}, image, "replacement", [old_id]) == OK, "staged deletion and import apply together")
	check(prefs.list_tables().size() == 1 and prefs.values.table_id != old_id and prefs.table_texture(old_id) == null,
		"the staged replacement selects the new table and removes the old table")
	table_path = path.path_join("tables").path_join(prefs.values.table_id + ".png")
	DirAccess.remove_absolute(table_path)
	prefs = preferences.new(path)
	check(prefs.values.table_id == "" and prefs.values.skin == "guobiao", "a missing copy falls back only for the table")


func test_invalid_images(preferences: Script, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var prefs = preferences.new(path)
	var tiny := Image.create_empty(3, 6, false, Image.FORMAT_RGB8)
	write_bytes(path.path_join("disguised.png"), tiny.save_jpg_to_buffer())
	check(prefs.read_table_image(path.path_join("disguised.png")).has("message"), "extension must agree with the image bytes")
	write_bytes(path.path_join("disguised.gif"), tiny.save_png_to_buffer())
	check(prefs.read_table_image(path.path_join("disguised.gif")).has("message"), "unsupported extensions are rejected")
	write_bytes(path.path_join("broken.png"), PackedByteArray([0x89, 0x50, 0x4e, 0x47]))
	check(prefs.read_table_image(path.path_join("broken.png")).has("message"), "a truncated PNG returns an explanation")
	var jpeg := tiny.save_jpg_to_buffer()
	write_bytes(path.path_join("broken.jpg"), jpeg.slice(0, jpeg.size() - 2))
	check(prefs.read_table_image(path.path_join("broken.jpg")).has("message"), "a JPEG missing its end marker is rejected")
	var wide := Image.create_empty(4097, 2, false, Image.FORMAT_RGB8)
	for format in ["png", "jpg"]:
		var file_path := path.path_join("wide." + format)
		write_bytes(file_path, wide.save_png_to_buffer() if format == "png" else wide.save_jpg_to_buffer())
		check(str(prefs.read_table_image(file_path).get("message", "")).contains("4096"), "image dimensions are limited for " + format)
	var oversized := FileAccess.open(path.path_join("large.png"), FileAccess.WRITE)
	oversized.resize(16 * 1024 * 1024 + 1)
	oversized.close()
	check(str(prefs.read_table_image(path.path_join("large.png")).get("message", "")).contains("16 MiB"), "input file length is limited")
	check(prefs.apply_appearance({"skin": "guobiao"}, wide, "wide") != OK and prefs.values.skin == "riichi",
		"invalid imports leave the current skin and table intact")


func test_failed_save(preferences: Script, path: String) -> void:
	var prefs = preferences.new(path)
	check(prefs.update({"nickname": "保留我"}) == OK, "initial settings save")
	var table_dir := path.path_join("tables")
	write_bytes(table_dir, "blocked table directory".to_utf8_buffer())
	var image := Image.create_empty(20, 20, false, Image.FORMAT_RGB8)
	check(prefs.apply_appearance({"nickname": "被拒绝"}, image, "blocked") != OK, "copy failure is reported")
	check(prefs.values.nickname == "保留我" and preferences.new(path).values.nickname == "保留我",
		"copy failure keeps the in-memory and saved configuration")
	DirAccess.remove_absolute(table_dir)
	var config_path := path.path_join("preferences.json")
	DirAccess.rename_absolute(config_path, config_path + ".test_backup")
	DirAccess.make_dir_absolute(config_path)
	check(prefs.apply_appearance({"nickname": "被拒绝"}, image, "blocked") != OK, "commit failure is reported")
	check(DirAccess.get_files_at(table_dir).is_empty(), "commit failure cleans up a newly created copy")
	check(prefs.values.nickname == "保留我" and prefs.list_tables().is_empty(), "commit failure keeps the prior state")


func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func clean(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for child: String in dir.get_directories():
		clean(path.path_join(child))
	for file: String in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)
