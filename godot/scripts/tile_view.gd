extends Button

const Art = preload("res://scripts/table_art.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const Rules = preload("res://scripts/rules.gd")
const Metrics = preload("res://scripts/tile_metrics.gd")
const SHELL = preload("res://assets/effects/mahjong_shell.gdshader")

var number := -1
var back_index := 0
var golden := false
var marked := false
var chosen := false
var texture: Texture2D
var face_font: Font
var hot := false
var upright := false
var hide_badge := false
var shell_layer: ColorRect
var shell_material: ShaderMaterial
var projected_face := PackedVector2Array()
var native_model_visible := false


func setup(tile: int, dimensions: Vector2, face: Texture2D, font: Font, is_gold: bool,
		interactive: bool, selected: bool, highlighted: bool, footprint := PackedVector2Array()) -> void:
	number = tile
	texture = face
	face_font = font
	golden = is_gold
	chosen = selected
	marked = highlighted
	projected_face = footprint
	native_model_visible = not footprint.is_empty()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = dimensions
	size = dimensions
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	tooltip_text = Rules.tile_name(tile) + (" · 金" if is_gold else "")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if not native_model_visible:
		_make_shell()
	if interactive:
		mouse_entered.connect(func(): hot = true; queue_redraw())
		mouse_exited.connect(func(): hot = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)


func _make_shell() -> void:
	shell_layer = ColorRect.new()
	shell_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_layer.show_behind_parent = true
	shell_layer.position = Vector2(-7, -7)
	shell_material = ShaderMaterial.new()
	shell_material.shader = SHELL
	shell_layer.material = shell_material
	add_child(shell_layer)


func show_native_model(value: bool) -> void:
	if native_model_visible == value:
		return
	native_model_visible = value
	if not value and not is_instance_valid(shell_layer):
		_make_shell()
	if is_instance_valid(shell_layer):
		shell_layer.visible = not value
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	if not projected_face.is_empty() and focus_mode != Control.FOCUS_NONE:
		return Geometry2D.is_point_in_polygon(point, projected_face)
	return Rect2(Vector2.ZERO, size).has_point(point)


func _draw() -> void:
	if native_model_visible or not is_instance_valid(shell_material):
		return
	var angle := get_global_transform().get_rotation()
	var down := Vector2.DOWN.rotated(-angle).snapped(Vector2.ONE)
	var depth := maxf(2.8, minf(size.x, size.y) * (0.145 if upright else 0.24))
	var extrusion := Vector2(-1.4, -depth) if upright else down * depth
	var surface := Rect2(-extrusion.min(Vector2.ZERO), size - extrusion.abs()).grow(-0.6)
	shell_layer.size = size + Vector2(15, 16)
	shell_material.set_shader_parameter("canvas_size", shell_layer.size)
	shell_material.set_shader_parameter("face", Vector4(surface.position.x, surface.position.y, surface.size.x, surface.size.y))
	shell_material.set_shader_parameter("extrusion", extrusion)
	shell_material.set_shader_parameter("shadow_offset", Vector2(1.3, 3.3).rotated(-angle))
	var small_gold := golden and size.x < 20.0
	var ivory_color := Color("#fff5dc") if (golden and hide_badge) else (
		Color("#ffcc6d") if small_gold else (Color("#ffe7b9") if golden else Color("#fff0d2")))
	shell_material.set_shader_parameter("ivory", ivory_color)
	shell_material.set_shader_parameter("resin", Color("#c0832e") if golden else Color("#698b50"))
	shell_material.set_shader_parameter("face_down", number < 0)
	shell_material.set_shader_parameter("highlighted", hot or chosen or marked or has_focus())
	if number < 0:
		Backs.draw_on(self, surface.grow(-2), back_index)
		return
	var badge := clampf(size.x * 0.20, 8.0, 16.0) if (golden and not small_gold and not hide_badge) else 0.0
	var print_area := surface.grow(-maxf(0.8, minf(surface.size.x, surface.size.y) * 0.04))
	var badge_rect := Rect2()
	if badge > 0.0:
		# The dedicated top band is kept clear of SVG ink on either skin.
		badge_rect = Rect2(print_area.end.x - badge, print_area.position.y, badge, badge)
		var band := badge + 0.8
		print_area.position.y += band
		print_area.size.y -= band
	if texture:
		draw_texture_rect(texture, Metrics.fit_art(texture.get_size(), print_area), false)
	if badge > 0.0:
		draw_style_box(Art.box(Color("#7f4c22"), Color("#d4a65f"), 2), badge_rect)
		draw_string(face_font, badge_rect.position + Vector2(1, badge - 2), "金", HORIZONTAL_ALIGNMENT_CENTER,
			badge - 2, int(badge - 2), Color("#fff0c0"))
