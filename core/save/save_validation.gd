class_name SaveValidation
extends RefCounted
## Validate untrusted JSON before any typed from_dict constructor is called.

const OBJECTS := ["hero", "run", "ladder", "upgrades", "onboarding", "stats", "stat_bonus", "reward", "shop", "outcome", "levels", "measured", "chapters", "picks_taken", "fight", "rng", "streams", "statuses", "ghost", "layout_snapshot"]
const ARRAYS := ["deck", "relics", "rules", "ghosts", "nodes", "resolved", "descent_offers", "cards", "enemies", "used_events", "claimed_pools", "claimed_biomes", "expeditions", "legends", "epitaphs", "compendium", "draw_pile", "hand", "discard_pile", "exhaust_pile", "room_records", "previous_presets"]
const NUMBERS := ["version", "campaign_seed", "run_seed", "last_tick", "created_at", "soul", "coin", "rate_per_hour", "record_depth", "hero_counter", "run_counter", "expedition_counter", "id", "uid", "floor", "entry_floor", "node_index", "fight_counter", "max_hp", "hp", "strength", "next_uid", "next_ghost_id", "source_id", "resolve", "max_resolve", "camp", "runs", "started_at", "seconds", "survival", "ink", "seal", "blessing", "hero_hp", "hero_max_hp", "hero_block", "energy", "max_energy", "draw_per_turn", "turn", "tier", "pattern_index", "cards_played_this_turn", "pending_x", "block"]


static func check(content: Content, raw: Variant) -> String:
	if not raw is Dictionary:
		return "invalid"
	var d: Dictionary = raw
	if not _numeric(d.get("version", 0)):
		return "invalid"
	if float(d.get("version", 0)) < 0 or float(d.get("version", 0)) != floorf(float(d.get("version", 0))):
		return "invalid"
	if int(d.get("version", 0)) > SaveGame.VERSION:
		return "future"
	if not d.has("campaign_seed") or not d.has("hero") or not d.has("ladder") or not d.has("last_tick"):
		return "invalid"
	if not _shape(d):
		return "invalid"
	if not _references(content, d):
		return "content"
	var hero: Dictionary = d["hero"]
	if not _hero(hero) or not (d["ladder"].get("ghosts", []) is Array):
		return "invalid"
	var ids: Dictionary = {}
	for ghost in d["ladder"].get("ghosts", []):
		if not ghost is Dictionary or not _hero(ghost) or int(ghost.get("floor", 0)) < 1:
			return "invalid"
		var id := int(ghost.get("id", 0))
		if id <= 0 or ids.has(id):
			return "invalid"
		ids[id] = true
	for expedition in d.get("expeditions", []):
		if not _hero(expedition.get("ghost", {})) or int(expedition["ghost"].get("floor", 0)) < 1:
			return "invalid"
	var run: Dictionary = d.get("run", {})
	if not run.is_empty():
		if not _hero(run.get("hero", {})) or int(run.get("floor", 0)) < 1:
			return "invalid"
		var phase := String(run.get("phase", ""))
		if not phase in ["descent", "node", "fight", "reward", "event", "shop", "rest", "exit", "ended"]:
			return "invalid"
		if phase == "descent" and run.get("descent_offers", []).is_empty():
			return "invalid"
		if phase == "event" and not content.events.has(run.get("event_id", "")):
			return "content"
		if phase == "fight" and (run.get("fight", {}).is_empty() or run["fight"].get("enemies", []).is_empty()):
			return "invalid"
		if phase == "fight" and not _fight(content, run["fight"]):
			return "invalid"
		for row in run.get("stats", {}).values():
			if not row is Dictionary or not _numeric_map(row):
				return "invalid"
		var nodes: Array = run.get("nodes", [])
		if phase not in ["descent", "ended"] and nodes.is_empty():
			return "invalid"
		for node in nodes:
			if not node is Dictionary or not String(node.get("kind", "")) in ["fight", "elite", "boss", "event", "shop", "rest"]:
				return "invalid"
			if node.get("kind", "") in ["fight", "elite", "boss"] and node.get("enemies", []).is_empty():
				return "invalid"
			if node.get("kind", "") == "event" and not content.events.has(node.get("event", "")):
				return "content"
			for enemy in node.get("enemies", []):
				if not enemy is String:
					return "invalid"
		if (int(d.get("version", 0)) >= 4 or run.has("room_records")) and not _rooms(run):
			return "invalid"
		if not _layout(run.get("layout_snapshot", {}), nodes.size()):
			return "invalid"
		if not _integer(run.get("action_revision", 0), 0, 2147483647):
			return "invalid"
		var index := int(run.get("node_index", 0))
		if index < 0 or (phase not in ["descent", "ended", "exit"] and index >= nodes.size()):
			return "invalid"
	return ""


