class_name RelicDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var hooks: Dictionary = {}


static func from_dict(d: Dictionary) -> RelicDef:
	var r := RelicDef.new()
	r.id = String(d.get("id", ""))
	r.name_key = String(d.get("name", ""))
	r.text_key = String(d.get("text", ""))
	var h: Dictionary = d.get("hooks", {})
	r.hooks = h.duplicate(true)
	return r
