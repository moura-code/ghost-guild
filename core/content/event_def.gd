class_name EventDef
extends RefCounted
## An authored event node: text plus two or three choices, each a list of
## run effect ops (see ContentValidator.RUN_OPS).

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var biome: String = ""
var choices: Array = []


static func from_dict(d: Dictionary) -> EventDef:
	var e := EventDef.new()
	e.id = String(d.get("id", ""))
	e.name_key = String(d.get("name", ""))
	e.text_key = String(d.get("text", ""))
	e.biome = String(d.get("biome", ""))
	var raw: Array = d.get("choices", [])
	e.choices = raw.duplicate(true)
	return e
