class_name EnemyDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var biome: String = ""
var tags: Array[String] = []
var hp: int = 1
var moves: Dictionary = {}
var pattern: Dictionary = {}
var kind: String = "regular"


static func from_dict(d: Dictionary) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = String(d.get("id", ""))
	e.name_key = String(d.get("name", ""))
	e.biome = String(d.get("biome", ""))
	for t in d.get("tags", []):
		e.tags.append(String(t))
	e.hp = int(d.get("hp", 1))
	for m in d.get("moves", []):
		var move: Dictionary = m
		e.moves[String(move.get("id", ""))] = move.duplicate(true)
	var p: Dictionary = d.get("pattern", {})
	e.pattern = p.duplicate(true)
	e.kind = String(d.get("kind", "regular"))
	return e
