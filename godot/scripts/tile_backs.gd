extends RefCounted

const NAMES := ["pig", "cat", "rabbit", "bear", "chick", "dog"]
const Metrics = preload("res://scripts/tile_metrics.gd")
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
	var turned := absf(sin(angle)) > 0.5
	var face_size := Vector2(area.size.y, area.size.x) if turned else area.size
	var reserve := Rect2(-face_size * 0.44, face_size * 0.88)
	var plate := Metrics.fit_art(Metrics.size_for(1), reserve)
	var artwork := texture_for(index)
	var destination := Metrics.fit_art(artwork.get_size(), plate)
	if destination.size.x < 4.0:
		return
	canvas.draw_set_transform(area.get_center(), angle)
	canvas.draw_texture_rect(artwork, destination, false, tint)
	canvas.draw_set_transform(Vector2.ZERO)
