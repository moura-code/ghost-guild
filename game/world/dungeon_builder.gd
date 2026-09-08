class_name DungeonBuilder
extends RefCounted
## Turns a FloorLayout into geometry, collision and light. It has no opinions
## about layout: if the corridor is wrong, the fix is in core/run/, where it
## can be tested without a window (spec §6).
##
## Geometry goes into three MultiMeshInstance3Ds rather than ~600 nodes,
## because a floor is 600 identical boxes and that is exactly what a MultiMesh
## is for. Collision is separate and merged into runs, because a collision
## box is invisible and can therefore be any size without stretching a
## texture.

const LAYER_WORLD := 1
const TORCH_COLOR := Color(1.0, 0.62, 0.26)
## Was 5.0, which clipped the near wall to white. A torch should be the
## warmest thing in the frame, not the least saturated.
const TORCH_ENERGY := 3.6
## How far out of its wall the flame hangs, in cells.
const TORCH_OUT := 0.62
const GROUND_THICKNESS := 1.0


## Where every piece of the floor goes, as three arrays of transforms keyed
## "floors", "ceilings", "walls".
##
## This is separate from build() for a reason worth remembering: a MultiMesh
## keeps its instance transforms on the RenderingServer, and a `--headless`
## run uses the dummy driver, which stores nothing and hands back identity for
## every one of them. So `get_instance_transform` is unassertable in the test
## suite. The numbers are computed here, where they can be checked, and poured
## into the buffer afterwards.
static func instance_transforms(layout: FloorLayout) -> Dictionary:
	var floors: Array[Transform3D] = []
	var ceilings: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	# A ceiling plane faces up like the floor does, so it is rolled 180° to
	# face back down; a plane lit from the wrong side is a black ceiling.
	var flip := Basis(Vector3.FORWARD, PI)
	for y in layout.height:
		for x in layout.width:
			var at := Kit.cell_to_world(Vector2i(x, y))
			match layout.cell(x, y):
				FloorLayout.Cell.FLOOR:
					floors.append(Transform3D(Basis.IDENTITY, at))
					ceilings.append(Transform3D(flip, at + Vector3(0.0, Kit.WALL_H, 0.0)))
				FloorLayout.Cell.WALL:
					walls.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, Kit.WALL_H * 0.5, 0.0)))
	return {"floors": floors, "ceilings": ceilings, "walls": walls}


## `biome_id` picks the stone. The Deep shipped with the Catacombs' walls and
## floor, so the only thing that said "somewhere else" was the colour of the
## air twenty metres away.
static func build(layout: FloorLayout, parent: Node3D, biome_id: String = Kit.HOME_STONE) -> Dictionary:
	var placed := instance_transforms(layout)
	var floors: Array[Transform3D] = placed["floors"]
	var ceilings: Array[Transform3D] = placed["ceilings"]
	var walls: Array[Transform3D] = placed["walls"]

	parent.add_child(_multi("Floors", Kit.floor_mesh(), Kit.floor_material(biome_id), floors))
	parent.add_child(_multi("Ceilings", Kit.ceiling_mesh(), Kit.ceiling_material(biome_id), ceilings))
	parent.add_child(_multi("Walls", Kit.wall_mesh(), Kit.wall_material(biome_id), walls))

	var boxes := wall_boxes(layout)
	parent.add_child(_collision(layout, boxes))

	# A `Torches` rather than a plain Node3D: the group the builder was already
	# making is also the right place to drive the flicker from, so it costs one
	# _process per floor and dies with the floor rather than outliving it.
	var torches := Torches.new()
	torches.name = "Torches"
	parent.add_child(torches)
	for raw in layout.torch_anchors:
		var light := torch_light(layout, raw)
		if light != null:
			torches.adopt(light)

	return {
		"floors": floors.size(),
		"walls": walls.size(),
		"torches": torches.count(),
		"boxes": boxes.size(),
	}


## Horizontal runs of wall merged into single boxes. One collider per cell is
## ~500 shapes per floor and every one of them is a seam the character
## controller can catch on; a merged run is one flat surface to slide along.
static func wall_boxes(layout: FloorLayout) -> Array:
	var out: Array = []
	for y in layout.height:
		var x := 0
		while x < layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.WALL:
				x += 1
				continue
			var run := 0
			while layout.cell(x + run, y) == FloorLayout.Cell.WALL:
				run += 1
			out.append(Rect2i(x, y, run, 1))
			x += run
	return out


## The bracket is bolted to a wall cell, so the flame has to hang in the open
## cell in front of it. Returns null for an anchor with nothing walkable
## beside it, which the generator can produce at a grid edge.
static func torch_light(layout: FloorLayout, anchor: Vector2i) -> OmniLight3D:
	var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var out_dir := Vector2i.ZERO
	for side in sides:
		if layout.is_walkable(anchor.x + side.x, anchor.y + side.y):
			out_dir = side
			break
	if out_dir == Vector2i.ZERO:
		return null
	var light := OmniLight3D.new()
	light.position = Vector3(
		(anchor.x + out_dir.x * TORCH_OUT) * Kit.CELL,
		Kit.WALL_H * 0.62,
		(anchor.y + out_dir.y * TORCH_OUT) * Kit.CELL)
	light.light_color = TORCH_COLOR
	light.light_energy = TORCH_ENERGY
	light.omni_range = Kit.CELL * 5.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	return light


static func _multi(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return inst


## One body for the whole floor: the walls as merged boxes, plus a slab under
## everything to stand on. The slab is safe because add_walls() rings every
## walkable cell in wall, so there is nowhere to walk off.
static func _collision(layout: FloorLayout, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0

	var ground := CollisionShape3D.new()
	ground.name = "Ground"
	var slab := BoxShape3D.new()
	slab.size = Vector3(layout.width * Kit.CELL + Kit.CELL, GROUND_THICKNESS, layout.height * Kit.CELL + Kit.CELL)
	ground.shape = slab
	ground.position = Vector3(
		(layout.width - 1) * Kit.CELL * 0.5,
		-GROUND_THICKNESS * 0.5,
		(layout.height - 1) * Kit.CELL * 0.5)
	body.add_child(ground)

	for raw in boxes:
		var box: Rect2i = raw
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x * Kit.CELL, Kit.WALL_H, Kit.CELL)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(
			(box.position.x + (box.size.x - 1) * 0.5) * Kit.CELL,
			Kit.WALL_H * 0.5,
			box.position.y * Kit.CELL)
		body.add_child(cs)
	return body
