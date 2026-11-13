extends SceneTree

const Desk = preload("res://table.tscn")
const Tile = preload("res://scripts/tile_view.gd")

var failures := 0
var output_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			output_dir = argument.trim_prefix("--qa-dir=")
	run.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func capture(filename: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir.path_join(filename)) == OK, "captured " + filename)


func run() -> void:
	var desk = Desk.instantiate()
	if not ("preferences_root" in desk):
		check(false, "desk exposes isolated preference path and supports settings")
		desk.free()
		quit(failures)
		return
	var folder := OS.get_temp_dir().path_join("fuqing-preferences-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "created test profile")
	desk.preferences_root = folder
	root.add_child(desk)
	var original: Texture2D = desk.faces[0]
	var filename := folder.path_join("桌布.png")
	var source := Image.create_empty(600, 300, false, Image.FORMAT_RGB8)
	source.fill(Color("#365868"))
	check(source.save_png(filename) == OK, "saved source image")
	desk.lobby.settings_button.pressed.emit()
	var settings = desk.settings_panel
	settings.nickname.text = "阿清"
	settings.skin.select(1)
	settings.refresh_preview()
	settings.select_image(filename)
	await capture("v125-preview.png")
	check(desk.faces[0] == original and desk.board_art.table_texture == null, "preview does not alter applied appearance")
	desk.close_modal()
	desk.lobby.settings_button.pressed.emit()
	settings = desk.settings_panel
	check(settings.skin.selected == 0 and settings.nickname.text.is_empty(), "cancel discards the draft")
	settings.nickname.text = "阿清"
	settings.skin.select(1)
	settings.select_image(filename)
	settings.apply()
	check(desk.faces.size() == 42 and desk.faces[0] != original and desk.board_art.table_texture != null,
		"applying swaps all face assets and installs the table")
	var selected_id: String = desk.preferences.values.table_id
	check(not selected_id.is_empty(), "table import has a persistent selection")
	check(DirAccess.remove_absolute(filename) == OK, "removed original desktop image")
	desk.lobby.change_input("24")
	desk.lobby.select("difficulty", "hard")
	desk.lobby.select("luck", "lucky")
	desk.lobby.change_input("33")
	desk.toggle_sound()
	desk.show_online()
	desk.exit_online()
	check(desk.lobby.round_field.text == "24", "returning from online preserves the latest solo choices")
	desk.queue_free()
	await process_frame
	desk = Desk.instantiate()
	desk.preferences_root = folder
	root.add_child(desk)
	check(desk.lobby.round_field.text == "24" and desk.lobby.selections.difficulty == "hard" and desk.lobby.selections.luck == "lucky",
		"last valid solo options restore even without starting")
	check(desk.muted and desk.board_art.table_texture != null and desk.faces[0] != original,
		"skin, sound and imported copy survive recreation")
	desk.begin_game(desk.lobby.selections)
	desk.finish_dealer_roll()
	desk.skip_intro()
	desk.show_settings()
	settings = desk.settings_panel
	var game = desk.game
	var board = desk.dynamic
	var revision: int = game.revision
	settings.skin.select(0)
	settings.apply()
	check(desk.game == game and game.revision == revision and desk.dynamic == board and desk.faces[0] == original,
		"switching skin retains the active game and board nodes")
	desk.show_lobby()
	desk.show_online()
	var screen = desk.online_lobby
	check(screen.entry_name.text == "阿清", "online lobby uses restored nickname")
	screen.settings_button.pressed.emit()
	settings = desk.settings_panel
	settings.remove_selected_table()
	desk.close_modal()
	check(desk.preferences.values.table_id == selected_id and desk.preferences.list_tables().size() == 1,
		"cancel leaves the imported table and its selection intact")
	screen.settings_button.pressed.emit()
	settings = desk.settings_panel
	settings.remove_selected_table()
	settings.apply()
	check(desk.preferences.values.table_id == "" and desk.board_art.table_texture == null, "confirmed deletion restores green felt")
	if failures == 0:
		print("v1.2.5 settings UI tests passed")
	desk.queue_free()
	await process_frame
	quit(failures)
