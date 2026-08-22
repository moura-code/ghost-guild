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
