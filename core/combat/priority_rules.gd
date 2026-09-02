class_name PriorityRules
extends RefCounted
## How a ghost fights (spec §3.3, §4.3).
##
## `Autopilot` scores a turn against a table of weights. A priority rule is a
## named bend in that table, and a ghost carries up to three of them. Compose
## the rules, hand the result to the autopilot, and every fight that ghost will
## ever simulate -- echoes, next-floor projections, tending deltas, Expeditions
## -- is played the way its owner chose.
##
## **An empty rule list is the identity.** That is not an accident of the
## arithmetic, it is the property the whole feature is built around: nothing in
## the game carries rules until a player picks some, so the balance simulator
## and both demos measure exactly the game they measured before.
##
## Order matters, deliberately. §3.3 says the player *orders* up to three
## rules, so position carries an influence factor: the first pick bends the
## scorer hardest, and the same three rules in a different order make a
## different ghost. Within one rule set the arithmetic is order-independent by
## construction (`base × Π mul + Σ add`), so the result depends on the order
## the player chose and on nothing else.

## Three, because the pick is meant to be a decision and not a checklist.
const MAX := 3
## What each position is worth. First choice dominates; third is a leaning.
const INFLUENCE := [1.0, 0.7, 0.45]

## Every weight a rule may bend.
##
## `death` and `lethal` are absent on purpose and the validator rejects them.
## They are what stop the autopilot from walking into a loss, and the 30-turn
## fight cap (spec §10) rests on them. A rule that could soften either is a
## rule that can hang every simulation in the game.
const ADJUSTABLE := [
	"damage", "kill",
	"block_useful", "block_excess", "unblocked",
	"hp_lost", "heal",
	"energy_left", "ai_value",
	"cards_drawn", "powers_played",
	"enemy_status.*", "enemy_status.poison", "enemy_status.vulnerable",
	"enemy_status.weak", "enemy_status.burn",
	"hero_status.*", "hero_status.might_buff", "hero_status.wit_buff",
	"hero_status.thorns", "hero_status.vigil", "hero_status.regen",
	"hero_status.knell",
]

## Weights that must stay penalties whatever the rules say. A positive
## `hp_lost` is an autopilot that seeks damage, and a positive `unblocked` is
## one that stands still to be hit; either turns a fight into a 30-turn cap
## hit, which is a hang with a stack trace.
const NEVER_POSITIVE := ["hp_lost", "unblocked"]


## Drops unknown ids and duplicates, keeps the player's order, and takes the
## first MAX. Content changes between saves -- a rule can be renamed or cut --
## and a save that names a rule that no longer exists must load, not fail.
static func normalize_ids(ids: Array, content: Content) -> Array[String]:
	var out: Array[String] = []
	for raw in ids:
		var id := String(raw)
		if out.size() >= MAX or out.has(id):
			continue
		if content != null and not content.rules.has(id):
			continue
		out.append(id)
	return out


## The weight table `base` becomes once `ids` are applied.
##
## `base` is never mutated: the autopilot's defaults are shared, and a ghost
## that edited them would change how every other ghost fights.
static func weights_for(base: Dictionary, ids: Array, content: Content) -> Dictionary:
	var out := base.duplicate(true)
	var chosen := normalize_ids(ids, content)
	if chosen.is_empty():
		return out
	for path in ADJUSTABLE:
		var name := String(path)
		if name.ends_with(".*"):
			continue
		if not _has(out, name):
			continue
		var mul := 1.0
		var add := 0.0
		for i in chosen.size():
			var rule: RuleDef = content.rules[chosen[i]]
			var influence := float(INFLUENCE[i]) if i < INFLUENCE.size() else 0.0
			# A multiplier at influence f is f of the way from 1.0 to itself,
			# so a half-weight rule is half as strong rather than half as
			# large -- and influence 0 is exactly no rule at all.
			mul *= 1.0 + (_mul_of(rule, name) - 1.0) * influence
			add += _add_of(rule, name) * influence
		var value := _read(out, name) * mul + add
		if NEVER_POSITIVE.has(name):
			value = minf(value, 0.0)
		_write(out, name, value)
	return out


## A rule's multiplier for one weight: its own entry times its group's
## wildcard, so `hero_status.*` can lift the whole group and a specific entry
## can still say more about one of them.
static func _mul_of(rule: RuleDef, path: String) -> float:
	return rule.mul_for(path) * rule.mul_for(_group_of(path))


static func _add_of(rule: RuleDef, path: String) -> float:
	return rule.add_for(path) + rule.add_for(_group_of(path))


static func _group_of(path: String) -> String:
	var dot := path.find(".")
	return "" if dot < 0 else path.substr(0, dot) + ".*"


static func _has(table: Dictionary, path: String) -> bool:
	var dot := path.find(".")
	if dot < 0:
		return table.has(path)
	var group: Dictionary = table.get(path.substr(0, dot), {})
	return group.has(path.substr(dot + 1))


static func _read(table: Dictionary, path: String) -> float:
	var dot := path.find(".")
	if dot < 0:
		return float(table[path])
	var group: Dictionary = table[path.substr(0, dot)]
	return float(group[path.substr(dot + 1)])


static func _write(table: Dictionary, path: String, value: float) -> void:
	var dot := path.find(".")
	if dot < 0:
		table[path] = value
		return
	var group: Dictionary = table[path.substr(0, dot)]
	group[path.substr(dot + 1)] = value
