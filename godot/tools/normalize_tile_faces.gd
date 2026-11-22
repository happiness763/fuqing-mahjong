extends SceneTree
## Run from Godot with --script res://tools/normalize_tile_faces.gd -- <output directory> [--apply].
## The contact sheets and the SVG measurement both use Godot's SVG renderer.

const Skins = preload("res://scripts/tile_skins.gd")
const CANVAS := Vector2(300, 400)
const MARKER := "<!-- normalized tile ink -->"
const FAMILIES := {
	"man": Vector2(246, 348), "pin": Vector2(249, 342),
	"sou": Vector2(246, 342), "honor": Vector2(244, 317),
	"flower": Vector2(244, 330),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Supply an absolute output directory.")
		quit(1)
		return
	var output: String = args[0]
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Cannot create output directory: ", output)
		quit(1)
		return
	var names: Array = []
	for suit in Skins.SUITS:
		for rank in range(1, 10):
			names.append("%s%d" % [suit, rank])
	names.append_array(Skins.HONORS_AND_FLOWERS)
	var updates := {}
	for skin in ["japanese", "guobiao"]:
		var directory: String = Skins.TILE_DIRECTORY + ("guobiao/" if skin == "guobiao" else "")
		var before := new_sheet()
		var after := new_sheet()
		for index in range(names.size()):
			var path: String = directory + names[index] + ".svg"
			var svg := FileAccess.get_file_as_string(path)
			var revised := normalize(svg, family_for(index))
			if revised.is_empty() or not add_face(before, svg, index) or not add_face(after, revised, index):
				printerr("Invalid SVG or empty face: ", path)
				quit(1)
				return
			updates[path] = revised
		if before.save_png(output.path_join(skin + "-before.png")) != OK or after.save_png(output.path_join(skin + "-after.png")) != OK:
			printerr("Cannot save contact sheets in ", output)
			quit(1)
			return
	if "--apply" in args:
		for path in updates:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				printerr("Cannot write: ", path)
				quit(1)
				return
			file.store_string(updates[path])
			file.close()
	print("Measured and verified 84 SVG faces with Godot. Sheets: ", output)
	quit()


func family_for(index: int) -> String:
	if index < 27:
		return ["man", "pin", "sou"][floori(float(index) / 9)]
	return "honor" if index < 34 else "flower"


func normalize(svg: String, family: String) -> String:
	if MARKER in svg:
		return svg
	var header_pattern := RegEx.create_from_string("<svg\\b[^>]*>")
	var coordinate_pattern := RegEx.create_from_string("viewBox=\"([^\"]+)\"")
	var header := header_pattern.search(svg)
	if header == null:
		return ""
	var view_box := coordinate_pattern.search(header.get_string())
	var close := svg.rfind("</svg>")
	if view_box == null or close < header.get_end():
		return ""
	var values := view_box.get_string(1).replace(",", " ").split_floats(" ", false)
	if values.size() != 4 or values[2] <= 0 or values[3] <= 0:
		return ""
	var source := Rect2(values[0], values[1], values[2], values[3])
	var body := svg.substr(header.get_end(), close - header.get_end())
	# Measure in the original coordinate system, without anisotropic stretching.
	var measure := root_header(source.size, source) + body + "</svg>"
	var rendered := Image.new()
	if rendered.load_svg_from_string(measure, 3.0) != OK:
		return ""
	var bounds := rendered.get_used_rect()
	if not bounds.has_area():
		return ""
	var pixel_scale := source.size / Vector2(rendered.get_size())
	var ink := Rect2(source.position + Vector2(bounds.position) * pixel_scale,
		Vector2(bounds.size) * pixel_scale)
	var target: Vector2 = FAMILIES[family]
	var scale := minf(target.x / ink.size.x, target.y / ink.size.y)
	var translation := CANVAS * 0.5 - ink.get_center() * scale
	var transform := 'translate(%.5f %.5f) scale(%.6f)' % [translation.x, translation.y, scale]
	return root_header(CANVAS, Rect2(Vector2.ZERO, CANVAS)) + "\n  " + MARKER + \
		'\n  <g transform="%s">%s  </g>\n</svg>\n' % [transform, body]


func root_header(dimensions: Vector2, view: Rect2) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%s" height="%s" viewBox="%s %s %s %s">' % [
		dimensions.x, dimensions.y, view.position.x, view.position.y, view.size.x, view.size.y]


func new_sheet() -> Image:
	var sheet := Image.create_empty(810, 500, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#1f3b32"))
	return sheet


func add_face(sheet: Image, svg: String, index: int) -> bool:
	var face := Image.new()
	if face.load_svg_from_string(svg) != OK or not face.get_used_rect().has_area():
		return false
	face.convert(Image.FORMAT_RGBA8)
	face.resize(60, 80, Image.INTERPOLATE_LANCZOS)
	var point := Vector2i((index % 9) * 90 + 15, (index / 9) * 100 + 10)
	sheet.fill_rect(Rect2i(point - Vector2i(3, 3), Vector2i(66, 86)), Color("#fff0d2"))
	sheet.blend_rect(face, Rect2i(Vector2i.ZERO, face.get_size()), point)
	return true
