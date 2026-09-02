class_name Expeditions
extends RefCounted
## The idle ghost source (spec §3.5).
##
## Every ghost in the game so far came from a human playing a run, which makes
## the idle half of "the living hero is the roguelite, dead heroes become
## idle-farming ghosts" a half with no source. An expedition is the guild
## sending someone down on its own: a fresh hero with the class starting deck
## and the meta slots, descending under the autopilot with auto-draft to the
## deepest floor within reach where its projected survival holds up, who then
## takes the watch.
##
## Three rules from the spec that shape all of this:
##
## - **Unprepared.** No +25%. Only manual play earns that.
## - **It cannot extend reach.** An expedition ghost raises the waypoint up to
##   reach, never past it, so the idle half follows the played half and never
##   leads it.
## - **One at a time**, until slots are bought. A guild that kept sending
##   people would place several dozen ghosts across one offline window --
##   unbounded save growth for a floor that saturates anyway.
##
## Everything expensive happens in `launch`. See `Expedition`.

const UNLOCK := "expedition"
const SLOTS := "expedition_slots"
const SPEED := "expedition_speed"


static func unlocked(c: Campaign) -> bool:
	return c.upgrades.level(UNLOCK) > 0


## One, plus whatever has been bought.
static func slots(c: Campaign) -> int:
	return 1 + c.upgrades.level(SLOTS) if unlocked(c) else 0


static func can_launch(c: Campaign) -> bool:
	return unlocked(c) and c.expeditions.size() < slots(c)


## About two minutes per floor (spec §3.5), faster with the speed upgrade. The
## depth is what makes a deep expedition a real commitment rather than a
## strictly better one.
static func duration_seconds(c: Campaign, depth: int) -> int:
	var per_floor := float(c.balance().get("expedition_seconds_per_floor", 120))
	var speed := 1.0 + float(c.upgrades.level(SPEED)) * float(c.balance().get("expedition_speed_step", 0.2))
	return maxi(1, int(round(maxi(1, depth) * per_floor / speed)))


## The hero the guild would send if it entered at `floor`: the class starting
## deck, the meta stat slots, and one auto-drafted pick for every floor skipped
## on the way in (spec §3.2).
##
## The living hero's doctrine goes with them. The guild trains people the way
## its master fights, and it is also the only answer that makes an expedition
## ghost's rules mean anything.
static func hero_for(c: Campaign, floor: int, seed_value: int) -> Hero:
	var mods := c.modifiers()
	var name := Hero.generate_name(Rng.new(hash([seed_value, "expedition_name"])))
	var hero := Hero.create(c.content, c.hero.class_id if c.hero != null else "sexton",
		name, mods["stats"], 1 + int(mods["max_resolve_bonus"]))
	hero.rules = c.hero.rules.duplicate() if c.hero != null else []
	for offer in DescentDraft.offers(c.content, hero, c.biome(), floor, seed_value):
		var cards: Array = offer["cards"]
		if cards.is_empty():
			continue
		hero.add_card(String(cards[DescentDraft.auto_pick(c.content, cards, hero.rules)]))
	return hero


## The deepest floor within reach whose projected survival holds up, and the
## hero who would go there.
##
## Every floor up to reach is checked rather than stopping at the first
## failure: a deeper floor grants another draft pick on the way in, so
## survival is *nearly* monotonic in depth and not quite, and the cost is
## bounded by reach either way.
static func plan(c: Campaign, seed_value: int) -> Dictionary:
	var threshold := float(c.balance().get("expedition_survival", 0.65))
	var samples := int(c.balance().get("expedition_samples", 4))
	var reach := maxi(1, CampaignEngine.reach(c))
	var best := {"depth": 0, "hero": null, "survival": 0.0}
	for floor in range(1, reach + 1):
		var hero := hero_for(c, floor, seed_value)
		var ap := Autopilot.with_rules(hero.rules, c.content)
		var survival := RunProjection.survival_chance(
			c.content, hero.snapshot(), c.biome(), floor,
			hash([seed_value, "expedition", floor]), samples, ap)
		if survival >= threshold:
			best = {"depth": floor, "hero": hero, "survival": survival}
	if best["hero"] == null:
		# Nowhere is safe enough. The guild still sends someone -- floor 1 is
		# where the Founder already stands, and an expedition that refuses to
		# leave is an upgrade the player bought for nothing.
		best = {"depth": 1, "hero": hero_for(c, 1, seed_value), "survival": 0.0}
	return best


## Sends someone down. Does all the work: the projection, the draft, the ghost
## and its strength. Returns `{"ok": bool, "expedition": Expedition, "reason": String}`.
static func launch(c: Campaign, now: int) -> Dictionary:
	if not unlocked(c):
		return {"ok": false, "expedition": null, "reason": "locked"}
	if c.expeditions.size() >= slots(c):
		return {"ok": false, "expedition": null, "reason": "full"}
	c.expedition_counter += 1
	var seed_value := hash([c.campaign_seed, "expedition", c.expedition_counter])
	var planned := plan(c, seed_value)
	var hero: Hero = planned["hero"]
	var depth := int(planned["depth"])

	var e := Expedition.new()
	e.id = c.expedition_counter
	e.started_at = now
	e.seconds = duration_seconds(c, depth)
	e.survival = float(planned["survival"])
	e.ghost = Ghost.from_expedition(hero, depth, now)
	# Priced now, once, and never again: `fixed_strength` is what makes
	# resolution free, and the Founder already uses it for the same reason.
	var sim := Strength.simulate(c.content, e.ghost.snapshot(), c.biome(), depth,
		hash([seed_value, "strength"]), int(c.balance().get("expedition_sim_fights", 12)), hero.rules)
	e.ghost.strength = Strength.from_stats(float(sim["win_rate"]), float(sim["avg_turns"]), c.balance())
	e.ghost.measured = {"fights": 0, "wins": 0, "win_rate": float(sim["win_rate"]), "avg_turns": float(sim["avg_turns"])}
	e.ghost.fixed_strength = true

	c.expeditions.append(e)
	c.emit({"type": "expedition_launched", "id": e.id, "floor": depth,
		"seconds": e.seconds, "survival": e.survival, "name": e.ghost.name, "at": now})
	return {"ok": true, "expedition": e, "reason": ""}


## When the next in-flight expedition lands, or -1 if none will.
static func next_due(c: Campaign) -> int:
	var soonest := -1
	for e in c.expeditions:
		var at: int = (e as Expedition).done_at()
		if soonest < 0 or at < soonest:
			soonest = at
	return soonest


## Lands every expedition finished by `now`, oldest first, and returns what
## they left. Pure bookkeeping -- no simulation, by construction.
static func resolve_due(c: Campaign, now: int) -> Array:
	var landed: Array = []
	var still: Array[Expedition] = []
	var due: Array[Expedition] = []
	for e in c.expeditions:
		if (e as Expedition).is_done(now):
			due.append(e)
		else:
			still.append(e)
	due.sort_custom(func(a: Expedition, b: Expedition) -> bool: return a.done_at() < b.done_at())
	c.expeditions = still
	for e in due:
		c.ladder.add(e.ghost)
		landed.append(e.ghost)
		c.emit({"type": "expedition_returned", "id": e.id, "floor": e.ghost.floor,
			"name": e.ghost.name, "strength": e.ghost.strength, "at": e.done_at()})
	return landed
