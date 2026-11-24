extends Control

const Meshes = preload("res://scripts/table_meshes_3d.gd")
const Atlas = preload("res://scripts/table_tile_atlas.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const Rules = preload("res://scripts/rules.gd")

const DESIGN_SIZE := Vector2i(1280, 800)
const TILE_WIDTH := 0.72
const TILE_DEPTH := 0.96
const FACE_Y := 0.158
const BACK_Y := -0.1555
const FACE_INK_SIZE := Vector2(TILE_WIDTH, TILE_DEPTH) * 0.85
const CLOTH_SIZE := Vector2(21.92, 16.66)

# Fixed, long-focus camera from the approved study. The 1280×800 subviewport
# maintains its aspect during the outer Control's responsive, uniform scaling.
# Adapted from tableCameraPosition in the MIT-licensed lianhuaguangdongmahjong
# sceneRenderProfile.ts at 1f1be007.
const CAMERA_POSITION := Vector3(0.0, 22.3, 15.5)
const CAMERA_TARGET := Vector3(0.0, 0.0, 0.46)
const CAMERA_FOV := 36.9
const TABLE_BATCH_BOUNDS := AABB(Vector3(-17, -1, -16), Vector3(34, 10, 32))

enum Batch { IVORY, GOLD, RESIN, FACES, BACKS, CONTACTS, HIGHLIGHTS }

var _camera_transform := Transform3D(Basis.looking_at(CAMERA_TARGET - CAMERA_POSITION), CAMERA_POSITION)
var _view_transform := _camera_transform.affine_inverse()
var _focal_length := DESIGN_SIZE.y * 0.5 / tan(deg_to_rad(CAMERA_FOV * 0.5))

var _active := false
var _effects := "full"
var _render_scale := 1.0
var _cloth_texture: Texture2D
var _viewport: SubViewport
var _world: Node3D
var _main_light: DirectionalLight3D
var _image_cloth: MeshInstance3D
var _image_material: StandardMaterial3D
var _face_atlas: RefCounted
var _back_marks: StandardMaterial3D
var _back_index := -1
var _back_changed := false
var _batches: Array[TileBatch] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = Vector2(DESIGN_SIZE)
	hide()


func _ready() -> void:
	if _active:
		_ensure_scene()
		_request_render()


func set_board_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	visible = active
	if not active:
		if _viewport != null:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			for batch in _batches:
				batch.clear()
		return
	_ensure_scene()
	_request_render()


func set_appearance(cloth: Texture2D, effects: String) -> void:
	if cloth == _cloth_texture and effects == _effects:
		return
	_cloth_texture = cloth
	_effects = effects
	if _viewport != null:
		_apply_appearance()
		_update_viewport_size()
		_request_render()


func set_render_scale(scale_factor: float) -> void:
	var clamped := clampf(scale_factor, 1.0, 2.5)
	if is_equal_approx(clamped, _render_scale):
		return
	_render_scale = clamped
	if _viewport != null:
		_update_viewport_size()
		_request_render()


func target_viewport_size() -> Vector2i:
	var cap := 1.5 if (_effects == "off" or OS.get_name() == "Android") else 2.5
	var effective := clampf(_render_scale, 1.0, cap)
	return Vector2i((Vector2(DESIGN_SIZE) * effective).round())


func _update_viewport_size() -> void:
	if _viewport == null:
		return
	var target := target_viewport_size()
	if _viewport.size != target:
		_viewport.size = target


func begin_frame(back_index: int) -> void:
	for batch in _batches:
		batch.begin()
	if _viewport != null and _back_index != back_index:
		_back_index = back_index
		_back_marks.albedo_texture = Backs.texture_for(back_index)
		_back_changed = true


func add_tile(pose: Transform3D, number: int, face: Texture2D, gold: bool,
		highlighted := false, ground_shadow := true) -> void:
	if _batches.is_empty():
		return
	var face_down := number < 0
	_bodies(pose, gold, ground_shadow)
	if face_down:
		_backs(pose)
	elif face != null and number < Rules.TILE_TYPES:
		_face_atlas.set_face(number, face)
		var room_for_badge := gold and _projected_face_width(pose) >= 24.0
		var face_pose := pose.translated_local(Vector3(0, FACE_Y + 0.002, 0))
		if room_for_badge:
			face_pose = face_pose.translated_local(Vector3(0, 0, 0.065))
			face_pose.basis = face_pose.basis.scaled_local(Vector3(0.84, 1.0, 0.84))
			_badge(pose)
		_batches[Batch.FACES].add(face_pose, _face_atlas.instance_uv(number))
	if highlighted:
		_highlight(pose, face_down)


func add_wall_tile(pose: Transform3D, sea: bool, base_layer: bool) -> void:
	if _batches.is_empty():
		return
	_bodies(pose, false, base_layer)
	_backs(pose)
	if sea:
		_highlight(pose, true)


func finish_frame() -> void:
	if _viewport == null:
		return
	var changed := _back_changed
	_back_changed = false
	if _face_atlas.flush():
		changed = true
	for batch in _batches:
		if batch.flush():
			changed = true
	if changed:
		_request_render()


func project_point(point: Vector3) -> Vector2:
	# Same pinhole projection as a vertical-FOV Camera3D with KEEP_HEIGHT.
	# Used directly so input geometry also works with a headless display server.
	var view := _view_transform * point
	return Vector2(DESIGN_SIZE) * 0.5 + Vector2(view.x, -view.y) * (_focal_length / -view.z)


func project_rect(pose: Transform3D) -> Rect2:
	var bounds := Rect2(project_point(pose * Vector3(-TILE_WIDTH * 0.5, BACK_Y, -TILE_DEPTH * 0.5)),
		Vector2.ZERO)
	for x in [-TILE_WIDTH * 0.5, TILE_WIDTH * 0.5]:
		for y in [BACK_Y, FACE_Y]:
			for z in [-TILE_DEPTH * 0.5, TILE_DEPTH * 0.5]:
				bounds = bounds.expand(project_point(pose * Vector3(x, y, z)))
	return bounds


func project_face(pose: Transform3D, face_down := false) -> PackedVector2Array:
	var y := BACK_Y if face_down else FACE_Y
	var z := TILE_DEPTH * 0.5 if face_down else -TILE_DEPTH * 0.5
	var x := TILE_WIDTH * 0.5
	return PackedVector2Array([
		project_point(pose * Vector3(-x, y, z)), project_point(pose * Vector3(x, y, z)),
		project_point(pose * Vector3(x, y, -z)), project_point(pose * Vector3(-x, y, -z)),
	])


func _projected_face_width(pose: Transform3D) -> float:
	return project_point(pose * Vector3(-TILE_WIDTH * 0.5, FACE_Y, 0)).distance_to(
		project_point(pose * Vector3(TILE_WIDTH * 0.5, FACE_Y, 0)))


func _ensure_scene() -> void:
	if _viewport != null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.name = "TableViewport"
	_viewport.size = target_viewport_size()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var image := TextureRect.new()
	image.name = "ViewportImage"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.texture = _viewport.get_texture()
	add_child(image)

	_world = Node3D.new()
	_viewport.add_child(_world)
	_build_lighting()
	var camera := Camera3D.new()
	camera.name = "TableCamera"
	camera.transform = _camera_transform
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_world.add_child(camera)
	camera.make_current()
	_build_table()
	_build_tiles()
	_apply_appearance()


func _build_lighting() -> void:
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = Environment.new()
	atmosphere.environment.background_mode = Environment.BG_CLEAR_COLOR
	atmosphere.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color = Color("#e5eee7")
	atmosphere.environment.ambient_light_energy = 0.36
	_world.add_child(atmosphere)
	_main_light = DirectionalLight3D.new()
	_main_light.light_color = Color("#f3eee6")
	_main_light.light_energy = 0.42
	_main_light.light_specular = 0.24
	_main_light.rotation_degrees = Vector3(-58, -36, 0)
	_main_light.shadow_opacity = 0.64
	_main_light.shadow_blur = 1.85
	_main_light.directional_shadow_max_distance = 49.0
	_world.add_child(_main_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.4, 8.0, 0.2)
	fill.omni_range = 19.0
	fill.omni_attenuation = 0.88
	fill.light_color = Color("#eee9dd")
	fill.light_energy = 0.16
	fill.light_specular = 0.14
	_world.add_child(fill)


# Layered foot, steps, edge trim and playing surface follow the structure of
# createStaticTableScene from MIT-licensed lianhuaguangdongmahjong, 1f1be007.
func _build_table() -> void:
	var wood := _material(Color("#55311e"), 0.49)
	wood.albedo_texture = Meshes.grain(true)
	var border := _material(Color("#573720"), 0.51)
	var warm := _material(Color("#856337"), 0.38)
	var cloth := _material(Color("#1d503c"), 0.98)
	cloth.albedo_texture = Meshes.grain(false)
	_slab(Meshes.rounded_slab(23.10, 0.83, 17.83, 0.42, 0.13), wood, -0.68)
	_slab(Meshes.rounded_slab(22.98, 0.23, 17.68, 0.37, 0.055), border, -0.30)
	_slab(Meshes.rounded_slab(22.76, 0.34, 17.46, 0.31, 0.047), wood, -0.184)
	_slab(Meshes.rounded_slab(22.09, 0.14, 16.83, 0.28, 0.035), warm, -0.075)
	var felt := Meshes.rounded_slab(CLOTH_SIZE.x, 0.12, CLOTH_SIZE.y, 0.24, 0.03)
	_slab(felt, cloth, -0.059)
	# Keep felt grain showing through transparent pixels in imported cloth.
	_image_material = _material(Color.WHITE, 0.98)
	_image_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_image_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_image_material.texture_repeat = false
	_image_material.render_priority = -5
	_image_cloth = _slab(felt, _image_material, -0.057)
	_image_cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _slab(mesh: Mesh, material: Material, height: float) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	slab.mesh = mesh
	slab.material_override = material
	slab.position = Vector3(0, height, 0.12)
	_world.add_child(slab)
	return slab


func _build_tiles() -> void:
	var shell := Meshes.rounded_slab(TILE_WIDTH, 0.22, TILE_DEPTH, 0.075, 0.035)
	var resin := Meshes.rounded_slab(TILE_WIDTH, 0.095, TILE_DEPTH, 0.075, 0.022)
	_face_atlas = Atlas.new()
	_back_marks = _decal(null, Color("#c9ad74"))
	var shadow := _decal(Meshes.shadow_texture(), Color("#06180fd9"))
	shadow.render_priority = -2
	var highlight := _material(Color("#ffd568"), 0.84)
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_batches = [
		TileBatch.new(_world, shell, _material(Color("#c5c1b8"), 0.65), true),
		TileBatch.new(_world, shell, _material(Color("#ccb484"), 0.62), true),
		TileBatch.new(_world, resin, _material(Color("#315742"), 0.59), true),
		TileBatch.new(_world, Meshes.plane(FACE_INK_SIZE), _face_atlas.material, false, true),
		TileBatch.new(_world, Meshes.plane(Vector2(0.30, 0.43)), _back_marks, false),
		TileBatch.new(_world, Meshes.plane(Vector2(TILE_WIDTH + 0.34, TILE_DEPTH + 0.40)), shadow, false),
		TileBatch.new(_world, Meshes.rim(TILE_WIDTH, TILE_DEPTH, 0.075, 0.038, 0.033), highlight, false),
	]


func _apply_appearance() -> void:
	_main_light.shadow_enabled = _effects == "full"
	_batches[Batch.CONTACTS].node.visible = _effects != "off"
	_image_cloth.visible = _cloth_texture != null
	_image_material.albedo_texture = _cloth_texture
	if _cloth_texture != null:
		var image_size := _cloth_texture.get_size()
		var cover := maxf(CLOTH_SIZE.x / image_size.x, CLOTH_SIZE.y / image_size.y)
		var crop := CLOTH_SIZE / cover / image_size
		_image_material.uv1_scale = Vector3(crop.x, crop.y, 1.0)
		_image_material.uv1_offset = Vector3((1.0 - crop.x) * 0.5, (1.0 - crop.y) * 0.5, 0.0)


func _request_render() -> void:
	if _active and _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _bodies(pose: Transform3D, gold: bool, ground_shadow: bool) -> void:
	_batches[Batch.GOLD if gold else Batch.IVORY].add(pose.translated_local(Vector3(0.0, 0.048, 0.0)))
	_batches[Batch.RESIN].add(pose.translated_local(Vector3(0.0, -0.108, 0.0)))
	if ground_shadow:
		var ground := Vector3(pose.origin.x + 0.045, 0.009, pose.origin.z - 0.025)
		var right := Vector3(pose.basis.x.x, 0.0, pose.basis.x.z).normalized()
		if right.is_zero_approx():
			right = Vector3.RIGHT
		var back := right.cross(Vector3.UP)
		var depth := lerpf(0.82, 1.0, absf(pose.basis.z.normalized().dot(back)))
		var footprint := Basis(right * pose.basis.x.length(), Vector3.UP,
			back * pose.basis.z.length() * depth)
		_batches[Batch.CONTACTS].add(Transform3D(footprint, ground))


func _backs(pose: Transform3D) -> void:
	var cap := Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, BACK_Y - 0.004, 0.0))
	_batches[Batch.BACKS].add(pose * cap)


