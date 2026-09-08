class_name FloorGenerator
extends RefCounted
## Builds one floor: a node pattern from the biome's table, resolved into
## concrete nodes. The last node of the biome's last floor is the boss
## (spec §3.1). Uses the "encounter" rng stream only.
##
## **Everything a biome authors is indexed within its own tier.** A biome's
## `first_floor`, `last_floor` and encounter buckets were written when floor
## numbers stopped at thirty; the descent cycles for ever now (§2), so an
## absolute floor has to be folded back into its tier before it is compared
## against any of them. It was not, and two things broke silently: floor 40
## had no boss, and every floor past thirty drew from the last bucket of its
## biome -- so tier 2 opened with the hardest Catacombs group at tier-2
## scaling and had no encounter variety at all.


static func generate(content: Content, biome: BiomeDef, floor: int, rng: Rng, used_events: Array = []) -> Array:
	var patterns: Array = biome.node_patterns
	var pattern: Array = patterns[rng.randi_range("encounter", 0, patterns.size() - 1)]
	var nodes: Array = []
	var used: Array = used_events.duplicate()
	# The floor as its biome authored it: 1..depth, whatever tier we are in.
	var here := Biomes.in_tier(content, floor)
	for i in pattern.size():
		var kind := String(pattern[i])
		if here == biome.last_floor and i == pattern.size() - 1:
			nodes.append({"kind": "boss", "enemies": biome.boss.duplicate()})
			continue
		match kind:
			"fight":
				nodes.append({"kind": "fight", "enemies": encounter_for(biome, here, rng)})
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


## The encounter groups for a floor. `in_tier_floor` is the floor **within its
## own tier** -- see the note at the top of this file. Passing an absolute
## floor past the authored depth matches no bucket and falls through to the
## deepest one, which is a real bug wearing a sensible-looking fallback.
static func groups_for(biome: BiomeDef, in_tier_floor: int) -> Array:
	var groups: Array = []
	for bucket in biome.encounters:
		var span: Array = bucket.get("floors", [1, 1])
		if in_tier_floor >= int(span[0]) and in_tier_floor <= int(span[1]):
			groups = bucket.get("groups", [])
			break
	if groups.is_empty() and not biome.encounters.is_empty():
		var last: Dictionary = biome.encounters[biome.encounters.size() - 1]
		groups = last.get("groups", [])
	return groups.duplicate(true)


static func encounter_for(biome: BiomeDef, in_tier_floor: int, rng: Rng) -> Array:
	var groups := groups_for(biome, in_tier_floor)
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
