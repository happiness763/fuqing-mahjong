extends RefCounted

const VERSION := 1
const MAX_IMAGE_BYTES := 16 * 1024 * 1024
const MAX_IMAGE_EDGE := 4096
const DEFAULTS := {
	"nickname": "", "rounds": 25, "difficulty": "normal", "luck": "normal",
	"host_port": 36712, "room_rounds": 25, "turn_seconds": 60, "muted": false,
	"skin": "riichi", "table_id": "", "interaction_effects": true, "fullscreen": false,
	"effects": "full",
}
const JPEG_FRAME_MARKERS := [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]

var values: Dictionary:
	get:
		return _values

var _values := DEFAULTS.duplicate()
var _tables: Dictionary = {}
var _root: String
var _config_path: String
var _table_dir: String
var _cached_id := ""
var _cached_texture: Texture2D


func _init(root_dir: String = "user://") -> void:
	_root = ProjectSettings.globalize_path(root_dir)
	_config_path = _root.path_join("preferences.json")
	_table_dir = _root.path_join("tables")
	_load()


func update(changes: Dictionary) -> Error:
	return apply_appearance(changes)


func list_tables() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _tables:
		result.append({"id": id, "name": _tables[id].name})
	return result


func table_texture(id: String) -> Texture2D:
	if not _tables.has(id):
		return null
	if id == _cached_id:
		return _cached_texture
	var image: Image = _read_table_image(_table_path(id, _tables[id].extension), false).get("image")
	if image == null:
		return null
	_cached_id = id
	_cached_texture = ImageTexture.create_from_image(image)
	return _cached_texture


func read_table_image(path: String) -> Dictionary:
	return _read_table_image(path, true)


func apply_appearance(changes: Dictionary, image: Image = null, image_name: String = "", remove_ids: Array = []) -> Error:
	var next_values := _values.duplicate()
	for key: Variant in changes:
		if not DEFAULTS.has(key):
			return ERR_INVALID_PARAMETER
		var value: Variant = _validated_value(key, changes[key])
		if value == null:
			return ERR_INVALID_PARAMETER
		next_values[key] = value
	var next_tables := _tables.duplicate()
	for id: Variant in remove_ids:
		if not _tables.has(id):
			return ERR_DOES_NOT_EXIST
		next_tables.erase(id)
		if next_values.table_id == id:
			next_values.table_id = ""
	var image_path := ""
	if image != null:
		if image.is_empty() or maxi(image.get_width(), image.get_height()) > MAX_IMAGE_EDGE:
			return ERR_INVALID_DATA
		var extension: String = image.get_meta("table_extension", "png")
		var bytes: PackedByteArray = image.get_meta("table_source", PackedByteArray())
		if bytes.is_empty():
			bytes = image.save_png_to_buffer()
			extension = "png"
		if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES or _image_size(bytes, extension) != image.get_size():
			return ERR_INVALID_DATA
		var error := DirAccess.make_dir_recursive_absolute(_table_dir)
		if error != OK:
			return error
		var id := _new_id()
		image_path = _table_path(id, extension)
		error = _write_new_file(image_path, bytes)
		if error != OK:
			return error
		next_tables[id] = {"name": _display_name(image_name), "extension": extension}
		next_values.table_id = id
	elif next_values.table_id != "" and next_values.table_id != _values.table_id:
		if table_texture(next_values.table_id) == null:
			return ERR_INVALID_DATA
	if next_values == _values and next_tables == _tables:
		return OK
	var error := _save(next_values, next_tables)
	if error != OK:
		if not image_path.is_empty():
			DirAccess.remove_absolute(image_path)
		return error
	for id: String in remove_ids:
		var old_path := _table_path(id, _tables[id].extension)
		if FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(old_path)
		if _cached_id == id:
			_cached_id = ""
			_cached_texture = null
	_values = next_values
	_values.make_read_only()
	_tables = next_tables
	if image != null:
		_cached_id = _values.table_id
		_cached_texture = ImageTexture.create_from_image(image)
	return OK


func remove_table(id: String) -> Error:
	return apply_appearance({}, null, "", [id])


