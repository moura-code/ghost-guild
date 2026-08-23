class_name UpgradeDef
extends RefCounted
## A meta upgrade node in the Guild panel (spec §5.9): one effect, levels
## with exponential cost.

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var group: String = "hero"
var effect: Dictionary = {}
var max_level: int = 1
var base_cost: float = 10.0
var cost_growth: float = 1.6


static func from_dict(d: Dictionary) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = String(d.get("id", ""))
	u.name_key = String(d.get("name", ""))
	u.text_key = String(d.get("text", ""))
	u.group = String(d.get("group", "hero"))
	var e: Dictionary = d.get("effect", {})
	u.effect = e.duplicate(true)
	u.max_level = int(d.get("max_level", 1))
	u.base_cost = float(d.get("base_cost", 10.0))
	u.cost_growth = float(d.get("cost_growth", 1.6))
	return u
