shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.35, 0.90, 1.0, 1.0);
uniform float seed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.55;

float glint(vec2 uv, vec2 center, float radius, float phase) {
	float distance_to_center = length(uv - center);
	float halo = 1.0 - smoothstep(radius * 0.12, radius, distance_to_center);
	float core = 1.0 - smoothstep(radius * 0.02, radius * 0.18, distance_to_center);
	float pulse = 0.55 + 0.45 * sin(TIME * 1.4 + phase + seed);
	return (halo * 0.55 + core * 0.45) * pulse;
}

void fragment() {
	vec2 uv = UV;
	float alpha = 0.0;
	vec2 first = vec2(0.24 + 0.10 * sin(TIME * 0.23 + seed),
		0.30 + 0.10 * cos(TIME * 0.31 + seed));
	vec2 second = vec2(0.67 + 0.09 * cos(TIME * 0.19 + seed * 1.7),
		0.53 + 0.12 * sin(TIME * 0.27 + seed * 0.8));
	vec2 third = vec2(0.48 + 0.12 * sin(TIME * 0.17 + seed * 2.1),
		0.78 + 0.08 * cos(TIME * 0.29 + seed * 1.3));
	alpha += glint(uv, first, 0.12, 0.0);
	alpha += glint(uv, second, 0.09, 2.1);
	alpha += glint(uv, third, 0.07, 4.4);
	COLOR = vec4(tint.rgb, alpha * tint.a * intensity);
}
