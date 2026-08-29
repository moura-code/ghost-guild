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

const AMBIENT_TOP := 0.085
const AMBIENT_BOTTOM := 0.030
const FOG_TOP := 0.026
const FOG_BOTTOM := 0.075


static func depth_of(floor: int, last_floor: int) -> float:
	if last_floor <= 1:
		return 0.0
	return clampf(float(floor - 1) / float(last_floor - 1), 0.0, 1.0)


static func environment(depth: float) -> Environment:
	var d := clampf(depth, 0.0, 1.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cold ambient against warm torchlight: the contrast is what makes a torch
	# read as a torch instead of as the room's brightness.
	env.ambient_light_color = Color(0.30, 0.36, 0.48).lerp(Color(0.16, 0.20, 0.34), d)
	env.ambient_light_energy = lerpf(AMBIENT_TOP, AMBIENT_BOTTOM, d)
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.15, 0.20).lerp(Color(0.07, 0.07, 0.11), d)
	env.fog_density = lerpf(FOG_TOP, FOG_BOTTOM, d)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	return env


static func world_environment(depth: float) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.environment = environment(depth)
	return we


## The guild. The only room in the game that is not a crypt, and it has to
## read that way before a word is on screen: warmer, brighter, and with the
## fog pulled back so you can see the far wall. Everything else -- the
## tonemap, the SSAO, the glow -- is the same grade the dungeon uses, because
## the guild and the crypt have to look like the same game.
static func guild_environment() -> Environment:
	var env := environment(0.0)
	env.ambient_light_color = Color(0.42, 0.40, 0.44)
	env.ambient_light_energy = 0.22
	env.fog_light_color = Color(0.22, 0.20, 0.21)
	env.fog_density = 0.010
	return env


static func world_environment_guild() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.environment = guild_environment()
	return we