static func _numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _hero(d: Dictionary) -> bool:
	return not d.is_empty() and d.get("name", null) is String and d.get("class_id", null) is String \
		and int(d.get("max_hp", 0)) > 0 and d.get("deck", null) is Array and _numeric_map(d.get("stats", {}))


static func _numeric_map(d: Dictionary) -> bool:
	for value in d.values():
		if not _numeric(value):
			return false
	return true


static func _fight(content: Content, d: Dictionary) -> bool:
	if not d.get("phase", "") in ["player", "won", "lost"] or not _numeric_map(d.get("stats", {})):
		return false
	if int(d.get("hero_max_hp", 0)) <= 0 or not d.has("rng"):
		return false
	for enemy in d.get("enemies", []):
		if not enemy is Dictionary or not enemy.has("def_id") or int(enemy.get("max_hp", 0)) <= 0:
			return false
		var def: EnemyDef = content.enemies[enemy["def_id"]]
		for key in ["last_move", "next_move"]:
			var move := String(enemy.get(key, ""))
			if move != "" and not def.moves.has(move):
				return false
	var rng: Dictionary = d["rng"]
	if not _rng_integer(rng.get("seed")):
		return false
	for stream in rng.get("streams", {}).values():
		if not stream is Dictionary or not _rng_integer(stream.get("seed")) or not _rng_integer(stream.get("state")):
			return false
	return true


static func _rng_integer(value: Variant) -> bool:
	return value is String and value.is_valid_int()


