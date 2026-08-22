class_name CardDef
extends RefCounted
## Immutable description of a card, loaded from JSON.

const COST_X := -1
const COST_UNCHANGED := -2

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var pool: String = "neutral"
var type: String = "attack"
var cost: int = 1
var rarity: String = "common"
var tags: Array[String] = []
var keywords: Array[String] = []
var target: String = "enemy"
var effects: Array = []
var upgrade_effects: Array = []
var upgrade_cost: int = COST_UNCHANGED
var ai_value: float = 0.0


static func from_dict(d: Dictionary) -> CardDef:
	var c := CardDef.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name", ""))
	c.text_key = String(d.get("text", ""))
	c.pool = String(d.get("pool", "neutral"))
	c.type = String(d.get("type", "attack"))
	c.cost = _parse_cost(d.get("cost", 1), 1)
	c.rarity = String(d.get("rarity", "common"))
	for t in d.get("tags", []):
		c.tags.append(String(t))
	for k in d.get("keywords", []):
		c.keywords.append(String(k))
	c.target = String(d.get("target", "enemy"))
	var fx: Array = d.get("effects", [])
	c.effects = fx.duplicate(true)
	var up: Dictionary = d.get("upgrade", {})
	var up_fx: Array = up.get("effects", fx)
	c.upgrade_effects = up_fx.duplicate(true)
	c.upgrade_cost = _parse_cost(up.get("cost", COST_UNCHANGED), COST_UNCHANGED)
	c.ai_value = float(d.get("ai_value", 0.0))
	return c


static func _parse_cost(value: Variant, fallback: int) -> int:
	if value is String:
		return COST_X if String(value).to_lower() == "x" else fallback
	if value is float or value is int:
		return int(value)
	return fallback


func effects_for(upgraded: bool) -> Array:
	return upgrade_effects if upgraded else effects


func cost_for(upgraded: bool) -> int:
	if upgraded and upgrade_cost != COST_UNCHANGED:
		return upgrade_cost
	return cost


func has_keyword(k: String) -> bool:
	return keywords.has(k)
