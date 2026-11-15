extends Control

const OpeningIntro = preload("res://scripts/opening_intro.gd")
const DURATION := OpeningIntro.DICE_DURATION_MS / 1000.0
const DISPLAY_SIZE := Vector2(136, 116)
const BEVEL := 0.095
const CORE := 0.5 - BEVEL
const GRID := [-0.5, -0.48, -0.453, -0.426, -CORE, CORE, 0.426, 0.453, 0.48, 0.5]
const FACE_NORMALS := [Vector3.UP, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.DOWN]
const PIPS := [
	[Vector2.ZERO],
	[Vector2(-1, -1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
]
const SPIN_AXES := [Vector3(0.82, 0.31, 0.48), Vector3(-0.48, 0.38, 0.78)]
const LANDINGS := [Vector2(-0.62, 0.04), Vector2(0.63, -0.13)]
const YAW := [-0.16, 0.18]

var _viewport: SubViewport
var _camera: Camera3D
var _models: Array[Node3D] = []
var _poses: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _shadows: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _heights: Array[float] = [0.0, 0.0]
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = DISPLAY_SIZE
	hide()
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(DISPLAY_SIZE * 2.0)
	_viewport.transparent_bg = true
	_viewport.gui_disable_input = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = DISPLAY_SIZE
	add_child(display)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#efe7d7")
	world.environment.ambient_light_energy = 0.74
	_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -32, 0)
	key.light_color = Color("#fff5df")
	key.light_energy = 0.68
	_viewport.add_child(key)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = DISPLAY_SIZE.x / 35.0
	_camera.position = Vector3(0, 6.7, 3.4)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0, 0.40, 0))
	_camera.make_current()

	var body := _body_mesh()
	var pips := _pip_mesh()
	for index in range(2):
		var model := Node3D.new()
		for mesh in [body, pips]:
			var piece := MeshInstance3D.new()
			piece.mesh = mesh
			model.add_child(piece)
		_viewport.add_child(model)
		_models.append(model)


func set_faces(faces: Vector2i) -> void:
	cancel_roll()
	visible = faces.x in range(1, 7) and faces.y in range(1, 7)
	if not visible:
		return
	for index in range(2):
		_put_die(index, LANDINGS[index], _face_up(faces[index], index), 0.0)
	_redraw_dice()


func roll_to(faces: Vector2i, on_landed: Callable) -> void:
	if not visible:
		set_faces(Vector2i(1, 2))
	cancel_roll()
	var starts := _poses.duplicate()
	_tween = create_tween()
	_tween.tween_method(_throw_frame.bind(faces, starts), 0.0, 1.0, DURATION)
	_tween.tween_callback(func():
		_tween = null
		if on_landed.is_valid():
			on_landed.call())


func cancel_roll() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _throw_frame(progress: float, faces: Vector2i, starts: Array) -> void:
	for index in range(2):
		var spin: Vector3 = SPIN_AXES[index]
		var align_start := 0.59 + index * 0.045
		var rotation_progress := minf(progress / align_start, 1.0)
		var angle := TAU * (1.65 + index * 0.34) * (1.0 - pow(1.0 - rotation_progress, 1.72))
		var orientation := Quaternion(spin.normalized(), angle) * Quaternion(starts[index])
		var settling := smoothstep(align_start, 0.93, progress)
		orientation = orientation.slerp(_face_up(faces[index], index), settling).normalized()
		var arc_end := 0.44 + index * 0.058
		var rebound_end := 0.67 + index * 0.04
		var lift := _bounce(progress, 0.0, arc_end) * (0.61 - index * 0.13)
		lift += _bounce(progress, arc_end, rebound_end) * 0.15
		lift += _bounce(progress, rebound_end, 0.85) * 0.043
		var landing: Vector2 = LANDINGS[index]
		var side := signf(landing.x)
		var outward := sin(PI * smoothstep(0.0, 0.91, progress)) * side * 0.27
		var forward := _bounce(progress, 0.0, 0.84) * (-0.07 if index == 0 else -0.44)
		_put_die(index, landing + Vector2(outward, forward), orientation, lift)
	_redraw_dice()


