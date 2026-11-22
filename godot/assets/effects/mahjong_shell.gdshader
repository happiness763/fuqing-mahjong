shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform vec2 canvas_size;
uniform vec4 face;
uniform vec2 extrusion;
uniform vec2 shadow_offset;
uniform vec4 ivory : source_color;
uniform vec4 resin : source_color;
uniform bool face_down = false;
uniform bool highlighted = false;

float rounded_box(vec2 delta, vec2 half_size, float radius) {
	vec2 corner = abs(delta) - half_size + vec2(radius);
	return length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
}

// Short extrusion between two rounded faces in the direction of the table projection.
float shell(vec2 point, vec2 half_size, float radius, vec2 shift) {
	float distance = rounded_box(point, half_size, radius);
	for (int sample_index = 1; sample_index <= 5; sample_index++) {
		distance = min(distance, rounded_box(point - shift * (float(sample_index) / 5.0), half_size, radius));
	}
	return distance;
}

void layer(inout vec4 paint, vec3 color, float alpha) {
	paint = vec4(color, 1.0) * alpha + paint * (1.0 - alpha);
}

void fragment() {
	vec2 half_size = face.zw * 0.5;
	vec2 point = UV * canvas_size - vec2(7.0) - face.xy - half_size;
	float radius = min(5.0, min(face.z, face.w) * 0.19);
	float d = rounded_box(point, half_size, radius);
	float aa = max(0.38, fwidth(d) * 0.56);
	vec4 paint = vec4(0.0);
	float shadow = shell(point - shadow_offset, half_size, radius + 0.8, extrusion);
	layer(paint, vec3(0.012, 0.030, 0.020), 0.42 * (1.0 - smoothstep(-2.0, 5.0, shadow)));
	layer(paint, vec3(0.014, 0.021, 0.011), 0.40 * (1.0 - smoothstep(-0.6, 2.6, shadow)));

	float outer = shell(point, half_size, radius, extrusion);
	float core = shell(point, half_size, radius, extrusion * 0.76);
	float mid = shell(point, half_size, radius, extrusion * 0.36);
	float along = clamp(dot(point, normalize(extrusion)) / length(half_size) * 0.5 + 0.5, 0.0, 1.0);
	vec3 edge = resin.rgb * (0.90 - 0.28 * along) + 0.13 * exp(-abs(outer + 1.2));
	layer(paint, edge, 1.0 - smoothstep(-aa, aa, outer));
	vec3 body = ivory.rgb * (0.86 - 0.18 * along);
	body += 0.10 * exp(-abs(mid)) + 0.06 * exp(-abs(core + 1.2));
	layer(paint, face_down ? resin.rgb * (0.86 - 0.30 * along) : body,
		1.0 - smoothstep(-aa, aa, core));

	vec2 edge_normal = sign(point) * max(abs(point) - half_size + vec2(radius), vec2(0.0));
	edge_normal /= max(length(edge_normal), 0.001);
	float key = dot(edge_normal, vec2(-0.58, -0.81));
	float bevel = exp(-abs(d + 1.15) * 0.79);
	vec2 uv = point / half_size;
	vec2 light = (uv + vec2(0.48, 0.77)) * vec2(0.64, 1.48);
	float wash = exp(-dot(light, light));
	vec3 tint = face_down ? resin.rgb : ivory.rgb;
	vec3 surface = tint * (0.95 + 0.06 * wash - 0.058 * uv.y);
	surface = mix(surface, surface * (0.91 + 0.14 * key) + vec3(0.09) * max(key, 0.0), bevel);
	if (highlighted) {
		float rim = 1.0 - smoothstep(0.35, 1.6, abs(d + 0.65));
		surface = mix(surface, vec3(0.99, 0.75, 0.34), rim * 0.93);
	}
	layer(paint, surface, 1.0 - smoothstep(-aa, aa, d));
	COLOR = paint * COLOR.a;
}
