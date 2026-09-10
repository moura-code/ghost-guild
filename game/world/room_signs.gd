class_name RoomSigns
extends RefCounted
## Signs stand outside trigger boundaries. They observe run state only.

static func doors(layout: FloorLayout, room_index: int) -> Array:
	var room := layout.room_rect(room_index)
	var out: Array = []
	for y in range(int(room["y"]), int(room["y"]) + int(room["h"])):
		for x in range(int(room["x"]), int(room["x"]) + int(room["w"])):
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var outside: Vector2i = Vector2i(x, y) + direction
				if outside.x >= int(room["x"]) and outside.x < int(room["x"]) + int(room["w"]) and outside.y >= int(room["y"]) and outside.y < int(room["y"]) + int(room["h"]):
					continue
				if layout.is_walkable(outside.x, outside.y):
					out.append({"cell": outside, "direction": direction})
	return out


## One sign per continuous opening, even when a corridor joins along a wall.
static func sign_doors(layout: FloorLayout, room_index: int) -> Array:
	var remaining := doors(layout, room_index)
	var out := []
	while not remaining.is_empty():
		var group: Array = [remaining.pop_front()]
		var cursor := 0
		while cursor < group.size():
			var at: Dictionary = group[cursor]
			cursor += 1
			for i in range(remaining.size() - 1, -1, -1):
				var other: Dictionary = remaining[i]
				if other["direction"] == at["direction"] and (other["cell"] as Vector2i).distance_squared_to(at["cell"]) == 1:
					group.append(other)
					remaining.remove_at(i)
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["cell"] as Vector2i) < (b["cell"] as Vector2i))
		out.append(group[group.size() / 2])
	return out


static func service_cell(layout: FloorLayout, room_index: int) -> Vector2i:
	var room := layout.room_rect(room_index)
	return Vector2i(int(room["x"]) + int(room["w"]) - 1, int(room["y"]) + int(room["h"]) - 1)


static func build(parent: Node3D, layout: FloorLayout, run: RunState, index: int) -> Array:
	var out: Array = []
	var kind := String(run.nodes[index]["kind"])
	for door in sign_doors(layout, layout.room_of_node(index)):
		var root := Node3D.new()
		root.name = "RoomSign%d" % index
		root.set_meta("node_index", index)
		var direction: Vector2i = door["direction"]
		# At shoulder height beside the lane; no collider or new light.
		root.position = Kit.cell_to_world(door["cell"]) + Vector3(float(-direction.y) * 0.9, 1.5, float(direction.x) * 0.9)
		var symbol := Sprite3D.new()
		symbol.texture = RoomPresentation.icon(kind)
		symbol.pixel_size = 0.0014
		symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		symbol.modulate = RoomPresentation.accent(kind)
		symbol.shaded = false
		root.add_child(symbol)
		var text := Label3D.new()
		text.name = "Caption"
		text.font = UiTheme.body_font()
		text.font_size = 48
		text.pixel_size = 0.006
		text.outline_size = 12
		text.position.y = -0.56
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.modulate = RoomPresentation.accent(kind)
		root.add_child(text)
		parent.add_child(root)
		refresh(root, run)
		out.append(root)
	if kind == "shop":
		merchant(parent, Kit.cell_to_world(service_cell(layout, layout.room_of_node(index))), run.content)
	return out


static func refresh(sign: Node3D, run: RunState) -> void:
	var index := int(sign.get_meta("node_index"))
	var text := sign.get_node("Caption") as Label3D
	text.text = RoomPresentation.label(run.content, String(run.nodes[index]["kind"])) + " · " + str(index + 1)
	text.text += "\n" + run.content.text("room.state." + RoomPresentation.availability(run, index))


static func merchant(parent: Node3D, at: Vector3, content: Content) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.14, 0.08)
	wood.roughness = 0.85
	var body := StaticBody3D.new()
	body.name = "MerchantCounter"
	body.position = at + Vector3(0, 0.48, 0)
	body.collision_layer = DungeonBuilder.LAYER_WORLD
	body.collision_mask = 0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7, 0.95, 0.65)
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = wood
	body.add_child(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	var caption := Label3D.new()
	caption.text = content.text("room.engage").replace("{room}", content.text("room.shop.name"))
	caption.font_size = 42
	caption.pixel_size = 0.006
	caption.position = at + Vector3(0, 1.8, 0)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = RoomPresentation.accent("shop")
	parent.add_child(caption)
