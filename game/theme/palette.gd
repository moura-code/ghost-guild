class_name Palette
extends RefCounted
## Every colour in the game (spec §9): near-black stone, bone-white text, one
## accent per biome, ghosts in translucent cyan. Screens and widgets never
## write a Color literal -- they name one of these.

const STONE := Color("0b0d10")
const STONE_RAISED := Color("14181d")
const STONE_EDGE := Color("232a31")
const BONE := Color("e8e2d4")
const BONE_DIM := Color("8f8a7e")
const BONE_FAINT := Color("55524b")
const GHOST := Color(0.42, 0.92, 1.0, 0.72)
const GHOST_DIM := Color(0.42, 0.92, 1.0, 0.22)
const ECHO := Color(0.62, 0.72, 0.95, 0.58)
const PREPARED := Color(1.0, 0.86, 0.45, 0.92)
const RESTLESS := Color(1.0, 0.45, 0.35, 0.85)
const SOUL := Color("cfe8ff")
const DANGER := Color("d9534f")
const GOOD := Color("7fbf7f")

const BIOME_ACCENTS := {
	"catacombs": Color("cfc6a8"),
	"fungal_deep": Color("9b6bd6"),
	"the_kiln": Color("e0762f"),
}


static func biome_accent(biome_id: String) -> Color:
	if BIOME_ACCENTS.has(biome_id):
		return BIOME_ACCENTS[biome_id]
	return BONE_DIM
