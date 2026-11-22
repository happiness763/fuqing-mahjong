shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// The face and the foot share an elliptical section, offset vertically to
// expose the near side. Coordinates below are in the radius of that section.
uniform vec2 active_direction = vec2(0.0);
uniform float light_phase = 0.0;

float disc(float radius, float edge, float aa) {
	return 1.0 - smoothstep(edge - aa, edge + aa, radius);
}

void layer(inout vec4 out_color, vec3 pigment, float coverage) {
	out_color = vec4(pigment, 1.0) * coverage + out_color * (1.0 - coverage);
}

vec3 brass(vec2 normal) {
	float glint = pow(abs(dot(normal, vec2(0.74, -0.67))), 4.0);
	float warm_light = clamp(0.52 - normal.y * 0.38 + normal.x * 0.12, 0.0, 1.0);
	return mix(mix(vec3(0.32, 0.19, 0.08), vec3(0.90, 0.65, 0.31), warm_light),
			vec3(1.0, 0.90, 0.61), glint);
}

void fragment() {
	vec2 pixel = (UV - vec2(0.5)) * vec2(192.0, 174.0) + vec2(0.0, 5.0);
	vec2 radius = vec2(84.5, 66.0);
	vec2 p = pixel / radius;
	float r = length(p);
	vec2 normal = p / max(r, 0.001);
	float aa = max(fwidth(r) * 0.66, 0.004);
	float shadow = length((pixel - vec2(1.5, 9.0)) / (radius + vec2(1.5, 0.0)));
	vec4 paint = vec4(0.0);
	layer(paint, vec3(0.018, 0.043, 0.030), 0.63 * disc(shadow, 1.01, 0.075));

	float foot = length((pixel - vec2(0.0, 6.0)) / radius);
	vec3 side = mix(vec3(0.039, 0.076, 0.055), vec3(0.19, 0.25, 0.16),
			(0.5 + 0.5 * normal.x) * disc(foot, 0.98, 0.02));
	layer(paint, side, disc(foot, 1.0, aa));
	layer(paint, vec3(0.20, 0.16, 0.085), disc(r, 1.008, aa));
	vec3 metal = brass(normal);
	float bevel_light = 0.83 + 0.28 * sin((r - 0.964) * 79.0);
	layer(paint, metal * bevel_light, disc(r, 0.994, aa));
	layer(paint, vec3(0.084, 0.12, 0.077), disc(r, 0.958, aa));

	// Soft overhead reflection across the enamel. Shading along the
	// circumference and the blackened lip make the surface sit in the brass.
	float wash = exp(-dot((p + vec2(0.32, 0.64)) * vec2(0.85, 1.65),
			(p + vec2(0.32, 0.64)) * vec2(0.85, 1.65)));
	vec3 enamel = mix(vec3(0.072, 0.154, 0.116), vec3(0.215, 0.326, 0.237), wash);
	enamel *= 1.0 - 0.24 * smoothstep(0.84, 0.96, r);
	layer(paint, enamel, disc(r, 0.94, aa));

	// Diamond-shaped engraved dividers catch light on their lower-right lip.
	vec2 sector = abs(p) - vec2(0.50, 0.50);
	vec2 diagonal = vec2(sector.x + sector.y, sector.x - sector.y);
	float recess = abs(diagonal.x) / 0.236 + abs(diagonal.y) / 0.095;
	float inset = abs(diagonal.x + 0.012) / 0.217 + abs(diagonal.y) / 0.080;
	layer(paint, vec3(0.35, 0.43, 0.30), disc(recess, 1.0, aa * 10.0));
	layer(paint, vec3(0.045, 0.091, 0.067), disc(inset, 1.0, aa * 10.0));

	// Concave inner bowl with a polished edge and a dim reflected band
	// across its glass. All text is rendered by the Control at native size.
	float inner = length(pixel / vec2(36.8, 30.4));
	float inner_aa = aa * 2.3;
	layer(paint, mix(vec3(0.065, 0.095, 0.071), vec3(0.54, 0.62, 0.45),
			clamp(0.55 + normal.y * 0.54, 0.0, 1.0)), disc(inner, 1.05, inner_aa));
	vec3 glass = mix(vec3(0.032, 0.090, 0.075), vec3(0.089, 0.19, 0.145),
			clamp(0.68 - p.y * 0.8 - inner * inner * 0.53, 0.0, 1.0));
	layer(paint, glass, disc(inner, 0.982, inner_aa));

	float facing = dot(normal, active_direction);
	float slot = smoothstep(0.897, 0.916, facing);
	float near_rim = length((pixel - vec2(0.0, 0.8)) / radius);
	layer(paint, vec3(0.03, 0.18, 0.15), slot * disc(abs(near_rim - 0.97), 0.055, aa));
	float light = disc(abs(near_rim - 0.97), 0.034, aa);
	float shine = 1.0 - smoothstep(0.0, 0.038, abs(near_rim - 0.979));
	vec3 cyan = mix(vec3(0.01, 0.56, 0.49), vec3(0.62, 1.0, 0.87), shine * light_phase);
	layer(paint, cyan, slot * light);
	float spill = exp(-18.0 * abs(r - 0.941)) * pow(max(0.0, facing), 18.0) * disc(r, 0.94, aa);
	layer(paint, vec3(0.12, 0.85, 0.68), spill * 0.29 * light_phase);
	COLOR = paint;
}
