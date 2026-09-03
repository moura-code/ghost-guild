class_name Hauntings
extends RefCounted
## When your dead start agreeing with each other (spec §5.6).
##
## "A floor with three or more ghosts sharing an archetype forms a Haunting:
## +15% spawn_rate per matching ghost, capped at +75%. Synergy raises the
## floor's **cap** -- a bigger floor -- rather than each ghost's strength."
##
## That distinction is the whole design and it is worth spelling out, because
## the other reading is the obvious one and it is wrong. Buffing each ghost's
## strength would make a haunting worth nothing on a floor that is already
## saturated, which is exactly where the player has been stacking their dead.
## Raising the spawn rate raises the ceiling the strength is measured against,
## so a haunting is worth *most* on a crowded floor. It is the mechanic that
## says "put your Poison dead together" rather than "spread them thin".
##
## Pure, total, and an identity below the threshold: two matching ghosts are
## two ghosts.

## The largest group of same-archetype ghosts on a floor, as
## `{"tag": String, "count": int}`. A tie goes to the alphabetically first tag,
## so a ladder that is saved and loaded reports the same haunting.
static func on_floor(content: Content, ladder: Ladder, floor: int) -> Dictionary:
	var counts: Dictionary = {}
	for g in ladder.on_floor(floor):
		var tag := (g as Ghost).archetype(content)
		if tag == "":
			continue
		counts[tag] = int(counts.get(tag, 0)) + 1
	var names: Array = counts.keys()
	names.sort()
	var best := ""
	var most := 0
	for tag in names:
		if int(counts[tag]) > most:
			most = int(counts[tag])
			best = String(tag)
	return {"tag": best, "count": most}


## What a haunting multiplies the floor's spawn rate by. 1.0 for a floor that
## has not formed one.
static func spawn_bonus(content: Content, ladder: Ladder, floor: int,
		balance: Dictionary) -> float:
	var group := on_floor(content, ladder, floor)
	return bonus_for(int(group["count"]), balance)


## The multiplier a group of `count` matching ghosts is worth. Split out from
## the lookup so the curve can be checked without a ladder.
static func bonus_for(count: int, balance: Dictionary) -> float:
	var needed := int(balance.get("haunting_min", 3))
	if count < needed:
		return 1.0
	var per := float(balance.get("haunting_per", 0.15))
	var cap := float(balance.get("haunting_cap", 0.75))
	return 1.0 + minf(cap, per * float(count))


## Every floor's multiplier, keyed by floor. Only floors that have actually
## formed a haunting appear, so the table is small and a missing floor means
## exactly 1.0 -- which is what keeps `Ladder` free of any of this.
static func by_floor(content: Content, ladder: Ladder, balance: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for floor in ladder.floors():
		var mult := spawn_bonus(content, ladder, floor, balance)
		if not is_equal_approx(mult, 1.0):
			out[floor] = mult
	return out


## What the player is told. Empty when the floor has no haunting.
static func describe(content: Content, ladder: Ladder, floor: int,
		balance: Dictionary) -> Dictionary:
	var group := on_floor(content, ladder, floor)
	var mult := bonus_for(int(group["count"]), balance)
	if is_equal_approx(mult, 1.0):
		return {}
	return {"tag": group["tag"], "count": group["count"], "bonus": mult - 1.0}