static func _shape(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value is Array:
		if value.size() > 100000:
			return false
		for item in value:
			if not _shape(item, depth + 1):
				return false
	elif value is Dictionary:
		for key in value:
			var item: Variant = value[key]
			# Stream names can be "deck" or "enemies"; they are not card
			# piles or encounter arrays at this location in the document.
			if str(key) == "streams":
				if not item is Dictionary:
					return false
				for stream in item.values():
					if not stream is Dictionary or not _rng_integer(stream.get("seed")) or not _rng_integer(stream.get("state")):
						return false
				continue
			if OBJECTS.has(key) and not item is Dictionary:
				return false
			if ARRAYS.has(key) and not item is Array:
				return false
			if NUMBERS.has(key) and not _numeric(item):
				return false
			if key in ["might", "wit", "vigor", "focus", "fights", "wins", "turns", "win_rate", "avg_turns", "card_price", "relic_price", "removal_price", "cycle", "mass", "multiplier", "invoked_legend"] and not _numeric(item):
				return false
			if key in ["statuses", "levels", "chapters", "stat_bonus", "measured"] and not _numeric_map(item):
				return false
			if key in ["class_id", "def_id", "name", "phase", "kind", "event_id", "epitaph_key", "trait_tag", "cause", "killer", "epitaph", "last_move", "next_move", "relic", "event"] and not item is String:
				return false
			if key in ["upgraded", "alive", "prepared", "restless", "fixed_strength", "removed", "watch_unlocked", "first_death_seen", "free_tend_available", "founder_seeded", "legacy_floor", "floor_clear_emitted", "visited", "encounter_resolved", "required", "available"] and not item is bool:
				return false
			if key in ["deck", "ghosts", "nodes", "descent_offers", "expeditions", "legends", "epitaphs", "draw_pile", "hand", "discard_pile", "exhaust_pile"]:
				for entry in item:
					if not entry is Dictionary:
						return false
					if key in ["deck", "draw_pile", "hand", "discard_pile", "exhaust_pile"] and (not entry.has("uid") or not entry.has("def_id")):
						return false
			if key in ["resolved", "picks_taken"]:
				for flag in (item.values() if item is Dictionary else item):
					if not flag is bool:
						return false
			if not _shape(item, depth + 1):
				return false
	elif value is float and not is_finite(value):
		return false
	return true


static func _references(content: Content, value: Variant, category: String = "") -> bool:
	if value is Array:
		for item in value:
			if not _references(content, item, category):
				return false
	elif value is Dictionary:
		if value.has("class_id") and not content.classes.has(value["class_id"]):
			return false
		if value.has("def_id"):
			var defs := content.enemies if category == "enemies" else content.cards
			if not defs.has(value["def_id"]):
				return false
		if value.has("relic") and value["relic"] != "" and not content.relics.has(value["relic"]):
			return false
		if category in ["levels", "chapters"]:
			var definitions := content.upgrades if category == "levels" else content.chapters
			for key in value:
				if not definitions.has(key):
					return false
		for key in value:
			if not _references(content, value[key], str(key)):
				return false
	elif category in ["relics", "compendium", "cards", "rules", "enemies", "used_events", "claimed_biomes", "claimed_pools"]:
		if not value is String:
			return false
		match category:
			"relics", "compendium": return content.relics.has(value)
			"cards": return content.cards.has(value)
			"rules": return content.rules.has(value)
			"enemies": return content.enemies.has(value)
			"used_events": return content.events.has(value)
			"claimed_biomes": return content.biomes.has(value)
	return true


static func _rooms(run: Dictionary) -> bool:
	var records: Array = run.get("room_records", [])
	var nodes: Array = run.get("nodes", [])
	if records.size() != nodes.size():
		return false
	for i in records.size():
		if not records[i] is Dictionary:
			return false
		var room: Dictionary = records[i]
		if room.get("room_id") != "%d:%d" % [int(run.get("floor", 0)), i]:
			return false
		for key in ["visited", "encounter_resolved", "required", "available"]:
			if not room.get(key) is bool:
				return false
		if room["encounter_resolved"] and not room["visited"]:
			return false
		if room["required"] != bool(nodes[i].get("required", true)) and not bool(run.get("legacy_floor", false)):
			return false
		var stock: Dictionary = room.get("shop", {})
		if not stock.is_empty():
			if nodes[i].get("kind") != "shop" or not stock.get("cards") is Array or not stock.get("relic") is String or not stock.get("removed") is bool:
				return false
			for key in ["card_price", "relic_price", "removal_price"]:
				if not _numeric(stock.get(key)) or float(stock[key]) < 0 or float(stock[key]) != floorf(float(stock[key])):
					return false
		if nodes[i].get("kind") != "shop" and room["available"]:
			return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _numeric(value) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high


static func _layout(d: Dictionary, node_count: int) -> bool:
	if d.is_empty():
		return true # Legacy floors retain their original deterministic generator.
	for key in ["width", "height"]:
		if not _integer(d.get(key), 3, 128):
			return false
	if not _integer(d.get("generator_version"), 1, 2):
		return false
	var w := int(d["width"])
	var h := int(d["height"])
	if not d.get("cells") is Array or d["cells"].size() != w * h:
		return false
	for cell in d["cells"]:
		if not _integer(cell, 0, 2):
			return false
	if not d.get("rooms") is Array or d["rooms"].size() != node_count + 2:
		return false
	for room in d["rooms"]:
		if not room is Dictionary:
			return false
		for key in ["x", "y", "w", "h"]:
			if not _integer(room.get(key), 1, 128):
				return false
		if room["x"] + room["w"] >= w or room["y"] + room["h"] >= h:
			return false
		for y in range(int(room["y"]), int(room["y"] + room["h"])):
			for x in range(int(room["x"]), int(room["x"] + room["w"])):
				if int(d["cells"][y * w + x]) != FloorLayout.Cell.FLOOR:
					return false
	var used := {}
	for key in ["entry_room", "stairs_room"]:
		if not _integer(d.get(key), 0, node_count + 1) or used.has(int(d[key])):
			return false
		used[int(d[key])] = true
	if not d.get("node_rooms") is Array or d["node_rooms"].size() != node_count:
		return false
	for room in d["node_rooms"]:
		if not _integer(room, 0, node_count + 1) or used.has(int(room)):
			return false
		used[int(room)] = true
	for key in ["torch_anchors", "ghost_anchors"]:
		if not d.get(key) is Array:
			return false
		for cell in d[key]:
			if not cell is Array or cell.size() != 2 or not _integer(cell[0], 0, w - 1) or not _integer(cell[1], 0, h - 1):
				return false
	if not d.get("presets") is Array or d["presets"].size() != d["rooms"].size():
		return false
	for id in d["presets"]:
		if not id is String:
			return false
	return true
