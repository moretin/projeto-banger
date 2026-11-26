shader_type canvas_item;

uniform vec3 sunset_tint : source_color = vec3(1.04, 0.94, 0.84);
uniform float sunset_strength : hint_range(0.0, 1.0) = 0.28;
uniform vec3 ground_color : source_color = vec3(0.68, 0.43, 0.25);
uniform float ground_blend_height : hint_range(0.0, 0.25) = 0.09;
uniform float ground_blend_strength : hint_range(0.0, 1.0) = 0.42;
uniform float recolor_ice_to_amber : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 region_uv_y = vec2(0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	float alpha = tex.a;

	if (recolor_ice_to_amber > 0.5) {
		float cold = clamp((tex.b - tex.r) * 2.4 + max(tex.g - tex.r, 0.0) * 0.9, 0.0, 1.0);
		float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
		vec3 warm_stone = mix(vec3(0.24, 0.15, 0.13), vec3(0.76, 0.46, 0.24), clamp(lum * 1.25, 0.0, 1.0));
		vec3 glowing_amber = mix(vec3(0.95, 0.54, 0.14), vec3(1.0, 0.88, 0.42), clamp((lum - 0.50) * 2.2, 0.0, 1.0));
		vec3 recolored = mix(warm_stone, glowing_amber, smoothstep(0.42, 0.78, lum));
		rgb = mix(rgb, recolored, cold);
	}

	rgb = mix(rgb, rgb * sunset_tint, sunset_strength);

	float span_y = max(region_uv_y.y - region_uv_y.x, 0.001);
	float local_v = clamp((UV.y - region_uv_y.x) / span_y, 0.0, 1.0);
	float base_start = 1.0 - ground_blend_height;
	if (ground_blend_height > 0.001 && local_v > base_start) {
		float t = clamp((local_v - base_start) / ground_blend_height, 0.0, 1.0);
		rgb = mix(rgb, ground_color, t * ground_blend_strength);
	}
	if (local_v > 0.975) {
		float feather = clamp((1.0 - local_v) / 0.025, 0.0, 1.0);
		alpha *= mix(0.65, 1.0, feather);
	}

	rgb = mix(rgb, vec3(1.0, 0.92, 0.68), hit_flash * 0.55);
	COLOR = vec4(rgb, alpha) * COLOR;
}
