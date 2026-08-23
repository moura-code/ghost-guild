class_name FloorGenerator
extends RefCounted
## Builds one floor: a node pattern from the biome's table, resolved into
## concrete nodes. The last node of the biome's last floor is the boss
## (spec §3.1). Uses the "encounter" rng stream only.


static func generate(content: Content, biome: BiomeDef, floor: int, rng: Rng, used_events: Array = []) -> Array:
	var patterns: Array = biome.node_patterns
	var pattern: Array = patterns[rng.randi_range("encounter", 0, patterns.size() - 1)]
	var nodes: Array = []
	var used: Array = used_events.duplicate()
	for i in pattern.size():
		var kind := String(pattern[i])
		if floor == biome.last_floor and i == pattern.size() - 1:
			nodes.append({"kind": "boss", "enemies": biome.boss.duplicate()})
			continue
		match kind:
			"fight":
				nodes.append({"kind": "fight", "enemies": encounter_for(biome, floor, rng)})
			"elite":
				var group: Array = biome.elites[rng.randi_range("encounter", 0, biome.elites.size() - 1)]
				nodes.append({"kind": "elite", "enemies": group.duplicate()})
			"event":
				var event_id := pick_event(content, biome.id, used, rng)
				if event_id == "":
					nodes.append({"kind": "rest"})
				else:
					used.append(event_id)
					nodes.append({"kind": "event", "event": event_id})
			_:
				nodes.append({"kind": kind})
	return nodes


static func groups_for(biome: BiomeDef, floor: int) -> Array:
	var groups: Array = []
	for bucket in biome.encounters:
		var span: Array = bucket.get("floors", [1, 1])
		if floor >= int(span[0]) and floor <= int(span[1]):
			groups = bucket.get("groups", [])
			break
	if groups.is_empty() and not biome.encounters.is_empty():
		var last: Dictionary = biome.encounters[biome.encounters.size() - 1]
		groups = last.get("groups", [])
	return groups.duplicate(true)


static func encounter_for(biome: BiomeDef, floor: int, rng: Rng) -> Array:
	var groups := groups_for(biome, floor)
	var group: Array = groups[rng.randi_range("encounter", 0, groups.size() - 1)]
	return group.duplicate()


static func pick_event(content: Content, biome_id: String, used: Array, rng: Rng) -> String:
	var keys: Array = content.events.keys()
	keys.sort()
	var candidates: Array = []
	for id in keys:
		var ev: EventDef = content.events[id]
		if (ev.biome == "" or ev.biome == biome_id) and not used.has(id):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	return String(rng.pick("encounter", candidates))
