extends RefCounted


static func rounded_slab(width: float, height: float, depth: float, corner: float, bevel: float) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [
		Vector2(-height * 0.5, bevel), Vector2(-height * 0.5 + bevel, 0.0),
		Vector2(height * 0.5 - bevel, 0.0), Vector2(height * 0.5, bevel),
	]
	var rings: Array[PackedVector3Array] = []
	for level: Vector2 in levels:
		rings.append(_rounded_ring(width, depth, corner, level.y, level.x))
	for index in range(rings[0].size()):
		var next := (index + 1) % rings[0].size()
		for layer in range(rings.size() - 1):
			var a := rings[layer][index]
			var b := rings[layer][next]
			var c := rings[layer + 1][next]
			var d := rings[layer + 1][index]
			_triangle(surface, a, b, c, width, depth)
			_triangle(surface, a, c, d, width, depth)
		_triangle(surface, Vector3(0, height * 0.5, 0), rings[3][index], rings[3][next], width, depth)
		_triangle(surface, Vector3(0, -height * 0.5, 0), rings[0][next], rings[0][index], width, depth)
	surface.index()
	return surface.commit()


static func rim(width: float, depth: float, corner: float, inset: float, stroke: float) -> Mesh:
	var outer := _rounded_ring(width, depth, corner, inset, 0.0)
	var inner := _rounded_ring(width, depth, corner, inset + stroke, 0.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(outer.size()):
		var next := (index + 1) % outer.size()
		_triangle(surface, outer[index], outer[next], inner[index], width, depth)
		_triangle(surface, inner[index], outer[next], inner[next], width, depth)
	return surface.commit()


static func _rounded_ring(width: float, depth: float, corner: float, inset: float,
		height: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for quadrant in range(4):
		var quadrant_mid := Vector2.from_angle((quadrant + 0.5) * PI / 2)
		var center := Vector2(signf(quadrant_mid.x) * (width * 0.5 - corner),
			signf(quadrant_mid.y) * (depth * 0.5 - corner))
		for point in range(5):
			var vertex := center + Vector2.from_angle((quadrant * 4 + point) * PI / 8) * (corner - inset)
			points.append(Vector3(vertex.x, height, vertex.y))
	return points


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		width: float, depth: float) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c]:
		surface.set_uv(Vector2(vertex.x / width + 0.5, vertex.z / depth + 0.5))
		surface.set_normal(normal)
		surface.add_vertex(vertex)


static func plane(dimensions: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	return mesh


static func grain(is_wood: bool) -> ImageTexture:
	var dimension := 256
	var random := RandomNumberGenerator.new()
	random.seed = 39 if is_wood else 331
	var noise := FastNoiseLite.new()
	noise.seed = random.seed
	noise.frequency = 0.041
	var image := Image.create_empty(dimension, dimension, false, Image.FORMAT_RGB8)
	for y in range(dimension):
		for x in range(dimension):
			var fiber := random.randf_range(0.91, 1.0)
			var texel := 0.962 + (fiber - 0.955) * 0.66 + noise.get_noise_2d(x * 2, y * 2) * 0.026
			if is_wood:
				var slow := noise.get_noise_2d(x * 0.30, y * 0.28)
				var grain_shift := 4.0 * slow + 1.2 * noise.get_noise_2d(x * 0.36, y * 0.56)
				var stripe := sin(y * 1.28 + grain_shift)
				var fine := sin(y * 2.54 + 1.7 * grain_shift)
				texel = 0.84 + stripe * 0.045 + fine * 0.027 + (fiber - 0.95) * 0.2
			image.set_pixel(x, y, Color(texel, texel, texel))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# The soft rectangular footprint follows makeContactShadowTexture from the
# MIT-licensed lianhuaguangdongmahjong tileInstanceRenderer.ts, 1f1be007.
static func shadow_texture() -> ImageTexture:
	var dimension := 64
	var image := Image.create_empty(dimension, dimension, false, Image.FORMAT_RGBA8)
	for y in range(dimension):
		for x in range(dimension):
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / dimension * 2.0 - Vector2.ONE
			var edge := pow(pow(absf(uv.x), 4.0) + pow(absf(uv.y), 4.0), 0.25)
			var opacity := 0.46 * (1.0 - smoothstep(0.36, 1.0, edge))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, opacity))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
