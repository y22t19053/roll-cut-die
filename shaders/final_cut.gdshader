shader_type canvas_item;
render_mode unshaded;

uniform float grain_phase = 0.0;
uniform float grain_contrast : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float slash_width_factor = 0.31;
uniform float edge_light : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_ink : source_color = vec4(0.27, 0.86, 0.92, 1.0);

varying vec4 tint;

float grain(vec2 point) {
	vec3 p = fract(vec3(point.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	float noise = grain(floor(FRAGCOORD.xy * 0.72) + grain_phase * 19.7);
	float matte = 1.0;
	if (dissolve > 0.0) {
		vec2 screen = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;
		float slash = abs(screen.x - 0.5 + (screen.y - 0.5) * 0.48);
		float resistance = slash * slash_width_factor + noise * 0.19;
		matte = smoothstep(dissolve - 0.07, dissolve, resistance);
	}

	vec4 texel = texture(TEXTURE, UV);
	float edge = 0.0;
	if (edge_light > 0.0) {
		vec2 pixel = TEXTURE_PIXEL_SIZE;
		float inside = min(
			min(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, pixel.y)).a, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a)
		);
		float at_border = step(min(UV.x, UV.y), max(pixel.x, pixel.y))
			+ step(1.0 - max(pixel.x, pixel.y), max(UV.x, UV.y));
		edge = clamp(texel.a - inside + at_border, 0.0, 1.0) * edge_light;
	}
	vec3 ink = mix(texel.rgb * tint.rgb, edge_ink.rgb, edge);
	float exposure = mix(1.0, mix(0.88, 1.08, noise), grain_contrast);
	COLOR = vec4(ink * exposure, texel.a * tint.a * matte);
}