func _badge(pose: Transform3D) -> void:
	var badge := pose.translated_local(Vector3(0.22, FACE_Y + 0.003, -0.34))
	badge.basis = badge.basis.scaled_local(Vector3(0.25, 1.0, 0.23))
	_batches[Batch.FACES].add(badge, _face_atlas.instance_uv(Atlas.GOLD_BADGE))


func _highlight(pose: Transform3D, face_down: bool) -> void:
	var y := BACK_Y - 0.006 if face_down else FACE_Y + 0.006
	_batches[Batch.HIGHLIGHTS].add(pose.translated_local(Vector3(0.0, y, 0.0)))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _decal(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var material := _material(color, 1.0)
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


# Reuse each instance stream and its buffer across snapshots. The shared caps,
# atlas offsets and contact-shadow stream adapt createTileInstanceRenderer from
# MIT-licensed lianhuaguangdongmahjong tileInstanceRenderer.ts, 1f1be007.
class TileBatch extends RefCounted:
	var node := MultiMeshInstance3D.new()
	var _mesh := MultiMesh.new()
	var _poses: Array[Transform3D] = []
	var _ink := PackedColorArray()
	var _presented_poses: Array[Transform3D] = []
	var _presented_ink := PackedColorArray()

	func _init(world: Node3D, geometry: Mesh, material: Material, cast_shadows: bool,
			use_custom_data := false) -> void:
		_mesh.transform_format = MultiMesh.TRANSFORM_3D
		_mesh.use_custom_data = use_custom_data
		_mesh.mesh = geometry
		_mesh.custom_aabb = TABLE_BATCH_BOUNDS
		node.multimesh = _mesh
		node.material_override = material
		if not cast_shadows:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)

	func begin() -> void:
		_poses = []
		_ink = PackedColorArray()

	func clear() -> void:
		begin()
		flush()

	func add(pose: Transform3D, ink := Color.TRANSPARENT) -> void:
		_poses.append(pose)
		if _mesh.use_custom_data:
			_ink.append(ink)

	func flush() -> bool:
		if _poses == _presented_poses and _ink == _presented_ink:
			return false
		var count := _poses.size()
		if count > _mesh.instance_count:
			_mesh.instance_count = maxi(16, nearest_po2(count))
		for index in range(count):
			_mesh.set_instance_transform(index, _poses[index])
			if _mesh.use_custom_data:
				_mesh.set_instance_custom_data(index, _ink[index])
		_mesh.visible_instance_count = count
		_presented_poses = _poses
		_presented_ink = _ink
		return true
