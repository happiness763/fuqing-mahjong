extends RefCounted

const AtlasShader = preload("res://assets/effects/table_tile_atlas.gdshader")
const Rules = preload("res://scripts/rules.gd")
const GOLD_BADGE := Rules.TILE_TYPES
const INK_SIZE := Vector2i(240, 320)
const PADDING := Vector2i(8, 8)
const CELL_SIZE := INK_SIZE + PADDING * 2
const COLUMNS := 8
const ROWS := 6
const ATLAS_SIZE := CELL_SIZE * Vector2i(COLUMNS, ROWS)

var material := ShaderMaterial.new()

var _source: Dictionary[int, Texture2D] = {}
var _image := Image.create_empty(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
var _texture: ImageTexture
var _changed := true


func _init() -> void:
	material.shader = AtlasShader
	material.set_shader_parameter("cell_scale", Vector2(INK_SIZE) / Vector2(ATLAS_SIZE))
	var badge := Image.new()
	badge.load_svg_from_string("""
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 48 48">
<rect x="2" y="2" width="44" height="44" rx="8" fill="#7f4c22" stroke="#d4a65f" stroke-width="3"/>
<path d="M8 22 Q17 17 24 9 Q31 17 40 22 M15 22 H33 M12 28 H36 M24 22 V38 M16 31 L20 36 M32 31 L28 36 M11 38 H37"
 fill="none" stroke="#fff0c0" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
""")
	_write(GOLD_BADGE, badge)


func set_face(tile: int, source: Texture2D) -> void:
	if _source.get(tile) == source:
		return
	var pixels := source.get_image()
	if pixels == null or pixels.is_empty():
		return
	if pixels.is_compressed() and pixels.decompress() != OK:
		return
	_source[tile] = source
	_write(tile, pixels)


func instance_uv(tile: int) -> Color:
	var uv := Vector2(_cell_origin(tile)) / Vector2(ATLAS_SIZE)
	return Color(uv.x, uv.y, 0.0, 0.0)


func flush() -> bool:
	if not _changed:
		return false
	_image.generate_mipmaps()
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
		material.set_shader_parameter("markings", _texture)
	else:
		_texture.update(_image)
	_changed = false
	return true


func _write(tile: int, pixels: Image) -> void:
	var fit := minf(float(INK_SIZE.x) / pixels.get_width(), float(INK_SIZE.y) / pixels.get_height())
	var artwork_size := Vector2i((Vector2(pixels.get_size()) * fit).round()).max(Vector2i.ONE)
	var centered := Vector2i((Vector2(INK_SIZE - artwork_size) / 2.0).floor())
	pixels.clear_mipmaps()
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.resize(artwork_size.x, artwork_size.y, Image.INTERPOLATE_LANCZOS)
	var origin := _cell_origin(tile)
	_image.clear_mipmaps()
	_image.fill_rect(Rect2i(origin, INK_SIZE), Color.TRANSPARENT)
	_image.blit_rect(pixels, Rect2i(Vector2i.ZERO, artwork_size), origin + centered)
	_changed = true


func _cell_origin(tile: int) -> Vector2i:
	return Vector2i(tile % COLUMNS, floori(float(tile) / COLUMNS)) * CELL_SIZE + PADDING
