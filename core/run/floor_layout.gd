class_name FloorLayout
extends RefCounted
## The shape of one floor as data: a grid of cells, the rooms carved into it,
## which room holds which encounter, and where the dressing goes. Built by
## LayoutGenerator from a seed and read by the 3D builder, which owns the
## metres -- nothing here knows how big a cell is in the world, so the whole
## thing stays testable headless like the rest of core/.

enum Cell { VOID, FLOOR, WALL }

var width: int = 0
var height: int = 0
## Row-major, one byte per cell, holding a Cell value. VOID is 0, so a freshly
## resized grid is solid rock without a fill pass.
var cells: PackedByteArray = PackedByteArray()
## Grid rects: {"x": int, "y": int, "w": int, "h": int}.
var rooms: Array = []
var entry_room: int = -1
var stairs_room: int = -1
## node_rooms[node_index] -> index into rooms.
var node_rooms: Array = []
var torch_anchors: Array = []
var ghost_anchors: Array = []
var presets: Array = []
var preset_recipes: Array = []
var generator_version: int = 1


static func create(p_width: int, p_height: int) -> FloorLayout:
	var layout := FloorLayout.new()
	layout.width = maxi(0, p_width)
	layout.height = maxi(0, p_height)
	layout.cells.resize(layout.width * layout.height)
	return layout


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Outside the grid reads as VOID so callers can scan a neighbourhood without
## guarding every edge: the world behaves like solid rock past its own border.
func cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Cell.VOID
	return cells[y * width + x]


func set_cell(x: int, y: int, value: int) -> void:
	if in_bounds(x, y):
		cells[y * width + x] = value


func is_walkable(x: int, y: int) -> bool:
	return cell(x, y) == Cell.FLOOR


func room_rect(index: int) -> Dictionary:
	if index < 0 or index >= rooms.size():
		return {}
	return (rooms[index] as Dictionary).duplicate()


func room_center(index: int) -> Vector2i:
	if index < 0 or index >= rooms.size():
		return Vector2i.ZERO
	var r: Dictionary = rooms[index]
	return Vector2i(int(r["x"]) + int(r["w"]) / 2, int(r["y"]) + int(r["h"]) / 2)


func room_of_node(node_index: int) -> int:
	if node_index < 0 or node_index >= node_rooms.size():
		return -1
	return int(node_rooms[node_index])


## Every walkable cell reachable from `start`, as a set keyed by Vector2i.
## Orthogonal only -- a diagonal gap between two rooms is a wall you can see
## through, not a door you can walk through.
func reachable_from(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not is_walkable(start.x, start.y):
		return seen
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + step
			if seen.has(next) or not is_walkable(next.x, next.y):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func to_dict() -> Dictionary:
	var torches: Array = []
	var ghosts: Array = []
	for cell in torch_anchors:
		torches.append([cell.x, cell.y])
	for cell in ghost_anchors:
		ghosts.append([cell.x, cell.y])
	return {"generator_version": generator_version, "width": width, "height": height,
		"cells": Array(cells), "rooms": rooms.duplicate(true), "node_rooms": node_rooms.duplicate(),
		"entry_room": entry_room, "stairs_room": stairs_room, "torch_anchors": torches,
		"ghost_anchors": ghosts, "presets": presets.duplicate(), "preset_recipes": preset_recipes.duplicate(true)}


static func from_dict(d: Dictionary) -> FloorLayout:
	var layout := create(int(d["width"]), int(d["height"]))
	layout.generator_version = int(d.get("generator_version", 1))
	layout.cells = PackedByteArray(d["cells"])
	layout.rooms = (d["rooms"] as Array).duplicate(true)
	layout.node_rooms = (d["node_rooms"] as Array).duplicate()
	layout.entry_room = int(d["entry_room"])
	layout.stairs_room = int(d["stairs_room"])
	layout.presets = (d.get("presets", []) as Array).duplicate()
	layout.preset_recipes = (d.get("preset_recipes", []) as Array).duplicate(true)
	for cell in d.get("torch_anchors", []):
		layout.torch_anchors.append(Vector2i(int(cell[0]), int(cell[1])))
	for cell in d.get("ghost_anchors", []):
		layout.ghost_anchors.append(Vector2i(int(cell[0]), int(cell[1])))
	return layout
