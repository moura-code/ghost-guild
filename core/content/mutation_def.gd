class_name MutationDef
extends RefCounted
## One rule that applies to every fight on a tier's worth of floors (spec §2:
## "one mutation modifier per tier").
##
## Deliberately a *rule* rather than a difficulty knob. "Enemies have 30% more
## HP" is a bigger number and changes nothing about how a fight is played;
## "every enemy starts with 3 Thorns" is something you have to play around.
## `behavioural` records which kind a mutation is, and a test asserts most of
## them are the second kind -- otherwise a tier is the same floors again with a
## bigger number on them, which is exactly what tier cycling was written to
## avoid.

## The effects a mutation may have, each one a hook the fight engine already
## has. Kept small on purpose: a vocabulary that grows per mutation is a
## vocabulary nobody can balance.
const OPS: Array[String] = [
	"enemy_status",   # every enemy starts the fight with a status
	"hero_status",    # the hero does
	"hero_draw",      # +/- cards drawn each turn
	"hero_energy",    # +/- energy each turn
	"enemy_hp",       # a multiplier on enemy HP -- the one numeric one
]

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var op: String = ""
## For the status ops.
var status: String = ""
var stacks: int = 0
## For the numeric ops.
var amount: float = 0.0
## Whether this changes how a fight is played rather than only how long it
## takes. Authored rather than inferred: `enemy_hp` is numeric by nature but a
## future op might be either.
var behavioural: bool = true


static func from_dict(d: Dictionary) -> MutationDef:
	var m := MutationDef.new()
	m.id = String(d.get("id", ""))
	m.name_key = String(d.get("name", ""))
	m.text_key = String(d.get("text", ""))
	m.op = String(d.get("op", ""))
	m.status = String(d.get("status", ""))
	m.stacks = int(d.get("stacks", 0))
	m.amount = float(d.get("amount", 0.0))
	m.behavioural = bool(d.get("behavioural", m.op != "enemy_hp"))
	return m
