shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float hash1(float value) {
	return fract(sin(value) * 43758.5453);
}

float rain_band(vec2 uv, float density, float speed, float length_base,
		float length_variation, float width, float alpha, float seed) {
	vec2 slanted_uv = vec2(uv.x - uv.y * 0.045, uv.y);
	float column = floor(slanted_uv.x * density);
	float variation = hash1(column + seed);
	float speed_value = speed * mix(0.8, 1.2, variation);
	float streak_length = length_base + length_variation * variation;
	float phase = fract(slanted_uv.y + variation);
	float streak = smoothstep(1.0 - streak_length, 1.0,
		fract(phase - TIME * speed_value));
	float column_position = fract(slanted_uv.x * density);
	float stripe = 1.0 - step(width, abs(column_position - 0.5));
	return streak * stripe * alpha;
}

float rounded_box_sdf(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 uv = UV;
	float alpha = 0.0;
	alpha += rain_band(uv, 150.0, 1.15, 0.070, 0.025, 0.050, 0.10, 1.0);
	alpha += rain_band(uv, 225.0, 0.72, 0.035, 0.018, 0.030, 0.06, 7.0);
	alpha += rain_band(uv, 90.0, 0.42, 0.110, 0.050, 0.075, 0.045, 13.0);
	float window_sdf = rounded_box_sdf(uv - vec2(0.5), vec2(0.475), 0.060);
	float window_mask = 1.0 - smoothstep(0.0, 0.015, window_sdf);
	COLOR = vec4(0.706, 0.863, 1.0, min(alpha * intensity * 3.0, 0.30) * window_mask);
}
