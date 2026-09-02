class_name Grade
extends RefCounted
## The single grade for the whole game: one tonemap, one fog, one ambient,
## everywhere, on every floor, over every asset. Mixed CC0 sources look like
## one game only if they are lit and graded by one thing (spec §7), so this
## is the one thing.
##
## Depth is the only parameter. It does not change the grade -- it changes
## how much light there is inside it, which is "depth is the threat"
## (spec §2.3) expressed as numbers.

## Fill light. Was 0.085 and the crypt read as one flat orange: with almost no
## ambient, the ONLY light was the torches, so every surface was some value of
## the same warm hue and the image had no colour contrast at all. Real
## underground photography has a cold fill -- sky bounce, damp, distance -- and
## it is what makes torchlight look like fire instead of like a brightness
## setting.
## 0.34 went too far the other way and turned the whole crypt blue-grey. The
## fill exists to keep the shadows from being black, not to compete with the
## torches: warm has to win wherever a torch reaches.
const AMBIENT_TOP := 0.22
const AMBIENT_BOTTOM := 0.11
const FOG_TOP := 0.020
const FOG_BOTTOM := 0.055
## The cold half of the palette. Warm torches against this is the whole look.
const FILL_TOP := Color(0.38, 0.48, 0.70)
const FILL_BOTTOM := Color(0.20, 0.28, 0.52)

## How far a biome shifts the colour of the air, for the fog and for the fill.
##
## The grade does not change -- one tonemap, one fog model, one saturation,
## everywhere, because that is the whole reason mixed CC0 sources read as one
## game. What changes is the light inside it. Spec §9 gives each biome one
## accent (ivory, violet, orange) and nothing read them until now.
## Halved once the biomes were made of different stone. The tint was carrying
## the whole difference between the Catacombs and the Deep on its own, and at
## that strength on top of grey strata and a rotting floor the Deep came out a
## violet-black murk you could not read a corridor in. The air says where you
## are; the walls say it too now, and they should not both shout.
const BIOME_FOG_TINT := 0.18
const BIOME_FILL_TINT := 0.12
## The biome the game was graded in. The shift is measured from here rather
## than from neutral, so the Catacombs are an identity by construction and
## every judgement already made about the look still holds.
const HOME_BIOME := "catacombs"


static func depth_of(floor: int, last_floor: int) -> float:
	if last_floor <= 1:
		return 0.0
	return clampf(float(floor - 1) / float(last_floor - 1), 0.0, 1.0)


## Moves `base` toward `biome_id`'s accent by `amount`, measured against the
## home biome's accent -- so passing the home biome (or nothing) returns
## `base` unchanged, and an unknown id does too.
static func biome_tint(base: Color, biome_id: String, amount: float) -> Color:
	# An id with no authored accent leaves the light alone. `biome_accent`
	# falls back to bone for an unknown id, which is the right answer for a
	# label and the wrong one here -- it would tint the air toward nothing in
	# particular for any biome added to the data before the palette.
	if biome_id == HOME_BIOME or not Palette.BIOME_ACCENTS.has(biome_id):
		return base
	var accent := Palette.biome_accent(biome_id)
	var home := Palette.biome_accent(HOME_BIOME)
	return Color(
		clampf(base.r + (accent.r - home.r) * amount, 0.0, 1.0),
		clampf(base.g + (accent.g - home.g) * amount, 0.0, 1.0),
		clampf(base.b + (accent.b - home.b) * amount, 0.0, 1.0),
		base.a)


static func environment(depth: float, biome_id: String = "") -> Environment:
	var d := clampf(depth, 0.0, 1.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cold ambient against warm torchlight: the contrast is what makes a torch
	# read as a torch instead of as the room's brightness.
	env.ambient_light_color = biome_tint(FILL_TOP.lerp(FILL_BOTTOM, d), biome_id, BIOME_FILL_TINT)
	env.ambient_light_energy = lerpf(AMBIENT_TOP, AMBIENT_BOTTOM, d)

	env.fog_enabled = true
	# Exponential, NOT depth. FOG_MODE_DEPTH ignores fog_density entirely and
	# uses fog_depth_begin/end instead, so switching to it silently turned the
	# fog off over the twenty metres a corridor actually spans.
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = biome_tint(
		Color(0.16, 0.22, 0.36).lerp(Color(0.07, 0.10, 0.19), d), biome_id, BIOME_FOG_TINT)
	env.fog_density = lerpf(FOG_TOP, FOG_BOTTOM, d)
	# Fog that takes colour from the lights in it, so a torch down a corridor
	# glows through the haze instead of being flattened by it.
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Was 4.0, and every torch clipped to white -- a blown highlight has no
	# colour, so the brightest thing in the frame was also the least warm.
	env.tonemap_white = 8.0
	env.tonemap_exposure = 1.0

	env.ssao_enabled = true
	env.ssao_intensity = 1.8
	env.ssao_radius = 1.0
	env.ssil_enabled = true
	env.ssil_intensity = 0.5

	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.12
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	# The last 10%: a little more colour than the render gives, and a black
	# point that is actually black. One place, for the whole game.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.0
	return env


static func world_environment(depth: float, biome_id: String = "") -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.environment = environment(depth, biome_id)
	return we


## The guild. The only room in the game that is not a crypt, and it has to
## read that way before a word is on screen: warmer, brighter, and with the
## fog pulled back so you can see the far wall. Everything else -- the
## tonemap, the SSAO, the glow -- is the same grade the dungeon uses, because
## the guild and the crypt have to look like the same game.
static func guild_environment() -> Environment:
	var env := environment(0.0)
	# Warmer and brighter than any crypt floor, and the fog pulled right back:
	# the guild is the only safe place in the game and it has to read that way
	# before a word is on screen.
	env.ambient_light_color = Color(0.46, 0.44, 0.46)
	env.ambient_light_energy = 0.55
	env.fog_light_color = Color(0.26, 0.24, 0.24)
	env.fog_density = 0.008
	env.adjustment_saturation = 1.10
	return env


static func world_environment_guild() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.environment = guild_environment()
	return we
