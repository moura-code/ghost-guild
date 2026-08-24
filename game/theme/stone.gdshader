shader_type canvas_item;
// The ground the whole game sits on. Flat near-black reads as "unfinished";
// a slow vertical gradient with a vignette and a drifting grain reads as a
// place. Costs one full-screen quad and no art.

uniform vec4 top_color : source_color = vec4(0.070, 0.082, 0.098, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.016, 0.020, 0.027, 1.0);
uniform vec4 accent : source_color = vec4(0.81, 0.78, 0.66, 1.0);

uniform float vignette : hint_range(0.0, 2.0) = 0.85;
uniform float grain : hint_range(0.0, 0.25) = 0.035;
uniform float grain_drift = 0.02;
uniform float depth : hint_range(0.0, 1.0) = 0.0;   // 0 = surface, 1 = floor 10
uniform float glow_pulse : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Cheap value noise — enough to break up a flat wall, not enough to cost.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;

	// Deeper floors sit darker and lean toward the biome accent.
	vec3 top = mix(top_color.rgb, top_color.rgb * 0.55 + accent.rgb * 0.06, depth);
	vec3 bottom = mix(bottom_color.rgb, bottom_color.rgb * 0.6, depth);
	vec3 col = mix(top, bottom, smoothstep(0.0, 1.0, uv.y));

	// Broad stone mottling, two octaves, static so it reads as rock.
	float n = noise(uv * vec2(6.0, 4.0)) * 0.6 + noise(uv * vec2(19.0, 13.0)) * 0.4;
	col += (n - 0.5) * 0.035;

	// A faint warm bloom from below, as if something is lit down there.
	float from_below = smoothstep(1.0, 0.45, uv.y);
	col += accent.rgb * from_below * (0.012 + 0.03 * glow_pulse);

	vec2 c = uv - vec2(0.5);
	col *= clamp(1.0 - dot(c, c) * vignette * 2.0, 0.0, 1.0);

	// Drifting film grain, so the screen is never perfectly still.
	float g = hash(floor((uv + vec2(0.0, TIME * grain_drift)) * 520.0));
	col += (g - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
