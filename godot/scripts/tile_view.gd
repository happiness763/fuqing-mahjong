extends Button

const Art = preload("res://scripts/table_art.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const Rules = preload("res://scripts/rules.gd")
const SHELL = preload("res://assets/effects/mahjong_shell.gdshader")

var number := -1
var back_index := 0
var golden := false
var marked := false
var chosen := false
var texture: Texture2D
var face_font: Font
var hot := false
var guobiao_face := false
var upright := false
var shell_layer: ColorRect
var shell_material: ShaderMaterial


func setup(tile: int, dimensions: Vector2, face: Texture2D, font: Font, is_gold: bool,
		interactive: bool, selected: bool, highlighted: bool, guobiao: bool = false) -> void:
	number = tile
	texture = face
	face_font = font
	golden = is_gold
	chosen = selected
	marked = highlighted
	guobiao_face = guobiao
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = dimensions
	size = dimensions
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	tooltip_text = Rules.tile_name(tile) + (" · 金" if is_gold else "")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	shell_layer = ColorRect.new()
	shell_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_layer.show_behind_parent = true
	shell_layer.position = Vector2(-7, -7)
	shell_material = ShaderMaterial.new()
	shell_material.shader = SHELL
	shell_layer.material = shell_material
	add_child(shell_layer)
	if interactive:
		mouse_entered.connect(func(): hot = true; queue_redraw())
		mouse_exited.connect(func(): hot = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)


func _draw() -> void:
	if not is_instance_valid(shell_material):
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
	shell_material.set_shader_parameter("ivory", Color("#ffe6ad") if golden else Color("#fff0d2"))
	shell_material.set_shader_parameter("resin", Color("#698b50"))
	shell_material.set_shader_parameter("face_down", number < 0)
	shell_material.set_shader_parameter("highlighted", hot or chosen or marked or has_focus())
	if number < 0:
		Backs.draw_on(self, surface.grow(-2), back_index)
		return
	var badge := 0.0
	if golden and size.x >= 26:
		badge = 14.0 if size.x >= 40 else 11.0
	if texture:
		var maximum := surface.size * (Vector2(0.94, 0.93) if upright else Vector2(0.91, 0.91))
		var original := texture.get_size()
		var art := original * minf(maximum.x / original.x, maximum.y / original.y)
		# Shallow far-side faces use mild foreshortening so their symbols
		# are still legible at small window sizes.
		if surface.size.x > surface.size.y:
			art.x = minf(maximum.x, art.x * 1.23)
		var face_rect := Rect2(surface.get_center() - art * 0.5, art)
		if guobiao_face and badge > 0.0 and face_rect.size.y > badge:
			# The unprinted top margin of the artwork shares space with the gold badge.
			var inset := maxf(0.0, badge - (4.0 if size.x >= 40 else 1.0) - (face_rect.position.y - surface.position.y))
			var ratio := (face_rect.size.y - inset) / face_rect.size.y
			face_rect.position += Vector2(face_rect.size.x * (1.0 - ratio) * 0.5, inset)
			face_rect.size *= ratio
		draw_texture_rect(texture, face_rect, false)
	if badge > 0.0:
		var badge_rect := Rect2(surface.end.x - badge - 1, surface.position.y + 1, badge, badge)
		draw_style_box(Art.box(Color("#8f5724"), Color("#d4a65f"), 3), badge_rect)
		draw_string(face_font, badge_rect.position + Vector2(1, badge - 2), "金", HORIZONTAL_ALIGNMENT_CENTER,
			badge - 2, int(badge - 2), Color("#fff0c0"))
