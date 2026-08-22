class_name BiomeDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var first_floor: int = 1
var last_floor: int = 10
var card_pool: String = ""
var encounters: Array = []
var elites: Array = []
var boss: Array[String] = []
var node_patterns: Array = []


static func from_dict(d: Dictionary) -> BiomeDef:
	var b := BiomeDef.new()
	b.id = String(d.get("id", ""))
	b.name_key = String(d.get("name", ""))
	var floors: Array = d.get("floors", [1, 10])
	b.first_floor = int(floors[0])
	b.last_floor = int(floors[1])
	b.card_pool = String(d.get("card_pool", b.id))
	var enc: Array = d.get("encounters", [])
	b.encounters = enc.duplicate(true)
	var el: Array = d.get("elites", [])
	b.elites = el.duplicate(true)
	for enemy_id in d.get("boss", []):
		b.boss.append(String(enemy_id))
	var patterns: Array = d.get("node_patterns", [])
	b.node_patterns = patterns.duplicate(true)
	return b
