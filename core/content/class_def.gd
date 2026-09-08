class_name ClassDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var base_hp: int = 70
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var starting_deck: Array[String] = []
var relic: String = ""
var pool: String = ""
## The biome whose claim opens this class (spec §5.6), or "" for the class the
## guild starts with. See `Classes`.
var unlocked_by: String = ""


static func from_dict(d: Dictionary) -> ClassDef:
	var c := ClassDef.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name", ""))
	c.base_hp = int(d.get("base_hp", 70))
	var s: Dictionary = d.get("stats", {})
	for key in ["might", "wit", "vigor", "focus"]:
		c.stats[key] = int(s.get(key, 0))
	for card_id in d.get("starting_deck", []):
		c.starting_deck.append(String(card_id))
	c.relic = String(d.get("relic", ""))
	c.pool = String(d.get("pool", c.id))
	c.unlocked_by = String(d.get("unlocked_by", ""))
	return c