func _load() -> void:
	var config := _load_config(_config_path)
	if config.is_empty():
		config = _load_config(_config_path + ".previous")
	var saved: Variant = config.get("values")
	var saved_tables: Variant = config.get("tables")
	if saved_tables is Dictionary:
		for id: Variant in saved_tables:
			var entry: Variant = saved_tables[id]
			if not _valid_id(id) or not (entry is Dictionary):
				continue
			var extension: Variant = entry.get("extension")
			var name: Variant = entry.get("name")
			if extension in ["png", "jpg"] and name is String and FileAccess.file_exists(_table_path(id, extension)):
				_tables[id] = {"name": _clean_name(name), "extension": extension}
	if saved is Dictionary:
		for key: String in DEFAULTS:
			var value: Variant = _validated_value(key, saved.get(key))
			if value != null:
				_values[key] = value
	if _values.table_id != "" and table_texture(_values.table_id) == null:
		_values.table_id = ""
	_values.make_read_only()


func _load_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if not (json.data is Dictionary) or json.data.get("version") != VERSION:
		return {}
	return json.data


func _validated_value(key: String, value: Variant) -> Variant:
	match key:
		"nickname":
			if value is String:
				var trimmed: String = value.strip_edges()
				if trimmed.length() > 12:
					return null
				for index in range(trimmed.length()):
					var character := trimmed.unicode_at(index)
					if character < 32 or character in [127, 8232, 8233]:
						return null
				return trimmed
		"rounds", "room_rounds":
			return _integer_in_range(value, 1, 32)
		"host_port":
			return _integer_in_range(value, 1, 65535)
		"turn_seconds":
			var seconds: Variant = _integer_in_range(value, 0, 60)
			return seconds if seconds in [0, 15, 30, 60] else null
		"difficulty":
			return value if value in ["easy", "normal", "hard"] else null
		"luck":
			return value if value in ["unlucky", "normal", "lucky"] else null
		"skin":
			return value if value in ["riichi", "guobiao"] else null
		"table_id":
			return value if value == "" or _valid_id(value) else null
		"muted", "interaction_effects", "fullscreen":
			return value if value is bool else null
		"effects":
			return value if value in ["full", "simple", "off"] else null
	return null


func _integer_in_range(value: Variant, minimum: int, maximum: int) -> Variant:
	if not (value is int or value is float) or not (value >= minimum and value <= maximum):
		return null
	return int(value) if value == int(value) else null


func _valid_id(value: Variant) -> bool:
	if not (value is String) or value.length() != 32:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _display_name(raw_name: String) -> String:
	var name := raw_name.replace("\\", "/").get_file().strip_edges()
	if name.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
		name = name.get_basename().strip_edges()
	return _clean_name(name)


func _clean_name(raw_name: String) -> String:
	var name := raw_name.replace("\n", " ").replace("\r", " ").strip_edges().left(80)
	return name if not name.is_empty() else "自定义牌桌"


func _table_path(id: String, extension: String) -> String:
	return _table_dir.path_join(id + "." + extension)


func _save(next_values: Dictionary, next_tables: Dictionary) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(_root)
	if error != OK:
		return error
	if DirAccess.dir_exists_absolute(_config_path):
		return ERR_FILE_CANT_WRITE
	var bytes := JSON.stringify({"version": VERSION, "values": next_values, "tables": next_tables}, "\t", false).to_utf8_buffer()
	var pending := _config_path + "." + _new_id() + ".tmp"
	error = _write_new_file(pending, bytes)
	if error != OK:
		return error
	# Windows DirAccess removes the destination before replacing it. Keep the
	# previous file recoverable until the new file has been moved into place.
	var previous := _config_path + ".previous"
	if FileAccess.file_exists(_config_path):
		if FileAccess.file_exists(previous) and _load_config(_config_path).is_empty() and not _load_config(previous).is_empty():
			error = DirAccess.remove_absolute(_config_path)
		else:
			error = DirAccess.rename_absolute(_config_path, previous)
	if error == OK:
		error = DirAccess.rename_absolute(pending, _config_path)
	if error != OK:
		if not FileAccess.file_exists(_config_path) and FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, _config_path)
		DirAccess.remove_absolute(pending)
		return error
	if FileAccess.file_exists(previous):
		DirAccess.remove_absolute(previous)
	return OK


