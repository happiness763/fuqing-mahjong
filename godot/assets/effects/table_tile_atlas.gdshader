shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D markings : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 cell_scale;
varying flat vec2 cell_origin;

void vertex() {
	cell_origin = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec4 ink = texture(markings, cell_origin + UV * cell_scale);
	ALBEDO = ink.rgb;
	ALPHA = ink.a;
}
