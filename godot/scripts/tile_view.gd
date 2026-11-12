extends Button

const Art = preload("res://scripts/table_art.gd")
const Rules = preload("res://scripts/rules.gd")

var number := -1
var golden := false
var marked := false
var chosen := false
var texture: Texture2D
var face_font: Font
var hot := false


func setup(tile: int, dimensions: Vector2, face: Texture2D, font: Font, is_gold: bool,
		interactive: bool, selected: bool, highlighted: bool) -> void:
	number = tile
	texture = face
	face_font = font
	golden = is_gold
	chosen = selected
	marked = highlighted
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
	var depth := maxf(2.0, size.y * 0.09)
	var surface := Rect2(Vector2.ZERO, size - Vector2(0, depth))
	var edge := Color("#ae9673")
	var ivory := Color("#fff7e6")
	if number < 0:
		edge = Color("#3c6250")
		ivory = Color("#7a9d77")
	elif golden:
		edge = Color("#b08039")
		ivory = Color("#ffe7a6")
	var active := hot or chosen or marked or has_focus()
	var rim := Color("#edc67a") if active else edge
	var radius := 5 if size.x >= 30 else 3
	draw_style_box(Art.box(Color(0.02, 0.08, 0.04, 0.45), Color.TRANSPARENT, radius, 0), Rect2(Vector2(1, 3), size))
	draw_style_box(Art.box(edge, rim, radius), Rect2(Vector2.ZERO, size))
	draw_style_box(Art.box(ivory, rim if active else ivory.darkened(0.15), radius, 2 if active else 1), surface)
	draw_line(Vector2(3, surface.end.y - 1), Vector2(size.x - 3, surface.end.y - 1), ivory.darkened(0.10), 1.0)
	if number < 0:
		if size.x >= 12:
			draw_style_box(Art.box(Color("#678a67"), Color("#a3b591"), 2), surface.grow(-2))
		return
	if texture:
		draw_texture_rect(texture, surface.grow(-maxf(1.0, size.x * 0.045)), false)
	if golden and size.x >= 26:
		var badge := 14.0 if size.x >= 40 else 11.0
		var badge_rect := Rect2(size.x - badge - 1, 1, badge, badge)
		draw_style_box(Art.box(Color("#8f5724"), Color("#d4a65f"), 3), badge_rect)
		draw_string(face_font, badge_rect.position + Vector2(1, badge - 2), "金", HORIZONTAL_ALIGNMENT_CENTER,
			badge - 2, int(badge - 2), Color("#fff0c0"))
