class_name Upgrades
extends RefCounted
## Meta upgrade levels (spec §5.9) and the modifiers they produce. Prices
## grow ×cost_growth per level; the caller spends the Soul.

var levels: Dictionary = {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


static func cost_at(def: UpgradeDef, p_level: int) -> float:
	return def.base_cost * pow(def.cost_growth, p_level)


func cost(content: Content, id: String) -> float:
	if not content.upgrades.has(id):
		return -1.0
	var def: UpgradeDef = content.upgrades[id]
	if level(id) >= def.max_level:
		return -1.0
	return cost_at(def, level(id))


func can_buy(content: Content, id: String, soul: float) -> bool:
	var price := cost(content, id)
	return price >= 0.0 and soul >= price


func buy(content: Content, id: String) -> float:
	var price := cost(content, id)
	if price < 0.0:
		return -1.0
	levels[id] = level(id) + 1
	return price


func modifiers(content: Content) -> Dictionary:
	var m := {
		"global_strength": 1.0,
		"global_spawn": 1.0,
		"restless_penalty": float(content.balance.get("restless_penalty", 0.3)),
		"offline_cap_hours": float(content.balance.get("offline_cap_hours", 8)),
		"mend_discount": 0.0,
		"max_resolve_bonus": 0,
		"stats": {"might": 0, "wit": 0, "vigor": 0, "focus": 0},
	}
	for id in levels:
		var n := int(levels[id])
		if n <= 0 or not content.upgrades.has(id):
			continue
		var def: UpgradeDef = content.upgrades[id]
		var amount := float(def.effect.get("amount", 0)) * n
		match String(def.effect.get("kind", "")):
			"stat":
				var stat := String(def.effect.get("stat", ""))
				m["stats"][stat] = int(m["stats"].get(stat, 0)) + int(amount)
			"max_resolve":
				m["max_resolve_bonus"] = int(m["max_resolve_bonus"]) + int(amount)
			"mend_discount":
				m["mend_discount"] = minf(0.9, float(m["mend_discount"]) + amount)
			"global_strength":
				m["global_strength"] = float(m["global_strength"]) + amount
			"global_spawn":
				m["global_spawn"] = float(m["global_spawn"]) + amount
			"offline_cap":
				m["offline_cap_hours"] = float(m["offline_cap_hours"]) + amount
			"restless_penalty":
				m["restless_penalty"] = maxf(0.0, float(m["restless_penalty"]) - amount)
	return m


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate()}


static func from_dict(d: Dictionary) -> Upgrades:
	var u := Upgrades.new()
	var raw: Dictionary = d.get("levels", {})
	for id in raw:
		u.levels[String(id)] = int(raw[id])
	return u