func _write_new_file(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if written and error == OK and FileAccess.get_file_as_bytes(path) == bytes:
		return OK
	DirAccess.remove_absolute(path)
	return ERR_FILE_CANT_WRITE


func _read_table_image(path: String, keep_source: bool) -> Dictionary:
	var extension := path.get_extension().to_lower()
	if extension not in ["png", "jpg", "jpeg"]:
		return {"message": "请选择 PNG 或 JPEG 图片。"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"message": "无法读取图片，请检查文件是否存在以及是否可访问。"}
	var length := file.get_length()
	if length > MAX_IMAGE_BYTES:
		return {"message": "图片文件不能超过 16 MiB。"}
	var bytes := file.get_buffer(length)
	var format := "png" if extension == "png" else "jpg"
	var size := _image_size(bytes, format)
	if size.x <= 0 or size.y <= 0:
		return {"message": "图片已损坏、扩展名与内容不符，或并非静态 PNG/JPEG 图片。"}
	if maxi(size.x, size.y) > MAX_IMAGE_EDGE:
		return {"message": "图片最长边不能超过 4096 像素。"}
	var image := Image.new()
	var error := image.load_png_from_buffer(bytes) if format == "png" else image.load_jpg_from_buffer(bytes)
	if error != OK or image.is_empty() or image.get_size() != size:
		return {"message": "图片已损坏，无法预览。"}
	if keep_source:
		image.set_meta("table_source", bytes)
		image.set_meta("table_extension", format)
	return {"image": image}


func _image_size(bytes: PackedByteArray, format: String) -> Vector2i:
	if format == "png":
		return _png_size(bytes)
	if format == "jpg":
		return _jpeg_size(bytes)
	return Vector2i.ZERO


func _png_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 33 or bytes.slice(0, 16).hex_encode() != "89504e470d0a1a0a0000000d49484452":
		return Vector2i.ZERO
	var width := _read_be32(bytes, 16)
	var height := _read_be32(bytes, 20)
	# Keep out-of-range uint32 dimensions positive when converting to Vector2i.
	var dimensions := Vector2i(mini(width, MAX_IMAGE_EDGE + 1), mini(height, MAX_IMAGE_EDGE + 1))
	if maxi(dimensions.x, dimensions.y) > MAX_IMAGE_EDGE:
		return dimensions
	var offset := 33
	var has_image_data := false
	while offset + 12 <= bytes.size():
		var length := _read_be32(bytes, offset)
		if offset + 12 + length > bytes.size():
			break
		var type := _read_be32(bytes, offset + 4)
		if type == 0x6163544c:  # acTL identifies an animated PNG.
			break
		if type == 0x49444154:  # IDAT contains the image data.
			has_image_data = true
		if type == 0x49454e44:  # IEND terminates the PNG.
			return dimensions if has_image_data and length == 0 and offset + 12 == bytes.size() else Vector2i.ZERO
		offset += length + 12
	return Vector2i.ZERO


func _jpeg_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 4 or bytes[0] != 0xff or bytes[1] != 0xd8:
		return Vector2i.ZERO
	if bytes[bytes.size() - 2] != 0xff or bytes[bytes.size() - 1] != 0xd9:
		return Vector2i.ZERO
	var offset := 2
	while offset < bytes.size() and bytes[offset] == 0xff:
		while offset < bytes.size() and bytes[offset] == 0xff:
			offset += 1
		if offset + 2 >= bytes.size():
			break
		var marker := bytes[offset]
		offset += 1
		if marker in [0x00, 0xd8, 0xd9, 0xda]:
			break
		var length := (bytes[offset] << 8) | bytes[offset + 1]
		if length < 2 or offset + length > bytes.size():
			break
		if marker in JPEG_FRAME_MARKERS and length >= 8:
			var height := (bytes[offset + 3] << 8) | bytes[offset + 4]
			var width := (bytes[offset + 5] << 8) | bytes[offset + 6]
			return Vector2i(width, height)
		offset += length
	return Vector2i.ZERO


func _read_be32(bytes: PackedByteArray, index: int) -> int:
	return (bytes[index] << 24) | (bytes[index + 1] << 16) | (bytes[index + 2] << 8) | bytes[index + 3]
