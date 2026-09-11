class_name RoomPresets
extends RefCounted
## Pure role/size selection. Recipes name presentation features, never scenes.

static func choose(content: Content, layout: FloorLayout, nodes: Array, biome: String, rng: Rng, previous: Array = []) -> Array:
	var out: Array = []
	out.resize(layout.rooms.size())
	out.fill("neutral")
	var order: Array = range(layout.rooms.size())
	# Reserve scarce elite/boss recipes before the flexible normal rooms.
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := _priority(layout, nodes, a)
		var pb := _priority(layout, nodes, b)
		return pa < pb if pa != pb else a < b)
	var counts := {}
	var ids := content.room_presets.keys()
	ids.sort()
	for i in order:
		var node_index := layout.node_rooms.find(i)
		var role := String(nodes[node_index]["kind"]) if node_index >= 0 else ("entry" if i == layout.entry_room else "stairs")
		var room := layout.room_rect(i)
		var weighted: Array = []
		for id in ids:
			var recipe: Dictionary = content.room_presets[id]
			if recipe.get("biome") != biome or not recipe.get("roles", []).has(role):
				continue
			if int(room["w"]) < int(recipe.get("min_size", 3)) or int(room["h"]) < int(recipe.get("min_size", 3)) or int(counts.get(id, 0)) >= int(recipe.get("repeat_limit", 1)):
				continue
			if int(room["w"]) > int(recipe.get("max_size", LayoutGenerator.ROOM_MAX)) or int(room["h"]) > int(recipe.get("max_size", LayoutGenerator.ROOM_MAX)):
				continue
			var weight := maxi(1, int(recipe.get("weight", 3)) - (2 if previous.has(id) else 0))
			for _n in weight:
				weighted.append(id)
		var selected := String(rng.pick("presets", weighted)) if not weighted.is_empty() else "neutral"
		out[i] = selected
		counts[selected] = int(counts.get(selected, 0)) + 1
	return out


static func _priority(layout: FloorLayout, nodes: Array, room: int) -> int:
	var index := layout.node_rooms.find(room)
	if index < 0:
		return 4
	return 3 if nodes[index]["kind"] == "fight" else (0 if nodes[index]["kind"] in ["elite", "boss"] else 1)


static func validate(content: Content) -> Array[String]:
	var errors: Array[String] = []
	for id in content.room_presets:
		var recipe: Dictionary = content.room_presets[id]
		if not valid_recipe(recipe) or not content.biomes.has(recipe.get("biome")):
			errors.append("invalid room preset: " + str(id))
	return errors


static func valid_recipe(recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return true # Neutral fallback has no authored props or activity.
	for key in ["recipe_version", "min_size", "max_size", "weight", "repeat_limit", "light_budget", "ambient_budget", "walking_lane_cells", "combat_radius_cells"]:
		var value: Variant = recipe.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
			return false
	if recipe["recipe_version"] != 1 or recipe["min_size"] < 3 or recipe["max_size"] > LayoutGenerator.ROOM_MAX or recipe["max_size"] < recipe["min_size"]:
		return false
	if recipe["weight"] < 1 or recipe["weight"] > 20 or recipe["repeat_limit"] < 1 or recipe["repeat_limit"] > 9:
		return false
	if recipe["light_budget"] != 0 or recipe["ambient_budget"] < 0 or recipe["ambient_budget"] > 8:
		return false
	if recipe["walking_lane_cells"] != 1 or recipe["combat_radius_cells"] != 1:
		return false
	if not recipe.get("roles") is Array or recipe["roles"].is_empty():
		return false
	for role in recipe["roles"]:
		if not role in ["fight", "elite", "boss", "event", "rest", "shop"]:
			return false
	if not recipe.get("composition") in ["aisle", "vault", "ossuary", "ritual", "workroom", "merchant", "garden", "roots", "cistern", "furnace", "gantry", "foundry", "archive", "nursery", "cooling"]:
		return false
	return recipe.get("service_anchor") == "southeast" and recipe.get("ghost_anchor") == "center" \
		and recipe.get("prop_sockets") == "wall_only" and recipe.get("doorway_anchors") == "perimeter"


static func freeze(content: Content, ids: Array) -> Array:
	var out := []
	for id in ids:
		var recipe: Dictionary = content.room_presets.get(id, {}).duplicate(true)
		recipe.erase("id") # IDs are stored alongside recipes; save object IDs are numeric.
		out.append(recipe)
	return out
