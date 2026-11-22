extends RefCounted

const NAMES := ["pig", "cat", "rabbit", "bear", "chick", "dog"]
static var _textures: Array[Texture2D] = []


static func for_hand(hand_id: int) -> int:
	return posmod(maxi(1, hand_id) - 1, NAMES.size())


static func texture_for(index: int) -> Texture2D:
	if _textures.is_empty():
		for name in NAMES:
			_textures.append(load("res://assets/tile_backs/%s.svg" % name))
	return _textures[posmod(index, NAMES.size())]


static func draw_on(canvas: CanvasItem, area: Rect2, index: int, angle := 0.0,
		tint := Color.WHITE) -> void:
	var side := minf(area.size.x, area.size.y) * 0.83
	if side < 4.0:
		return
	canvas.draw_set_transform(area.get_center(), angle)
	canvas.draw_texture_rect(texture_for(index), Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)
