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
const STONE_TINT := Color(0.74, 0.84, 0.96)
const FLOOR_TINT := Color(0.78, 0.85, 0.95)

static var _cache: Dictionary = {}


static func floor_material() -> StandardMaterial3D:
	return _material("floor", "pavingstones119", Vector2(CELL, CELL), FLOOR_TINT)


static func wall_material() -> StandardMaterial3D:
	return _material("wall", "bricks100", Vector2(CELL, WALL_H), STONE_TINT)


static func ceiling_material() -> StandardMaterial3D:
	return _material("ceiling", "rock051", Vector2(CELL, CELL), STONE_TINT)


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
