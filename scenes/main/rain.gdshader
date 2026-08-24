shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float cols = 90.0;
	float x = floor(UV.x * cols);
	float speed = 1.4 + hash(vec2(x, 1.0)) * 1.8;
	float y = fract(UV.y * 0.35 + TIME * speed + hash(vec2(x, 7.0)));
	float streak = smoothstep(0.0, 0.08, y) * smoothstep(0.35, 0.08, y);
	float gate = step(0.55, hash(vec2(x, 3.0)));
	COLOR = vec4(0.706, 0.863, 1.0, streak * gate * intensity * 0.35);
}
