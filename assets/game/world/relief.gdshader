shader_type canvas_item;
// Gentle terrain relief (user request after M7b): the land rises and dips a little in broad
// patches — a level up or down — with soft slopes about a tile wide, lit from the north. Only a
// few percent lighter or darker, so it is felt rather than seen; never on water.

uniform sampler2D relief : filter_linear, repeat_disable;
uniform sampler2D land : filter_nearest, repeat_disable;
// Noise thresholds of the lower and upper level, and the slopes' width (noise units).
uniform float low_edge = 0.38;
uniform float high_edge = 0.62;
uniform float slope = 0.018;
uniform float level_light = 0.035;
uniform float slope_light = 0.10;

float height_at(vec2 uv) {
	float n = texture(relief, uv).r;
	return smoothstep(high_edge - slope, high_edge + slope, n) - (1.0 - smoothstep(low_edge - slope, low_edge + slope, n));
}

void fragment() {
	float on_land = texture(land, UV).r;
	float h = height_at(UV);
	// Light from the north: a slope rising towards the south faces the light.
	float facing = -dFdy(h) * 8.0;
	float shade = h * level_light + clamp(facing, -1.0, 1.0) * slope_light;
	vec3 tone = shade > 0.0 ? vec3(1.0, 0.98, 0.9) : vec3(0.05, 0.04, 0.12);
	COLOR = vec4(tone, abs(shade) * on_land);
}
