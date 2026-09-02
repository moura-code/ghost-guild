class_name Legend
extends RefCounted
## One prestige cycle's dead, merged (spec §6.1).
##
## A Legend is a memorial rather than a deletion, and that is not decoration:
## it is why `epitaphs` is on the record at all. The ladder is wiped when a
## Legend is forged, and if the only thing that survived were a multiplier then
## prestige would be a button that makes numbers bigger. What survives is a
## named person, everyone they were made of, and what they were worth.

var id: int = 0
## The deepest of the dead it was made from. A Legend is made of people; it
## should be called after one.
var name: String = ""
## Which prestige this was. Cycle 1 is the first.
var cycle: int = 1
## The total strength merged into it -- see `Legends.mass`.
var mass: float = 0.0
## What it multiplies: ghost strength, and hero damage and block (§4.4).
var multiplier: float = 1.0
## The dominant card tag across the merged decks, or "" for a Legend forged
## from nobody. Drives the trait.
var trait_tag: String = ""
## One `{name, floor, epitaph}` per ghost merged, oldest first. The Hall shows
## these; nothing else reads them.
var epitaphs: Array = []
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"cycle": cycle,
		"mass": mass,
		"multiplier": multiplier,
		"trait_tag": trait_tag,
		"epitaphs": epitaphs.duplicate(true),
		"created_at": created_at,
	}


static func from_dict(d: Dictionary) -> Legend:
	var l := Legend.new()
	l.id = int(d.get("id", 0))
	l.name = String(d.get("name", ""))
	l.cycle = int(d.get("cycle", 1))
	l.mass = float(d.get("mass", 0.0))
	l.multiplier = float(d.get("multiplier", 1.0))
	l.trait_tag = String(d.get("trait_tag", ""))
	var raw: Array = d.get("epitaphs", [])
	l.epitaphs = raw.duplicate(true)
	l.created_at = int(d.get("created_at", 0))
	return l
