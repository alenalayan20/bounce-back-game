shader_type canvas_item;

// Small local movements keep the hand-painted background intact.
uniform float door_scale : hint_range(1.0, 1.3) = 1.15;
uniform float chain_sway_pixels : hint_range(0.0, 12.0) = 8.5;
uniform float chain_speed : hint_range(0.1, 1.0) = 0.7;

varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

float strip_mask(vec2 p, vec4 bounds) {
	float horizontal = smoothstep(bounds.x, bounds.x + 4.0, p.x)
		* (1.0 - smoothstep(bounds.z - 4.0, bounds.z, p.x));
	float vertical = smoothstep(bounds.y, bounds.y + 3.0, p.y)
		* (1.0 - smoothstep(bounds.w - 5.0, bounds.w, p.y));
	return horizontal * vertical;
}

void fragment() {
	vec2 size = vec2(1280.0, 720.0);
	vec2 p = UV * size;
	vec2 source = p;

	// The links are painted into the image. A narrow UV bend moves them
	// in a visible, slow arc, anchored to the overhead pipe.
	float long_chain = strip_mask(p, vec4(1078.0, 69.0, 1124.0, 282.0));
	float short_chain = strip_mask(p, vec4(1125.0, 69.0, 1167.0, 242.0));
	float long_weight = pow(clamp((p.y - 72.0) / 200.0, 0.0, 1.0), 1.3);
	float short_weight = pow(clamp((p.y - 72.0) / 163.0, 0.0, 1.0), 1.3);
	source.x -= long_chain * long_weight * sin(TIME * chain_speed) * chain_sway_pixels;
	source.x -= short_chain * short_weight * sin(TIME * chain_speed * 0.83 + 1.7) * chain_sway_pixels * 0.8;

	// Magnify the existing door around its feet. A feathered border blends
	// into the wall, so the door is not doubled and the floor never moves.
	float door_mask = smoothstep(1137.0, 1148.0, p.x)
		* (1.0 - smoothstep(1225.0, 1236.0, p.x))
		* smoothstep(445.0, 460.0, p.y)
		* (1.0 - smoothstep(585.0, 588.0, p.y));
	vec2 door_source = vec2(1186.0, 588.0) + (p - vec2(1186.0, 588.0)) / door_scale;
	source = mix(source, door_source, door_mask);
	COLOR = texture(TEXTURE, source / size) * item_modulate;
}
