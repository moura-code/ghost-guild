class_name Chronicle
extends RefCounted
## The second prestige layer (spec §6.2): what Ink buys, and what it changes.
##
## Ink has existed since Legends shipped and bought nothing. One arrives per
## rite, so a Chapter costs a whole cycle — which is what makes this a layer
## rather than another upgrade shelf. The Chronicle opens at five Legends,
## because a mechanic that only pays across cycles is noise until the player
## has run several.
##
## Pure and total, and an identity at nothing: a guild with no Chapters has
## `founder_floor` 1, `spawn` 1.0, `soul_kept` 0.0 and no seals — which is the
## game exactly as it was before any of this.


## Legends the guild needs before the Chronicle opens at all (spec §6.2).
static func threshold(content: Content) -> int:
	return int(content.balance.get("chronicle_threshold", 5))


static func is_open(c: Campaign) -> bool:
	return c.legends.size() >= threshold(c.content)


static func level_of(c: Campaign, id: String) -> int:
	return int(c.chapters.get(id, 0))


## What the next level of a Chapter costs, or -1 when it is finished.
static func cost_of(c: Campaign, id: String) -> int:
	if not c.content.chapters.has(id):
		return -1
	var def: ChapterDef = c.content.chapters[id]
	var level := level_of(c, id)
	if level >= def.max_level:
		return -1
	return def.cost_at(level)


static func can_write(c: Campaign, id: String) -> bool:
	var price := cost_of(c, id)
	return is_open(c) and price >= 0 and c.ink >= price


## Buys one level. Named for what the player is doing: the Chronicle is a
## book, and this is writing the next chapter of it into the guild's history.
static func write(c: Campaign, id: String, now: int) -> Dictionary:
	if not c.content.chapters.has(id):
		return {"ok": false, "cost": 0, "reason": "unknown"}
	if not is_open(c):
		return {"ok": false, "cost": 0, "reason": "locked"}
	var price := cost_of(c, id)
	if price < 0:
		return {"ok": false, "cost": 0, "reason": "finished"}
	if c.ink < price:
		return {"ok": false, "cost": price, "reason": "ink"}
	c.ink -= price
	c.chapters[id] = level_of(c, id) + 1
	c.emit({"type": "chapter_written", "chapter": id, "level": c.chapters[id],
		"ink": c.ink, "at": now})
	return {"ok": true, "cost": price, "reason": ""}


## The total of every Chapter with this op, in the op's own units.
static func total(c: Campaign, op: String) -> float:
	var sum := 0.0
	for id in c.content.chapters:
		var def: ChapterDef = c.content.chapters[id]
		if def.op == op:
			sum += def.amount * float(level_of(c, id))
	return sum


## Which floor a new cycle's Founder stands on (§6.2, Deeper Roots). Floor 1
## with no Chapters, which is where the Founder has always stood.
static func founder_floor(c: Campaign) -> int:
	return maxi(1, 1 + int(round(total(c, "founder_floor"))))


## What every floor's spawn rate is multiplied by (§6.2, The Breeding Dark).
static func spawn(c: Campaign) -> float:
	return 1.0 + total(c, "global_spawn")


## The fraction of Soul that survives the rite (§6.2, Old Blood).
static func soul_kept(c: Campaign) -> float:
	return clampf(total(c, "soul_kept"), 0.0, 0.95)


## How many Depth Seals the guild may set (§6.2). Zero until it buys one.
static func seals_available(c: Campaign) -> int:
	return int(round(total(c, "seals")))


## What a run under `seal` multiplies enemy scaling by. 1.0 at no seal, so an
## unsealed descent is the descent the whole game is balanced around.
static func seal_scaling(content: Content, seal: int) -> float:
	var step := float(content.balance.get("seal_enemy_step", 0.25))
	return 1.0 + step * float(maxi(0, seal))


## And what it multiplies the strength of anything left down there by. Steeper
## than the difficulty, or a seal is a worse deal than not setting one -- and
## an opt-in difficulty nobody opts into is a feature nobody has.
static func seal_yield(content: Content, seal: int) -> float:
	var step := float(content.balance.get("seal_yield_step", 0.45))
	return 1.0 + step * float(maxi(0, seal))
