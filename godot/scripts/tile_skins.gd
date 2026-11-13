extends RefCounted

const TILE_DIRECTORY := "res://assets/tiles/"
const SUITS := ["Man", "Pin", "Sou"]
const HONORS_AND_FLOWERS := [
	"Ton", "Nan", "Shaa", "Pei", "Chun", "Hatsu", "Haku",
	"Spring", "Summer", "Autumn", "Winter", "Plum", "Orchid", "Bamboo", "Chrysanthemum",
]


static func faces(skin: String) -> Array[Texture2D]:
	var directory := TILE_DIRECTORY + ("guobiao/" if skin == "guobiao" else "")
	var result: Array[Texture2D] = []
	for suit in SUITS:
		for rank in range(1, 10):
			result.append(load("%s%s%d.svg" % [directory, suit, rank]))
	for name in HONORS_AND_FLOWERS:
		result.append(load("%s%s.svg" % [directory, name]))
	return result
