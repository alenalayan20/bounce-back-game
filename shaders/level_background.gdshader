shader_type canvas_item;

// Small local movements keep the hand-painted background intact.
uniform float door_scale : hint_range(1.0, 1.3) = 1.15;
uniform float chain_sway_pixels : hint_range(0.0, 12.0) = 8.5;
uniform float chain_speed : hint_range(0.1, 1.0) = 0.7;
uniform vec4 long_chain_bounds = vec4(1078.0, 69.0, 1124.0, 282.0);
uniform vec4 short_chain_bounds = vec4(1125.0, 69.0, 1167.0, 242.0);
uniform bool hide_baked_saw = false;
// Slow warning-lamp brightness is supplied by door_warning_lights.gd. The
// mask follows source UVs, so the level-one door's enlarged lamp stays aligned.
uniform vec2 warning_lamp_centers[4];
uniform int warning_lamp_count = 0;
uniform vec2 warning_lamp_half_size = vec2(16.0, 5.0);
uniform float warning_lamp_glow_radius = 36.0;
uniform float warning_lamp_brightness : hint_range(0.0, 1.0) = 1.0;

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
	float long_chain = strip_mask(p, long_chain_bounds);
	float short_chain = strip_mask(p, short_chain_bounds);
	float long_weight = pow(clamp((p.y - long_chain_bounds.y - 3.0) / (long_chain_bounds.w - long_chain_bounds.y - 13.0), 0.0, 1.0), 1.3);
	float short_weight = pow(clamp((p.y - short_chain_bounds.y - 3.0) / (short_chain_bounds.w - short_chain_bounds.y - 13.0), 0.0, 1.0), 1.3);
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
	vec4 sampled = texture(TEXTURE, source / size);
	if (hide_baked_saw) {
		float saw_mask = smoothstep(820.0, 827.0, p.x)
			* (1.0 - smoothstep(889.0, 898.0, p.x))
			* smoothstep(486.0, 493.0, p.y)
			* (1.0 - step(524.0, p.y));
		// Replace only the stationary blade painted into level 3, preserving
		// the floor and yellow machine plate underneath the moving blade.
		vec4 clean_wall = texture(TEXTURE, vec2(p.x + 94.0, p.y) / size);
		sampled = mix(sampled, clean_wall, saw_mask);
	}
	float warning_mask = 0.0;
	for (int index = 0; index < 4; index++) {
		if (index < warning_lamp_count) {
			vec2 offset = source - warning_lamp_centers[index];
			// Color-select the existing painted emission. A wide soft edge
			// avoids a dim oval cutting across a still-bright glass strip.
			float lens = 1.0 - smoothstep(0.65, 1.65, length(offset / warning_lamp_half_size));
			float spill = 0.14 * exp(-4.0 * dot(offset / vec2(warning_lamp_glow_radius, warning_lamp_glow_radius * 0.65), offset / vec2(warning_lamp_glow_radius, warning_lamp_glow_radius * 0.65)));
			float warm_pixels = smoothstep(0.045, 0.24, sampled.r - sampled.b)
				* smoothstep(-0.015, 0.09, sampled.r - sampled.g);
			warning_mask = max(warning_mask, max(lens, spill) * warm_pixels);
		}
	}
	// Only color-selected warm emission changes. Retain a low reflected
	// base in the glass; also dim the pale amber filament evenly so it does
	// not turn gray as the red channels fade. Cool blue metal is unmasked.
	vec3 warm_emission = max(sampled.rgb - vec3(0.10), vec3(0.0));
	sampled.rgb -= warm_emission * ((1.0 - warning_lamp_brightness) * warning_mask);
	COLOR = sampled * item_modulate;
}
