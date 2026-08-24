class_name Palette
extends RefCounted
## Every colour in the game (spec §9): near-black stone, bone-white text, one
## accent per biome, ghosts in translucent cyan. Screens and widgets never
## write a Color literal -- they name one of these.

## Elevation. The old values sat within 5% of each other, which meant every
## panel, card and row rendered as the same flat grey and nothing read as
## sitting on anything. These are spread far enough apart to build a
## hierarchy with, and warmed slightly as they rise -- light in this game
## comes from lanterns, not from a blue sky.
const VOID := Color("05070a")
const STONE := Color("0d1014")
const STONE_RAISED := Color("1a1f26")
const STONE_HIGH := Color("262d36")
const STONE_EDGE := Color("39424e")
## The lit top edge of a raised surface, and the shadow it casts.
const EDGE_LIGHT := Color("4a5563")
const EDGE_SHADOW := Color("04060900")

const BONE := Color("f0eade")
const BONE_DIM := Color("9a9488")
const BONE_FAINT := Color("5f5b53")
const GHOST := Color(0.45, 0.94, 1.0, 0.85)
const GHOST_DIM := Color(0.45, 0.94, 1.0, 0.22)
const ECHO := Color(0.62, 0.72, 0.95, 0.65)
const PREPARED := Color("ffd166")
const RESTLESS := Color("ff7a5c")
const SOUL := Color("bfe4ff")
const DANGER := Color("e2574f")
const GOOD := Color("86c98a")

const BIOME_ACCENTS := {
	"catacombs": Color("cfc6a8"),
	"fungal_deep": Color("9b6bd6"),
	"the_kiln": Color("e0762f"),
}


static func biome_accent(biome_id: String) -> Color:
	if BIOME_ACCENTS.has(biome_id):
		return BIOME_ACCENTS[biome_id]
	return BONE_DIM
