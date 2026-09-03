class_name EnemySkin
extends RefCounted
## What a creature is made of.
##
## The geometry is `CreatureRig`'s job; this is what it is made of. Both were
## once one stand-in, and "stand-in" was doing more work than it should: every
## enemy was a flat untextured colour on a smooth primitive, a shop mannequin
## however good the silhouette is. The rock wall two metres behind it had a
## normal map, a roughness map and ambient occlusion; the thing trying to kill
## you did not.
##
## Nothing here needs an artist. The kit's own CC0 stone, mapped triplanar so
## primitives need no UVs, plus a tint read off the enemy's tags, plus a rim
## light so a body at the edge of the torchlight is a shape rather than a hole.
## `CreatureRig` builds the geometry this dresses. The two were written to be
## replaced together by a rigged model and never were, because the parts a
## crypt creature is made of turned out to be the right model of it.

const TEXTURE_SET := "rock051"
## Metres per texture repeat on a creature. Tighter than the kit's 2 m, because
## a creature is about two metres tall and one repeat over the whole body reads
## as a pattern rather than as a surface.
const TEXEL := 0.55
## Enough to separate a silhouette from the dark without making it glow. The
## crypt's threat is that you cannot see; a rim light that reads as neon takes
## that away.
const RIM := 0.35
const RIM_TINT := 0.6
## The faint self-light that keeps a creature outside the torchlight from being
## nothing at all. `EnemyBody` raises this to highlight a target.
const REST_EMISSION := 0.05

## Tags come from the enemy data, so a creature is coloured by what it *is*
## rather than by a per-enemy art field nobody would keep in step. First match
## wins, so the order is the priority: what something is made of beats what it
## used to be, and a fungal corpse reads as fungus.
const TAG_TINT := [
	["fungal", Color(0.46, 0.40, 0.52)],
	["construct", Color(0.36, 0.36, 0.40)],
	["flesh", Color(0.48, 0.36, 0.34)],
	["undead", Color(0.52, 0.49, 0.42)],
]
const DEFAULT_TINT := Color(0.44, 0.42, 0.38)

## Emission is cold everywhere: it is the room's fill leaking off a wet thing,
## not the creature's own light.
const EMISSION := Color(0.36, 0.40, 0.46)

static var _cache: Dictionary = {}


static func tint_for(tags: Array) -> Color:
	for entry in TAG_TINT:
		if tags.has(String(entry[0])):
			return entry[1]
	return DEFAULT_TINT


## One material per creature, not per enemy type: `EnemyBody` fades its own
## albedo alpha as it dies, and a shared material would take every other body
## on the floor down with it.
static func material_for(def: EnemyDef) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint_for(def.tags)
	m.roughness = 0.92
	# Triplanar: the shapes are spheres, capsules and boxes built in code, and
	# a primitive's UVs stretch and pinch wherever it curves. Projecting from
	# world space costs three texture fetches and needs no UVs at all.
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / TEXEL
	m.albedo_texture = _texture("color")
	m.normal_enabled = true
	m.normal_texture = _texture("normal")
	m.roughness_texture = _texture("roughness")
	m.ao_enabled = true
	m.ao_texture = _texture("ao")
	m.ao_light_affect = 0.6
	m.rim_enabled = true
	m.rim = RIM
	m.rim_tint = RIM_TINT
	m.emission_enabled = true
	m.emission = EMISSION
	m.emission_energy_multiplier = REST_EMISSION
	return m


static func _texture(map: String) -> Texture2D:
	if not _cache.has(map):
		_cache[map] = load("%s%s/%s.jpg" % [Kit.MAT_ROOT, TEXTURE_SET, map])
	return _cache[map]
