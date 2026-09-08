class_name EnemyShape
extends RefCounted
## Which silhouette a creature gets, and how far off the ground it sits.
##
## Classification only. This file used to build the bodies too -- five
## functions stacking whole primitives into a bag of `MeshInstance3D` children
## -- and that job moved to `CreatureRig`, which hangs `BoneMesh` parts off
## joints a pose can drive. What is left is the question the rest of the game
## actually asks: *what shape of thing is this?*
##
## It depends on nothing on purpose. `CreaturePose` matches on `Kind` and
## `CreatureRig` builds from it, so this has to be the file at the bottom or
## the three of them form a parse-time ring.
##
## Silhouette is the cheapest way to carry "what am I fighting". Every enemy in
## the game was once the same capsule with a ball on top, so a rat, a spider, a
## floating wisp and a stack of skulls were four identical objects at four
## sizes. Telling what you are fighting is a rule of the genre, not a polish
## item.

enum Kind { HUMANOID, BEAST, WISP, STACK, HULK }

## Which archetype each enemy in the roster gets. An explicit table rather
## than inference from tags: `undead` covers a rat, a wisp and the boss, so
## tags cannot tell them apart, and guessing from hp would put the spider and
## the archer in the same bucket.
const SHAPES := {
	"bone_rat": Kind.BEAST,
	"crypt_spider": Kind.BEAST,
	"grave_wisp": Kind.WISP,
	"skull_stack": Kind.STACK,
	"shambler": Kind.HUMANOID,
	"bone_archer": Kind.HUMANOID,
	"hollow_knight": Kind.HUMANOID,
	"plague_bearer": Kind.HUMANOID,
	"ossuary_warden": Kind.HULK,
	"mother_of_bones": Kind.HULK,

	# The Fungal Deep. Nothing down here stands up straight except the husk,
	# which is a Catacombs corpse the fungus took and still walks like one.
	"spore_hound": Kind.BEAST,
	"rot_grub": Kind.BEAST,
	"bloom_wretch": Kind.STACK,
	"mycelial_husk": Kind.HUMANOID,
	"cap_thrower": Kind.STACK,
	"thorn_polyp": Kind.WISP,
	"flesh_weaver": Kind.BEAST,
	"deep_lurker": Kind.HULK,
	"sporemother": Kind.HULK,
	"the_bloom": Kind.HULK,

	# The Kiln. Built things, mostly: heavy, upright and made of pieces. The
	# two that are only fire float, because fire does not stand on anything.
	"cinder_hound": Kind.BEAST,
	"slag_crawler": Kind.BEAST,
	"ember_wisp": Kind.WISP,
	"furnace_drone": Kind.STACK,
	"clay_sentinel": Kind.HULK,
	"glass_shrike": Kind.STACK,
	"kiln_warden": Kind.HUMANOID,
	"molten_husk": Kind.HUMANOID,
	"the_bellows": Kind.HULK,
	"the_first_flame": Kind.WISP,
}


static func kind_for(def: EnemyDef) -> int:
	if SHAPES.has(def.id):
		return SHAPES[def.id]
	# An enemy added to the data without a shape still gets a body. Big things
	# are hulks, small things are beasts, everything else stands up.
	if def.hp >= 55:
		return Kind.HULK
	if def.hp <= 14:
		return Kind.BEAST
	return Kind.HUMANOID


## How far off the ground the thing floats. Only a wisp does.
static func hover(kind: int) -> float:
	return 0.85 if kind == Kind.WISP else 0.0
