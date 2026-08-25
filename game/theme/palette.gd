class_name Palette
extends RefCounted
## Every colour in the game (spec §9): near-black stone, bone-white text, one
## accent per biome, ghosts in translucent cyan. Screens and widgets never
## write a Color literal -- they name one of these.

## Elevation, as a light model rather than a set of tints.
##
## The previous ramp put every stone value between 4% and 42% luminance and
## made every one of them purple. Nothing separated from anything and the
## whole game rendered as fog -- which is exactly what a review of all twelve
## screens found. The fix is not more colours, it is *range*: this ladder is
## anchored at true black and at bone, so there is somewhere for a shadow to
## go and somewhere for a highlight to reach.
##
## The other half is that light is WARM and shadow is COLD. Lantern light
## against near-black stone is the complementary contrast Darkest Dungeon and
## Cultist Simulator run on. `EDGE_LIGHT` used to be cold purple, which meant
## every lit edge in the game was the same hue as the shadow beside it.
##
## `theme_test.gd` asserts the rules this ladder has to keep: it climbs
## without ties, it spans more than 0.80 of the range, light is warm, and
## ghost cyan is the only cool accent in the game.
const ABYSS := Color("04050a")
const VOID := Color("07080f")
const STONE := Color("0d0f16")
const STONE_RAISED := Color("161a24")
const STONE_HIGH := Color("2b2f3d")
const STONE_EDGE := Color("454a5c")
## The lit top edge of a raised surface, and the shadow it casts.
const EDGE_LIGHT := Color("c9a86a")
const EDGE_SHADOW := Color("04060900")
## A lit surface: used at low alpha over stone, never as a fill.
const LANTERN := Color("ffe6b0")

const BONE := Color("f4efe4")
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


## Perceived brightness (Rec. 709). The elevation ladder is defined by this
## rather than by eye, so "is the background darker than what sits on it" is
## a question with an answer a test can check.
static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
