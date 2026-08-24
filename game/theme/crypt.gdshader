shader_type canvas_item;
// The room the whole game happens in.
//
// This replaces two things that were both liabilities: an AI-generated
// backdrop still, which at low alpha read as a rendering glitch rather than
// as a place, and the large empty black fields flanking every screen. It
// draws receding arches, side pillars and a floor, symmetric about the
// centre and full-bleed, so the frame is filled with architecture rather
// than with nothing.
//
// Entirely procedural: no texture, no art, one quad.

uniform vec4 stone : source_color = vec4(0.19, 0.17, 0.26, 1.0);
uniform vec4 deep : source_color = vec4(0.055, 0.045, 0.085, 1.0);
uniform vec4 accent : source_color = vec4(0.88, 0.83, 0.64, 1.0);

uniform float depth : hint_range(0.0, 1.0) = 0.0;      // 0 surface, 1 floor 10
uniform float glow_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.25) = 0.03;
uniform float aspect = 1.777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// One arch: a rounded opening centred at cx, of half-width w and height h.
// Returns how far inside it a point is, 0 outside.
float arch(vec2 p, float cx, float w, float h) {
	float dx = abs(p.x - cx);
	if (dx > w || p.y > h) return 0.0;
	// The curve of the top: a semicircle springing from 60% of the height.
	float spring = h * 0.55;
	if (p.y < spring) {
		return 1.0;
	}
	float t = (p.y - spring) / max(0.0001, h - spring);
	float half_at = w * sqrt(max(0.0, 1.0 - t * t));
	return dx < half_at ? 1.0 : 0.0;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(stone.rgb, deep.rgb, smoothstep(0.0, 1.15, uv.y));

	// Deeper floors are darker and lean toward the biome's colour.
	col = mix(col, col * 0.42 + accent.rgb * 0.03, depth);

	// Three ranks of arches receding toward the centre. Each is darker than
	// the wall it is cut into, which is what makes it read as an opening.
	float centred = (uv.x - 0.5) * aspect + 0.5;
	for (int rank = 0; rank < 3; rank++) {
		float f = float(rank);
		float scale = 1.0 - f * 0.18;
		float w = 0.135 * scale;
		float h = 0.68 * scale;
		// Further ranks are darker, but never so dark that the opening
		// becomes a black hole -- a big unlit shape in the middle of the
		// frame is the void problem again, wearing an arch.
		float dark = 0.52 - f * 0.07;
		// A pair either side of centre, plus one behind it.
		float inside = 0.0;
		inside += arch(vec2(centred, uv.y), 0.5 - (0.30 - f * 0.075), w, h);
		inside += arch(vec2(centred, uv.y), 0.5 + (0.30 - f * 0.075), w, h);
		// A smaller opening straight ahead, well back, to give the room a
		// vanishing point without punching a hole in the middle of it.
		if (rank == 2) {
			inside += arch(vec2(centred, uv.y), 0.5, w * 0.72, h * 0.82);
		}
		col = mix(col, col * dark, clamp(inside, 0.0, 1.0));
	}

	// Pillars down both edges, so the frame is bounded by architecture
	// rather than trailing off into black.
	float edge = min(uv.x, 1.0 - uv.x);
	float pillar = smoothstep(0.13, 0.02, edge);
	col = mix(col, col * 1.6 + accent.rgb * 0.028, pillar * 0.8);
	// A hard shadow where the pillar meets the wall behind it, and a lit
	// inner face -- an edge is what makes a shape read as a solid.
	float shade = smoothstep(0.155, 0.125, edge) * smoothstep(0.100, 0.130, edge);
	col *= 1.0 - shade * 0.55;
	float lip = smoothstep(0.132, 0.115, edge) * smoothstep(0.098, 0.118, edge);
	col += accent.rgb * lip * 0.20;

	// Masonry: broad blocks, then a finer grain over the top.
	vec2 block = vec2(uv.x * 14.0, uv.y * 22.0);
	float seam = step(0.94, fract(block.x)) + step(0.95, fract(block.y));
	col *= 1.0 - clamp(seam, 0.0, 1.0) * 0.30;
	col += (noise(uv * vec2(9.0, 6.0)) - 0.5) * 0.05;

	// The lantern: light rising from the floor of the room.
	float from_below = smoothstep(1.05, 0.35, uv.y);
	col += accent.rgb * from_below * (0.045 + 0.08 * glow_pulse) * (1.0 - depth * 0.6);

	// Vignette, and a drifting grain so the screen is never perfectly still.
	vec2 c = uv - vec2(0.5);
	col *= clamp(1.0 - dot(c, c) * 1.45, 0.0, 1.0);
	col += (hash(floor((uv + vec2(0.0, TIME * 0.02)) * 520.0)) - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
