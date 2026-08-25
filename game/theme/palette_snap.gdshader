shader_type canvas_item;
// Snaps every pixel the game draws to the game's palette.
//
// This sits over the whole frame, and it is what makes the game pixel art
// rather than a game with some pixel art in it. Converting widget by widget
// does not work: a `draw_circle` is anti-aliased, a shader gradient has a
// thousand steps in it, a particle fades through alpha, and a font hints its
// own greys -- each of those quietly reintroduces the smooth look no matter
// how small the sprites are. Collapsing the whole rendered frame to a fixed
// set of colours fixes all of them in one place, and it is what a real
// pixel-art pipeline does anyway: the palette is the art direction.
//
// The viewport is 640x360 and is scaled up by a whole number, so a pixel
// here is a pixel on screen. Nothing below is per-widget -- it applies to
// the crypt shader, the props, the cards, the numbers and the text equally.

uniform sampler2D screen : hint_screen_texture, filter_nearest;

// The palette, from game/theme/palette.gd plus the mid-tones a gradient
// needs to band through cleanly. Kept deliberately small: a wide palette
// snaps to something near enough that nothing visibly changes, which defeats
// the point. These are the colours the game is allowed to be.
const int COUNT = 28;
const vec3 PALETTE[COUNT] = {
	vec3(0.016, 0.020, 0.039),  // ABYSS
	vec3(0.027, 0.031, 0.055),
	vec3(0.051, 0.059, 0.086),  // STONE
	vec3(0.086, 0.102, 0.141),  // STONE_RAISED
	vec3(0.122, 0.141, 0.188),
	vec3(0.169, 0.184, 0.239),  // STONE_HIGH
	vec3(0.216, 0.239, 0.302),
	vec3(0.271, 0.290, 0.361),  // STONE_EDGE
	vec3(0.353, 0.376, 0.439),
	vec3(0.788, 0.659, 0.416),  // EDGE_LIGHT
	vec3(0.545, 0.451, 0.278),
	vec3(1.000, 0.902, 0.690),  // LANTERN
	vec3(0.957, 0.937, 0.894),  // BONE
	vec3(0.604, 0.580, 0.533),  // BONE_DIM
	vec3(0.373, 0.357, 0.325),  // BONE_FAINT
	vec3(0.450, 0.940, 1.000),  // GHOST
	vec3(0.250, 0.560, 0.640),
	vec3(0.620, 0.720, 0.950),  // ECHO
	vec3(1.000, 0.788, 0.235),  // PREPARED
	vec3(0.624, 0.847, 1.000),  // SOUL
	vec3(1.000, 0.353, 0.353),  // DANGER
	vec3(0.600, 0.200, 0.220),
	vec3(0.525, 0.788, 0.541),  // GOOD
	vec3(0.290, 0.122, 0.165),  // PLATE_ENEMY
	vec3(0.353, 0.125, 0.157),  // PLATE_ATTACK
	vec3(0.118, 0.227, 0.322),  // PLATE_SKILL
	vec3(0.275, 0.165, 0.369),  // PLATE_POWER
	vec3(0.878, 0.827, 0.643)   // catacombs accent
};

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	// Nearest entry by squared distance. Weighted toward green the way the
	// eye is, so a mid grey does not snap to a blue just because the blue is
	// arithmetically closer.
	vec3 best = PALETTE[0];
	float closest = 1e9;
	for (int i = 0; i < COUNT; i++) {
		vec3 d = (c - PALETTE[i]) * vec3(0.60, 1.00, 0.40);
		float dist = dot(d, d);
		if (dist < closest) {
			closest = dist;
			best = PALETTE[i];
		}
	}
	COLOR = vec4(best, 1.0);
}
