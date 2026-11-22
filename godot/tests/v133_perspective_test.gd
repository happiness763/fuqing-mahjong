extends SceneTree

const Wall = preload("res://scripts/table_wall.gd")
const Art = preload("res://scripts/table_art.gd")
var failures := 0


func _initialize() -> void:
	# Flattening a receding side wall or scaling only its upper layer breaks
	# the physical wall footprint used by every draw/replacement animation.
	var near := footprint(0)
	var far := footprint(2)
	check(near.size.x > far.size.x * 1.10, "near wall is visibly wider than the far wall")
	check(near.end.y < 691 and near.position.y > Art.RIVERS[0].end.y
		and far.end.y < Art.RIVERS[2].position.y,
		"horizontal walls leave the river and lower action band free")
	for side in [1, 3]:
		var first: int = side * 36
		var a := Wall.slot_rect(first + 1, 0)
		var b := Wall.slot_rect(first + 35, 0)
		var near_tile := a if a.get_center().y > b.get_center().y else b
		var far_tile := b if a.get_center().y > b.get_center().y else a
		check(absf(near_tile.get_center().x - 640) > absf(far_tile.get_center().x - 640) + 20,
			"side wall recedes toward the far table edge")
		check(near_tile.size.x > far_tile.size.x * 1.05,
			"side wall tile size changes gently with depth")
	for dealer in range(4):
		for slot in range(144):
			var rect := Wall.slot_rect(slot, dealer)
			check(rect.size.x > 10 and rect.size.y > 10 and Art.FELT.encloses(rect),
				"all physical wall slots remain visible on the felt")
			if slot % 2 == 0:
				var lower := Wall.slot_rect(slot + 1, dealer)
				check(rect.size.is_equal_approx(lower.size) and rect.intersects(lower),
					"upper and lower layers share their depth scale")
			check(rect == Wall.slot_rect(posmod(slot + dealer * 36, 144), 0),
				"view rotation keeps the original physical slot identifier")
	if failures == 0:
		print("Shallow perspective wall passed.")
	quit(failures)


func footprint(side: int) -> Rect2:
	var result := Wall.slot_rect(side * 36, 0)
	for slot in range(side * 36 + 1, side * 36 + 36):
		result = result.merge(Wall.slot_rect(slot, 0))
	return result


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
