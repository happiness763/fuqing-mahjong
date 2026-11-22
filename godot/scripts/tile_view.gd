extends Button

const Art = preload("res://scripts/table_art.gd")
const Backs = preload("res://scripts/tile_backs.gd")
const Rules = preload("res://scripts/rules.gd")

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
	if interactive:
		mouse_entered.connect(func(): hot = true; queue_redraw())
		mouse_exited.connect(func(): hot = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)


func _draw() -> void:
	var depth := maxf(3.0, minf(size.x, size.y) * (0.11 if upright else 0.19))
	var down := Vector2.DOWN.rotated(-get_global_transform().get_rotation()).snapped(Vector2.ONE)
	# The exposed edge points toward the viewer even on a rotated table tile.
	var edge_offset := down * depth
	var surface := Rect2(-edge_offset.min(Vector2.ZERO), size - edge_offset.abs())
	if upright:
		surface.position.y += 3.0
		surface.size.y -= 3.0
	var traditional_face := guobiao_face and number >= 0 and not golden
	var edge := Color("#beaa81")
	var ivory := Color("#ffefd0")
	if number < 0:
		edge = Color("#3c6250")
		ivory = Color("#7a9d77")
	elif golden:
		edge = Color("#b08039")
		ivory = Color("#ffe7a6")
	elif traditional_face:
		edge = Color("#bca77e")
		ivory = Color("#fbebca")
	var face_border := ivory.darkened(0.16)
	var bevel := ivory.darkened(0.10)
	var active := hot or chosen or marked or has_focus()
	var rim := Color("#edc67a") if active else edge
	var radius := 5 if size.x >= 30 else 3
	draw_style_box(Art.box(Color(0.01, 0.055, 0.03, 0.54), Color.TRANSPARENT, radius, 0), Rect2(down * 3, size))
	draw_style_box(Art.box(Color("#527741"), Color("#294630"), radius), Rect2(Vector2.ZERO, size))
	var body := surface.merge(Rect2(surface.position + edge_offset * 0.73, surface.size))
	draw_style_box(Art.box(edge, rim, radius), body)
	draw_style_box(Art.box(ivory, rim if active else face_border, radius, 2 if active else 1), surface)
	draw_line(Vector2(surface.position.x + 4, surface.end.y - 1), Vector2(surface.end.x - 4, surface.end.y - 1), bevel, 1.0)
	if size.x >= 24:
		var top := surface.position + Vector2(radius + 1, 1.5)
		draw_line(top, Vector2(surface.end.x - radius - 1, top.y), Color("#fff9e6"), 1.0)
	if number < 0:
		if size.x >= 12:
			draw_style_box(Art.box(Color("#678a67"), Color("#a3b591"), 2), surface.grow(-2))
		Backs.draw_on(self, surface.grow(-2), back_index)
		return
	var badge := 0.0
	if golden and size.x >= 26:
		badge = 14.0 if size.x >= 40 else 11.0
	if texture:
		var face_rect := surface.grow(-maxf(1.0, size.x * 0.045))
		if guobiao_face and badge > 0.0 and face_rect.size.y > badge:
			# The unprinted top margin of the artwork shares space with the gold badge.
			var inset := maxf(0.0, badge - (4.0 if size.x >= 40 else 1.0) - face_rect.position.y)
			var ratio := (face_rect.size.y - inset) / face_rect.size.y
			face_rect.position += Vector2(face_rect.size.x * (1.0 - ratio) * 0.5, inset)
			face_rect.size *= ratio
		draw_texture_rect(texture, face_rect, false)
	if badge > 0.0:
		var badge_rect := Rect2(surface.end.x - badge - 1, surface.position.y + 1, badge, badge)
		draw_style_box(Art.box(Color("#8f5724"), Color("#d4a65f"), 3), badge_rect)
		draw_string(face_font, badge_rect.position + Vector2(1, badge - 2), "金", HORIZONTAL_ALIGNMENT_CENTER,
			badge - 2, int(badge - 2), Color("#fff0c0"))
