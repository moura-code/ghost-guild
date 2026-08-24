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
## Warmed and lifted off pure black. Every game that has succeeded on this
## art budget -- Balatro, Luck be a Landlord, Cultist Simulator -- fills the
## frame with saturated colour instead of leaving voids; near-monochrome on
## near-black is the opposite playbook and it reads as unfinished.
const VOID := Color("0a0910")
const STONE := Color("14121c")
const STONE_RAISED := Color("221f2e")
const STONE_HIGH := Color("332e42")
const STONE_EDGE := Color("4a4460")
## The lit top edge of a raised surface, and the shadow it casts.
const EDGE_LIGHT := Color("6b6390")
const EDGE_SHADOW := Color("04060900")

const BONE := Color("f0eade")
const BONE_DIM := Color("9a9488")
const BONE_FAINT := Color("5f5b53")
const GHOST := Color(0.45, 0.94, 1.0, 0.85)
const GHOST_DIM := Color(0.45, 0.94, 1.0, 0.22)
const ECHO := Color(0.62, 0.72, 0.95, 0.65)
const PREPARED := Color("ffc93c")
const SOUL := Color("9fd8ff")
const DANGER := Color("ff5a5a")
const GOOD := Color("86c98a")

## The plate a glyph sits on. Flat icons read as clip art dropped on a
## slide; the same icon on a coloured disc reads as part of a system. This
## is what Slay the Spire, Monster Train and Balatro all do with their flat
## iconography, and it costs a draw call rather than an artist.
const PLATE_ENEMY := Color("4a1f2a")
const PLATE_ATTACK := Color("5a2028")
const PLATE_SKILL := Color("1e3a52")
const PLATE_POWER := Color("462a5e")
const PLATE_NEUTRAL := Color("2a2636")


static func plate_for_card(type: String) -> Color:
	match type:
		"attack":
			return PLATE_ATTACK
		"skill":
			return PLATE_SKILL
		"power":
			return PLATE_POWER
	return PLATE_NEUTRAL


const BIOME_ACCENTS := {
	"catacombs": Color("e0d3a4"),
	"fungal_deep": Color("9b6bd6"),
	"the_kiln": Color("e0762f"),
}


static func biome_accent(biome_id: String) -> Color:
	if BIOME_ACCENTS.has(biome_id):
		return BIOME_ACCENTS[biome_id]
	return BONE_DIM
