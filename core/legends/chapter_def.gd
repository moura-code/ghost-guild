class_name ChapterDef
extends RefCounted
## One permanent thing Ink buys (spec §6.2, The Chronicle).
##
## A Chapter is not an upgrade. Upgrades are bought with Soul, reset nothing,
## and the guild buys all of them eventually; Chapters are bought with Ink,
## which only a prestige produces, so a Chapter costs a *cycle* and the guild
## will never own them all early. That is the whole point of a second layer:
## the first one makes numbers bigger and this one changes what a cycle is.
##
## Deliberately a closed vocabulary of four ops, same as mutations and traits.
## A prestige layer whose effects are open-ended is one nobody can balance
## against the layer underneath it.

const OPS: Array[String] = [
	"founder_floor",  # each cycle's Founder starts standing deeper
	"global_spawn",   # every floor is bigger
	"soul_kept",      # a fraction of Soul survives the rite
	"seals",          # unlocks opt-in difficulty that multiplies yield
]

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var op: String = ""
## Ink for the first level; each level after costs `cost` more than the last,
## because Ink arrives one per cycle and a doubling curve would mean the
## fourth level of anything is unreachable inside a human lifetime.
var cost: int = 1
var max_level: int = 1
## What one level is worth, in the op's own units.
var amount: float = 0.0


static func from_dict(d: Dictionary) -> ChapterDef:
	var c := ChapterDef.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name", ""))
	c.text_key = String(d.get("text", ""))
	c.op = String(d.get("op", ""))
	c.cost = int(d.get("cost", 1))
	c.max_level = int(d.get("max_level", 1))
	c.amount = float(d.get("amount", 0.0))
	return c


## Ink for the next level of this Chapter, given how many the guild owns.
## Linear: level n costs n times the base.
func cost_at(level: int) -> int:
	return cost * (level + 1)
