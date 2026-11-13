extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const NAMES := [
	"Man1", "Man2", "Man3", "Man4", "Man5", "Man6", "Man7", "Man8", "Man9",
	"Pin1", "Pin2", "Pin3", "Pin4", "Pin5", "Pin6", "Pin7", "Pin8", "Pin9",
	"Sou1", "Sou2", "Sou3", "Sou4", "Sou5", "Sou6", "Sou7", "Sou8", "Sou9",
	"Ton", "Nan", "Shaa", "Pei", "Chun", "Hatsu", "Haku", "Spring", "Summer", "Autumn",
	"Winter", "Plum", "Orchid", "Bamboo", "Chrysanthemum",
]


func _initialize() -> void:
	var catalog_path := "res://scripts/tile_skins.gd"
	if not ResourceLoader.exists(catalog_path):
		printerr("FAIL: tile skin catalog is missing")
		quit(1)
		return
	var catalog := load(catalog_path)
	var failures := 0
	for skin in ["riichi", "guobiao", "unknown"]:
		var faces: Array[Texture2D] = catalog.faces(skin)
		if faces.size() != Rules.TILE_TYPES or faces.size() != NAMES.size():
			printerr("FAIL: expected 42 tile faces for ", skin)
			failures += 1
			continue
		var folder := "guobiao/" if skin == "guobiao" else ""
		for index in range(NAMES.size()):
			var face := faces[index]
			var path := "res://assets/tiles/%s%s.svg" % [folder, NAMES[index]]
			if face == null or face.resource_path != path or not face.get_image().get_used_rect().has_area():
				printerr("FAIL: expected nonempty ", path, " for tile ", Rules.tile_name(index))
				failures += 1
	if failures == 0:
		print("v1.2.5 tile skin tests passed")
	quit(failures)
