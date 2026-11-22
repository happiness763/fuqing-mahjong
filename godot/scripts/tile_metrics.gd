extends RefCounted

const RATIO := 0.75
const HAND_WIDTH := 56.0
const MELD_WIDTH := 24.0
const HAND_SIZE := Vector2(HAND_WIDTH, HAND_WIDTH / RATIO)
const MELD_SIZE := Vector2(MELD_WIDTH, MELD_WIDTH / RATIO)
const MELD_TILE_GAP := 1.0
const RIVER_COLUMNS := 6
const RIVER_GAP := 2.0
const RIVER_WIDTHS := [40.0, 34.0, 34.0, 34.0]
const RIVER_BASE_ROWS := [3, 4, 2, 4]


static func size_for(width: float) -> Vector2:
	return Vector2(width, width / RATIO)


static func at(position: Vector2, width: float) -> Rect2:
	return Rect2(position, size_for(width))


static func fit_art(texture_size: Vector2, area: Rect2) -> Rect2:
	var scale := minf(area.size.x / texture_size.x, area.size.y / texture_size.y)
	var dimensions := texture_size * scale
	return Rect2(area.get_center() - dimensions * 0.5, dimensions)


static func river_size(region: Rect2, seat: int, rows: int) -> Vector2:
	# Measure in seat-local axes. The same pitch works for every orientation.
	var available := region.size if seat % 2 == 0 else Vector2(region.size.y, region.size.x)
	var across := (available.x - (RIVER_COLUMNS - 1) * RIVER_GAP) / RIVER_COLUMNS
	var depth := (available.y - (rows - 1) * RIVER_GAP) / rows * RATIO
	return size_for(minf(RIVER_WIDTHS[seat], minf(across, depth)))
