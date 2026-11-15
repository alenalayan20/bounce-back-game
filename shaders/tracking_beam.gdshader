shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 beam_color : source_color = vec4(0.18, 0.60, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 0.5) = 0.085;

void fragment() {
	// Broad feathering makes the light look like haze rather than a solid cone.
	float across = UV.x * 2.0 - 1.0;
	float feather = exp(-across * across * 4.5)
		* (1.0 - smoothstep(0.72, 1.0, abs(across)));
	float end_fade = 1.0 - smoothstep(0.50, 1.0, UV.y);
	float source_fade = smoothstep(0.0, 0.08, UV.y);
	float alpha = intensity * feather * end_fade * source_fade;
	COLOR = vec4(beam_color.rgb, alpha);
}