func _put_die(index: int, floor_position: Vector2, orientation: Quaternion, lift: float) -> void:
	_poses[index] = orientation
	if _camera == null:
		return
	var basis := Basis(orientation)
	var support := CORE * (absf(basis.x.y) + absf(basis.y.y) + absf(basis.z.y)) + BEVEL
	var floor_point := Vector3(floor_position.x, 0, floor_position.y)
	_models[index].transform = Transform3D(basis, floor_point + Vector3.UP * (support + lift))
	_shadows[index] = _camera.unproject_position(floor_point + Vector3(0.045, 0, 0.075) * (1.0 + lift * 2.0)) * 0.5
	_heights[index] = lift


func _redraw_dice() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		queue_redraw()


func _draw() -> void:
	if _camera == null:
		return
	for index in range(2):
		var lift := _heights[index]
		var radius := 18.5 + lift * 9.0
		draw_set_transform(_shadows[index], 0.0, Vector2(1, 0.73))
		for ring in range(4):
			draw_circle(Vector2.ZERO, radius + float(3 - ring) * 2.0,
				Color(0.015, 0.065, 0.040, lerpf(0.19, 0.045, lift)), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)


static func _bounce(progress: float, start: float, stop: float) -> float:
	var t := clampf(inverse_lerp(start, stop, progress), 0.0, 1.0)
	return 4.0 * t * (1.0 - t)


static func _face_up(face: int, index: int) -> Quaternion:
	var normal: Vector3 = FACE_NORMALS[face - 1]
	var turn := Quaternion(Vector3.RIGHT, PI) if normal == Vector3.DOWN else Quaternion(normal, Vector3.UP)
	return (Quaternion(Vector3.UP, YAW[index]) * turn).normalized()


static func _body_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#e9dec8")
	material.roughness = 0.64
	surface.set_material(material)
	for direction in FACE_NORMALS:
		var normal: Vector3 = direction
		var u := Vector3.FORWARD if absf(normal.x) > 0.5 else Vector3.RIGHT
		var v := normal.cross(u)
		for row in range(GRID.size() - 1):
			for column in range(GRID.size() - 1):
				var a: Vector3 = normal * 0.5 + u * GRID[column] + v * GRID[row]
				var b: Vector3 = normal * 0.5 + u * GRID[column + 1] + v * GRID[row]
				var c: Vector3 = normal * 0.5 + u * GRID[column + 1] + v * GRID[row + 1]
				var d: Vector3 = normal * 0.5 + u * GRID[column] + v * GRID[row + 1]
				for point: Vector3 in [a, c, b, a, d, c]:
					var core := point.clamp(Vector3.ONE * -CORE, Vector3.ONE * CORE)
					var rounded := (point - core).normalized()
					surface.set_normal(rounded)
					surface.add_vertex(core + rounded * BEVEL)
	return surface.commit()


static func _pip_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	surface.set_material(material)
	for face in range(6):
		var normal: Vector3 = FACE_NORMALS[face]
		var u := Vector3.FORWARD if absf(normal.x) > 0.5 else Vector3.RIGHT
		var v := normal.cross(u)
		var ink := Color("#a02d28") if face in [0, 3] else Color("#202820")
		var radius := 0.144 if face == 0 else 0.081
		var colors := [Color("#b4a58d"), ink.darkened(0.17), ink.lightened(0.065)]
		for offset: Vector2 in PIPS[face]:
			var center := normal * 0.5015 + 0.237 * (offset.x * u + offset.y * v)
			for segment in range(20):
				var angle := TAU * float(segment) / 20.0
				var next_angle := angle + TAU / 20.0
				var a := u * cos(angle) + v * sin(angle)
				var b := u * cos(next_angle) + v * sin(next_angle)
				for part in [[a * radius, 0], [b * radius * 0.79, 1], [b * radius, 0],
						[a * radius, 0], [a * radius * 0.79, 1], [b * radius * 0.79, 1],
						[Vector3.ZERO, 2], [b * radius * 0.79, 1], [a * radius * 0.79, 1]]:
					var shade := int(part[1])
					surface.set_color(colors[shade])
					surface.set_normal(normal)
					surface.add_vertex(center + Vector3(part[0]))
	return surface.commit()
