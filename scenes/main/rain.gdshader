shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

float hash1(float x) {
	return fract(sin(x) * 43758.5453);
}

// One O(1) rain layer: grid of columns (not loops over drops).
// Returns an alpha contribution 0..1.
float rain_layer(vec2 uv, float density, float slant, float speed_base,
		float speed_var, float len_base, float len_var, float width_frac,
		float alpha, float seed) {
	vec2 p = vec2(uv.x - uv.y * slant, uv.y);
	float cell = 1.0 / density;
	float remainder = mod(p.x, cell);
	float cell_x = p.x - remainder;
	float rn = hash1(cell_x * density + seed);
	float speed = speed_base + speed_var * rn;
	float length = len_base + len_var * rn;
	float y = fract(p.y + rn);
	float trail = smoothstep(1.0 - length, 1.0, fract(y - TIME * speed));
	float thickness = step(remainder * density, width_frac);
	return trail * thickness * alpha;
}

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	a += rain_layer(uv, 140.0, 0.05, 2.2, 0.8, 0.08, 0.04, 0.15, 0.10, 1.0);  // near
	a += rain_layer(uv, 220.0, 0.045, 1.4, 0.8, 0.055, 0.03, 0.10, 0.06, 7.0); // mid
	a += rain_layer(uv, 320.0, 0.04, 0.8, 0.8, 0.035, 0.02, 0.06, 0.035, 13.0); // far
	COLOR = vec4(0.706, 0.863, 1.0, a * intensity);
}
