class_name CardInstance
extends RefCounted
## One physical card in a deck. uid is unique within a hero's lifetime.

var uid: int = 0
var def_id: String = ""
var upgraded: bool = false


func _init(p_uid: int = 0, p_def_id: String = "", p_upgraded: bool = false) -> void:
	uid = p_uid
	def_id = p_def_id
	upgraded = p_upgraded


func clone() -> CardInstance:
	return CardInstance.new(uid, def_id, upgraded)


func to_dict() -> Dictionary:
	return {"uid": uid, "def_id": def_id, "upgraded": upgraded}


static func from_dict(d: Dictionary) -> CardInstance:
	return CardInstance.new(int(d.get("uid", 0)), String(d.get("def_id", "")), bool(d.get("upgraded", false)))
