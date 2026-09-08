class_name Kit
extends RefCounted
## The modular kit: the only place in the game that knows how big a cell is
## and what stone looks like. Everything else works in cells and asks here
## for metres.
##
## The pieces are procedural -- a plane and a box -- rather than authored
## meshes, because stage 0 proved that with correct texel density and
## torchlight, boxes already read as a crypt, and there is no artist to
## author twelve pieces. Swapping in authored geometry later changes the
## three mesh functions below and nothing else in the game.

## Metres per grid cell. Not the 4 m the spec first guessed: a 24x24 grid at
## 4 m is 96 m across and a 4 m corridor reads as a hall. 3 m is the width
## the stage 0 shot was framed at, and it is why that shot read as a crypt.
const CELL := 3.0
const WALL_H := 3.2
## Metres per texture repeat, for every surface in the game. This single
## number is the discipline that stops mixed CC0 sources reading as an asset
## flip: a wall and the floor it meets never disagree about how big a stone
## is (spec §7).
const TEXEL := 2.0
const MAT_ROOT := "res://assets/materials/"
## The CC0 stone sets are warm sandstone. Under warm torchlight that made
## every pixel in the game some value of the same orange -- no colour contrast
## anywhere, which is exactly what "muy sombrio y poco atractivo" describes.
##
## Tinting the albedo cool-grey pulls the colour OUT of the texture so it comes
## from the lighting instead: warm where the torches reach, cold blue in the
## fill, real contrast between them. This is the cheapest, biggest single
## change to how the game looks, and it is a colourist's move, not a hack --
## a stone wall is grey, and it looks orange because it is lit by fire.
## Knocks the red down hard and the blue barely at all, so the stone cools
## without going dark. A tint that lowers all three channels just dims the
## room, which is the opposite of the problem being solved.
const STONE_TINT := Color(0.80, 0.86, 0.94)
const FLOOR_TINT := Color(0.84, 0.88, 0.94)
## The Deep is dug rather than built, and its floor is alive. Ground068 is a
## woodland floor photographed in daylight, so the tint has to pull most of the
## green out of it: fourteen floors down, what is left should read as rot under
## the torch and as nothing at all outside it.
## As bright as the Catacombs' stone and cooler, not darker: a biome that is
## harder to see in is not a biome with atmosphere, it is one you turn the
## brightness up for.
const DEEP_STONE_TINT := Color(0.76, 0.84, 0.96)
const DEEP_FLOOR_TINT := Color(0.74, 0.79, 0.76)
## The Deep's ceiling is raw rock rather than the Catacombs' smooth vault, and
## at full brightness its speckle was the busiest surface in the frame -- on
## the one surface nobody looks at on purpose. It recedes.
const DEEP_CEILING_TINT := Color(0.52, 0.58, 0.70)
## The Kiln's stone is fired brick and scorched rock, which is warm before
## anything is done to it -- so the tint stays cool like every other biome's.
## The heat comes from the torches and from the biome's own accent in the fog
## (see `Grade.biome_tint`), never from a warm albedo. That rule is what makes
## a torch read as fire rather than as a brightness setting, and the biome that
## is *about* fire is the last place to break it.
const KILN_STONE_TINT := Color(0.86, 0.90, 0.96)
const KILN_FLOOR_TINT := Color(0.80, 0.85, 0.92)
## Soot on a vault. The darkest surface in the game, on purpose: a ceiling you
## can read is a ceiling you look at.
const KILN_CEILING_TINT := Color(0.55, 0.60, 0.70)

## What each biome is made of. The Catacombs are laid brick and cut paving --
## somebody built them. The Deep is fractured strata and a floor of moss and
## rot -- nobody did.
##
## The tint is per surface rather than per set because the sets are photographs
## of different things: what they have in common is the texel density, and what
## they must not have in common is a colour cast the lighting did not put there.
const BIOME_STONE := {
	"catacombs": {
		"wall": "bricks100", "floor": "pavingstones119", "ceiling": "rock051",
		"wall_tint": STONE_TINT, "floor_tint": FLOOR_TINT, "ceiling_tint": STONE_TINT,
	},
	"fungal_deep": {
		"wall": "rock023", "floor": "ground068", "ceiling": "rock030",
		"wall_tint": DEEP_STONE_TINT, "floor_tint": DEEP_FLOOR_TINT,
		"ceiling_tint": DEEP_CEILING_TINT,
	},
	"the_kiln": {
		"wall": "bricks056", "floor": "rock020", "ceiling": "rock035",
		"wall_tint": KILN_STONE_TINT, "floor_tint": KILN_FLOOR_TINT,
		"ceiling_tint": KILN_CEILING_TINT,
	},
}
## Everywhere the data goes that the kit has no stone for yet.
const HOME_STONE := "catacombs"

static var _cache: Dictionary = {}


## The stone table for a biome, falling back to the Catacombs. A biome added to
## `data/` before its materials are downloaded gets a room rather than a crash,
## which is also what makes the fallback worth having: the content and the art
## do not have to land in the same commit.
static func stone_for(biome_id: String) -> Dictionary:
	return BIOME_STONE.get(biome_id, BIOME_STONE[HOME_STONE])


static func floor_material(biome_id: String = HOME_STONE) -> StandardMaterial3D:
	var stone := stone_for(biome_id)
	return _material("floor:" + String(stone["floor"]), String(stone["floor"]),
		Vector2(CELL, CELL), stone["floor_tint"])


static func wall_material(biome_id: String = HOME_STONE) -> StandardMaterial3D:
	var stone := stone_for(biome_id)
	return _material("wall:" + String(stone["wall"]), String(stone["wall"]),
		Vector2(CELL, WALL_H), stone["wall_tint"])


static func ceiling_material(biome_id: String = HOME_STONE) -> StandardMaterial3D:
	var stone := stone_for(biome_id)
	return _material("ceiling:" + String(stone["ceiling"]), String(stone["ceiling"]),
		Vector2(CELL, CELL), stone["ceiling_tint"])


static func floor_mesh() -> PlaneMesh:
	if not _cache.has("floor_mesh"):
		var m := PlaneMesh.new()
		m.size = Vector2(CELL, CELL)
		_cache["floor_mesh"] = m
	return _cache["floor_mesh"]


static func ceiling_mesh() -> PlaneMesh:
	# Same plane, flipped by the instance transform rather than by a second
	# mesh: one less resource and one less thing to keep in sync.
	return floor_mesh()


static func wall_mesh() -> BoxMesh:
	if not _cache.has("wall_mesh"):
		var m := BoxMesh.new()
		m.size = Vector3(CELL, WALL_H, CELL)
		_cache["wall_mesh"] = m
	return _cache["wall_mesh"]


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)


static func world_to_cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))


## `span` is the size in metres of the surface this material goes on, so the
## uv scale can be solved for TEXEL metres per repeat on both axes. Godot maps
## a PlaneMesh and each BoxMesh face across 0..1, so the span is exactly the
## face's dimensions.
static func _material(key: String, folder: String, span: Vector2, tint: Color = Color.WHITE) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load(MAT_ROOT + folder + "/color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(MAT_ROOT + folder + "/normal.jpg")
	m.roughness_texture = load(MAT_ROOT + folder + "/roughness.jpg")
	m.ao_enabled = true
	m.ao_texture = load(MAT_ROOT + folder + "/ao.jpg")
	m.ao_light_affect = 0.7
	m.uv1_scale = Vector3(span.x / TEXEL, span.y / TEXEL, 1.0)
	_cache[key] = m
	return m
