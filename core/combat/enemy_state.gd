class_name EnemyState
extends RefCounted

var def_id: String = ""
var hp: int = 1
var max_hp: int = 1
var block: int = 0
var statuses: Dictionary = {}
var pattern_index: int = 0
var last_move: String = ""
var next_move: String = ""
var alive: bool = true


func status(name: String) -> int:
	return int(statuses.get(name, 0))


func clone() -> EnemyState:
	var e := EnemyState.new()
	e.def_id = def_id
	e.hp = hp
	e.max_hp = max_hp
	e.block = block
	e.statuses = statuses.duplicate()
	e.pattern_index = pattern_index
	e.last_move = last_move
	e.next_move = next_move
	e.alive = alive
	return e


func to_dict() -> Dictionary:
	return {"def_id": def_id, "hp": hp, "max_hp": max_hp, "block": block,
		"statuses": statuses.duplicate(), "pattern_index": pattern_index,
		"last_move": last_move, "next_move": next_move, "alive": alive}


static func from_dict(d: Dictionary) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.def_id = String(d["def_id"])
	for key in ["hp", "max_hp", "block", "pattern_index"]:
		enemy.set(key, int(d.get(key, 0)))
	enemy.statuses = d.get("statuses", {}).duplicate()
	enemy.last_move = String(d.get("last_move", ""))
	enemy.next_move = String(d.get("next_move", ""))
	enemy.alive = bool(d.get("alive", true))
	return enemy
