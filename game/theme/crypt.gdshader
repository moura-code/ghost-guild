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

// One arch: an opening of half-width w running from `top` down to `bottom`,
// with a semicircular crown. 1 inside, 0 outside.
//
// The crown has to be at the TOP. The first version put the curve at the
// bottom of the shape, which made every arch a rounded slab hanging off the
// ceiling -- two of them either side of centre read as one big dark mass
// behind the fight, which is the blob problem all over again.
float arch(vec2 p, float cx, float w, float top, float bottom) {
	float dx = abs(p.x - cx);
	if (dx > w || p.y < top || p.y > bottom) return 0.0;
	float spring = top + w;
	if (p.y > spring) return 1.0;            // straight jambs below the crown
	float t = (spring - p.y) / max(0.0001, w);
	return dx < w * sqrt(max(0.0, 1.0 - t * t)) ? 1.0 : 0.0;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(stone.rgb, deep.rgb, smoothstep(0.0, 1.15, uv.y));

	// Deeper floors are darker and lean toward the biome's colour.
	col = mix(col, col * 0.42 + accent.rgb * 0.03, depth);

	// Two mirrored ranks of arches, held out at the sides. Nothing large and
	// dark may sit behind the middle of the frame: that is where the fight
	// happens, and a shadow there reads as a rendering fault rather than as
	// a room.
	float centred = (uv.x - 0.5) * aspect + 0.5;
	for (int rank = 0; rank < 2; rank++) {
		float f = float(rank);
		float w = 0.112 - f * 0.020;
		float top = 0.13 + f * 0.055;
		float bottom = 0.74 - f * 0.045;
		// Never much darker than the wall. An opening reads as an opening
		// because of its shape and its lit edge, not because it is black.
		float dark = 0.74 - f * 0.06;
		float off = 0.56 - f * 0.175;
		for (int side = 0; side < 2; side++) {
			float cx = side == 0 ? 0.5 - off : 0.5 + off;
			float inside = arch(vec2(centred, uv.y), cx, w, top, bottom);
			col = mix(col, col * dark, inside);
			// The lit stone edge around the opening. This is what makes it
			// architecture instead of a stain.
			float outer = arch(vec2(centred, uv.y), cx, w + 0.013, top - 0.013, bottom);
			col += accent.rgb * clamp(outer - inside, 0.0, 1.0) * (0.075 - f * 0.02);
		}
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
