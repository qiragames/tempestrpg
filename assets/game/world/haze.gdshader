shader_type canvas_item;
// Drifting fog, mist or blowing sand over the screen around the character (weather).
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.9, 0.92, 0.95, 0.4);
uniform vec2 drift = vec2(0.012, 0.004);
// Where the haze rectangle sits in the world (in rectangle sizes), so the fog stays in place.
uniform vec2 origin = vec2(0.0);

void fragment() {
	vec2 uv = (UV + origin) * 2.5 + TIME * drift;
	float n = texture(noise, uv).r * 0.7 + texture(noise, uv * 2.1 - TIME * drift * 1.7).r * 0.3;
	float cloud = smoothstep(0.3, 0.75, n);
	COLOR = vec4(tint.rgb, tint.a * cloud);
}
