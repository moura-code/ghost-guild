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

// Pushed from Palette by Atmosphere so there is one source of truth for the
// light model. The defaults match it; they exist so the shader is legible on
// its own and so a missing push does not render a magenta screen.
uniform vec4 stone : source_color = vec4(0.051, 0.059, 0.086, 1.0);
uniform vec4 deep : source_color = vec4(0.016, 0.020, 0.039, 1.0);
uniform vec4 accent : source_color = vec4(0.88, 0.83, 0.64, 1.0);
uniform vec4 lantern : source_color = vec4(1.0, 0.902, 0.690, 1.0);

uniform float depth : hint_range(0.0, 1.0) = 0.0;      // 0 surface, 1 floor 10
uniform float glow_pulse : hint_range(0.0, 1.0) = 0.0;

// The focus rule: where this screen's content lives, and how hard everything
// outside it falls away. Strength 0 means no screen declared one, and the
// frame is lit open exactly as it was before this existed.
uniform vec2 focus_centre = vec2(0.5, 0.5);
uniform float focus_radius = 0.35;
uniform float focus_strength : hint_range(0.0, 1.0) = 0.0;

// Pushed every frame by Atmosphere. Multiplies every warm highlight in the
// room so the whole place breathes with the flame rather than one element
// of it blinking on its own.
uniform float flicker = 1.0;
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

	// ONE rank of arches, not two. The second rank sat at low contrast behind
	// the first and read as a rendering artifact rather than as depth.
	//
	// And the interior is now genuinely dark. The previous version darkened
	// an opening by 26% on the reasoning that "an opening reads as an opening
	// because of its shape and its lit edge, not because it is black" -- but
	// at that contrast it read as a smudge on the wall. An opening is a hole:
	// it is where the light does not reach.
	float centred = (uv.x - 0.5) * aspect + 0.5;
	float w = 0.108;
	float top = 0.15;
	float bottom = 0.76;
	float off = 0.54;
	for (int side = 0; side < 2; side++) {
		float cx = side == 0 ? 0.5 - off : 0.5 + off;
		float inside = arch(vec2(centred, uv.y), cx, w, top, bottom);
		col = mix(col, deep.rgb * 0.6, inside * 0.92);
		// The lit stone edge around the opening -- warm, because the light in
		// this game comes from lanterns. This is the only thing that makes it
		// architecture instead of a hole punched in a wall, so it carries
		// more weight now that the interior is dark.
		float outer = arch(vec2(centred, uv.y), cx, w + 0.014, top - 0.014, bottom);
		col += lantern.rgb * clamp(outer - inside, 0.0, 1.0) * 0.14 * flicker;
	}

	// The frame falls into shadow at both edges.
	//
	// This used to do the opposite -- `col * 1.6` on the outer 13% -- which
	// made the two vertical bands at the extreme left and right the brightest
	// pixels on almost every screen. The eye went to the frame instead of to
	// the game. Nothing at the edge of the frame may outshine the content.
	float edge = min(uv.x, 1.0 - uv.x);
	float pillar = smoothstep(0.15, 0.01, edge);
	col = mix(col, deep.rgb, pillar * 0.80);
	// A single warm lip where the pillar's inner face catches the light, so
	// the darkness at the edge still reads as a solid and not as a fade-out.
	float lip = smoothstep(0.168, 0.148, edge) * smoothstep(0.128, 0.150, edge);
	col += lantern.rgb * lip * 0.10 * flicker;

	// Masonry: broad blocks, then a finer grain over the top. Subtler than
	// before -- on a ground this dark, loud seams are the loudest thing here.
	vec2 block = vec2(uv.x * 14.0, uv.y * 22.0);
	float seam = step(0.94, fract(block.x)) + step(0.95, fract(block.y));
	col *= 1.0 - clamp(seam, 0.0, 1.0) * 0.22;
	col += (noise(uv * vec2(9.0, 6.0)) - 0.5) * 0.03;

	// The lantern: light rising from the floor of the room.
	float from_below = smoothstep(1.05, 0.35, uv.y);
	col += lantern.rgb * from_below * (0.030 + 0.075 * glow_pulse) * (1.0 - depth * 0.6) * flicker;

	// Damp drifting along the floor. Slow enough to read as air rather than
	// as a scrolling texture, and faint enough to stay out of the way.
	float fog = noise(vec2(uv.x * 2.4 + TIME * 0.045, uv.y * 3.2 - TIME * 0.02));
	col += lantern.rgb * fog * smoothstep(0.45, 1.0, uv.y) * 0.022;

	// The focus falloff: the ground darkens away from wherever this screen
	// put its content. Measured with the aspect folded in so the lit core is
	// a circle on screen rather than an ellipse.
	if (focus_strength > 0.0) {
		vec2 fc = (uv - focus_centre) * vec2(aspect, 1.0);
		float fall = smoothstep(focus_radius, focus_radius * 2.3, length(fc));
		col = mix(col, deep.rgb * 0.35, fall * focus_strength);
	}

	// Vignette. Stronger than it was: it is what holds the centre of the
	// frame now that the edges no longer glow.
	vec2 c = uv - vec2(0.5);
	col *= clamp(1.0 - dot(c, c) * 2.30, 0.0, 1.0);
	col += (hash(floor((uv + vec2(0.0, TIME * 0.02)) * 520.0)) - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
