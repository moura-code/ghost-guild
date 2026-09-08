class_name RuleDef
extends RefCounted
## A priority rule (spec §3.3): a named bias on how the autopilot scores a
## turn, so a ghost fights the way its owner chose rather than the way every
## other ghost fights.
##
## A rule is nothing but a set of adjustments to `Autopilot.weights`, keyed by
## the weight's name. Nested weights are reached by a dotted path
## (`enemy_status.poison`) and a whole group by `hero_status.*`, so the data
## can say "care more about poison" without the loader having to know what a
## status is.
##
## Each adjustment is `{"mul": x}`, `{"add": y}`, or both. See
## `PriorityRules.weights_for` for how they compose.

var id: String = ""
var name_key: String = ""
var text_key: String = ""
## weight path -> {"mul": float, "add": float}
var weights: Dictionary = {}


static func from_dict(d: Dictionary) -> RuleDef:
	var r := RuleDef.new()
	r.id = String(d.get("id", ""))
	r.name_key = String(d.get("name", ""))
	r.text_key = String(d.get("text", ""))
	var raw: Dictionary = d.get("weights", {})
	r.weights = raw.duplicate(true)
	return r


## The multiplier this rule applies to `path`, or 1.0. Kept here rather than
## read out of the dictionary at every call site so "a missing mul is 1.0, not
## 0.0" is decided once -- the other way round, an adjustment that only sets
## `add` would silently zero the weight it was meant to nudge.
func mul_for(path: String) -> float:
	var entry: Dictionary = weights.get(path, {})
	return float(entry.get("mul", 1.0))


func add_for(path: String) -> float:
	var entry: Dictionary = weights.get(path, {})
	return float(entry.get("add", 0.0))
