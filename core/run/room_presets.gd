class_name RoomPresets
extends RefCounted
## Pure role/size selection. Recipes name presentation features, never scenes.

static func choose(content: Content, layout: FloorLayout, nodes: Array, biome: String, rng: Rng, previous: Array = []) -> Array:
	var out: Array = []
	var counts := {}
	var ids := content.room_presets.keys()
	ids.sort()
	for i in layout.rooms.size():
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
			var weight := maxi(1, int(recipe.get("weight", 3)) - (2 if previous.has(id) else 0))
			for _n in weight:
				weighted.append(id)
		var selected := String(rng.pick("presets", weighted)) if not weighted.is_empty() else "neutral"
		out.append(selected)
		counts[selected] = int(counts.get(selected, 0)) + 1
	return out


static func validate(content: Content) -> Array[String]:
	var errors: Array[String] = []
	for id in content.room_presets:
		var recipe: Dictionary = content.room_presets[id]
		if not content.biomes.has(recipe.get("biome")) or not recipe.get("roles") is Array or recipe.get("roles", []).is_empty():
			errors.append("invalid room preset roles/biome: " + str(id))
		if int(recipe.get("min_size", 0)) < 3 or int(recipe.get("min_size", 0)) > LayoutGenerator.ROOM_MAX:
			errors.append("invalid room preset dimensions: " + str(id))
		if not recipe.get("composition", "") in ["aisle", "vault", "ossuary", "ritual", "workroom", "merchant", "garden", "roots", "cistern", "furnace", "gantry", "foundry"]:
			errors.append("unknown room composition: " + str(id))
		if int(recipe.get("light_budget", -1)) < 0 or int(recipe.get("light_budget", -1)) > 1 or int(recipe.get("ambient_budget", -1)) < 0 or int(recipe.get("ambient_budget", -1)) > 8:
			errors.append("invalid room preset budget: " + str(id))
	return errors
