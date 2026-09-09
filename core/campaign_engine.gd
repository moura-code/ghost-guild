class_name CampaignEngine
extends RefCounted
## Every transition of a Campaign: creation, heroes, runs, production
## ticks and upgrades. Static functions that mutate the campaign in place;
## Seance owns echoes, Calls, Tend and Mend.


static func new_campaign(content: Content, campaign_seed: int, now: int) -> Campaign:
	var c := Campaign.new()
	c.content = content
	c.content_revision = String(content.balance.get("revision", "baseline"))
	c.campaign_seed = campaign_seed
	c.created_at = now
	c.last_tick = now
	c.ladder.add(Ghost.founder(content, now))
	c.onboarding.founder_seeded = true
	new_hero(c, now)
	refresh_rate(c)
	c.emit({"type": "campaign_start", "seed": campaign_seed, "at": now})
	return c


## The next hero. `class_id` empty keeps the one who just died -- dying does
## not cost you your class, it offers you the choice again.
static func new_hero(c: Campaign, now: int, class_id: String = "") -> Hero:
	c.hero_counter += 1
	var mods := c.modifiers()
	var hero_name := Hero.generate_name(c.sub_rng("names", c.hero_counter))
	var wanted := class_id
	if wanted == "" and c.hero != null:
		wanted = c.hero.class_id
	if not Classes.is_unlocked(c.content, c.ladder, wanted, c.claimed_biomes):
		wanted = Classes.starting(c.content)
	var hero := Hero.create(c.content, wanted, hero_name, mods["stats"], 1 + int(mods["max_resolve_bonus"]))
	hero.id = c.hero_counter
	c.hero = hero
	c.emit({"type": "hero_created", "id": hero.id, "name": hero.name, "at": now})
	return hero


## Re-makes the living hero as `class_id` (spec §3.4). Refused once they have
## descended: the gate is `runs == 0`, so every death offers the choice again
## and nobody swaps mid-campaign to dodge a matchup.
##
## Nothing is lost by it. Reach, Soul, the upgrades, the ladder and the camp
## are all campaign-level; the only state discarded is a deck that has never
## been played.
static func choose_class(c: Campaign, class_id: String) -> Dictionary:
	if c.hero == null or c.run != null:
		return {"ok": false, "reason": "in_run"}
	if c.hero.class_id == class_id:
		return {"ok": false, "reason": "unchanged"}
	if not Classes.is_unlocked(c.content, c.ladder, class_id, c.claimed_biomes):
		return {"ok": false, "reason": "locked"}
	if c.hero.runs > 0:
		return {"ok": false, "reason": "committed"}
	var camp := c.hero.camp
	var hero := new_hero(c, c.last_tick, class_id)
	# The camp is where the *guild* got to, not where this deck did.
	hero.camp = camp
	c.emit({"type": "class_chosen", "class": class_id, "hero": hero.id})
	return {"ok": true, "reason": ""}


## What every Legend the guild has multiplies (spec §4.4): ghost strength, and
## hero damage and block. Exactly 1.0 until the first prestige.
static func blessing(c: Campaign) -> float:
	return Legends.blessing(c.legends)


## The card tag of the Legend carried into the next run, or "".
static func invoked_tag(c: Campaign) -> String:
	var l := Traits.invoked(c)
	return l.trait_tag if l != null else ""


## Sets the Depth Seal for the next descent (spec §6.2). Clamped to what the
## Chronicle has actually unlocked, and refused mid-run for the same reason an
## invocation is: the run snapshots it at the door.
static func set_seal(c: Campaign, seal: int, now: int) -> bool:
	if c.run != null and not c.run.is_over():
		push_error("set_seal: a run is already in progress")
		return false
	var wanted := clampi(seal, 0, Chronicle.seals_available(c))
	if wanted != seal:
		return false
	if c.seal == wanted:
		return true
	c.seal = wanted
	c.emit({"type": "seal_set", "seal": wanted, "at": now})
	return true


## Chooses which Legend to carry (spec §6.1). `id` of 0 carries none.
##
## Refused while a run is live, because the run snapshots the trait at the
## door: allowing it mid-run would put a number on the screen that the fights
## already fought were not using.
static func invoke_legend(c: Campaign, id: int, now: int) -> bool:
	if c.run != null and not c.run.is_over():
		push_error("invoke_legend: a run is already in progress")
		return false
	if id != 0:
		var found := false
		for l in c.legends:
			if l.id == id:
				found = true
		if not found:
			push_error("invoke_legend: no Legend with id %d" % id)
			return false
	if c.invoked_legend == id:
		return true
	c.invoked_legend = id
	c.emit({"type": "legend_invoked", "legend": id, "at": now})
	return true


## A ghost's snapshot, carrying the guild's Blessing. Every simulation in the
## game goes through a snapshot, so stamping it here is what stops one path
## pricing a ghost without the Blessing that ghost actually fights with.
static func blessed_snapshot(c: Campaign, ghost: Ghost) -> HeroSnapshot:
	var snap := ghost.snapshot()
	snap.blessing = blessing(c)
	return snap


## The floor a true ghost must be standing on before the guild may prestige.
static func prestige_threshold(c: Campaign) -> int:
	return Legends.threshold(c.content, c.legends.size())


static func can_prestige(c: Campaign) -> bool:
	return c.run == null and c.ladder.waypoint() >= prestige_threshold(c)


## The rite (spec §6.1). Merges every ghost into a Legend and starts the cycle
## again.
##
## What is kept and what is taken is the riskiest list in the game, so it is
## written here rather than spread across the reset:
##
## - **Kept:** reach, the upgrades, the unlocks, the biome claims (which are
##   derived from... nothing, now -- see below), the Legends, the Ink.
## - **Taken:** the ladder, the Soul, the waypoint, anything in the field, and
##   the living hero's camp.
##
## The one that needs saying out loud: **biome claims are derived from the
## ladder**, and the ladder is wiped, so a naive prestige would silently
## re-lock the Fungal Deep and take the Hexer with it. `claimed_biomes` is
## therefore banked on the campaign before the merge, and `Biomes.claimed`
## reads the union of the two.
static func prestige(c: Campaign, now: int) -> Dictionary:
	if c.run != null:
		return {"ok": false, "reason": "in_run", "legend": null}
	if c.ladder.waypoint() < prestige_threshold(c):
		return {"ok": false, "reason": "too_shallow", "legend": null}

	tick(c, now)
	for id in Biomes.claimed(c.content, c.ladder):
		if not c.claimed_biomes.has(id):
			c.claimed_biomes.append(id)
	var legend := Legends.forge(c.content, c.ladder, c.legends.size() + 1, now)
	legend.id = c.legends.size() + 1
	c.legends.append(legend)
	c.ink += 1

	c.ladder = Ladder.new()
	# Deeper Roots and Old Blood (§6.2): the Chronicle is the layer above
	# the layer that resets, so it is the only thing allowed to change what
	# a reset means. Both are the identity until Ink has been spent.
	var founder := Ghost.founder(c.content, now)
	founder.floor = Chronicle.founder_floor(c)
	c.ladder.add(founder)
	c.soul = c.soul * Chronicle.soul_kept(c)
	c.expeditions = []
	new_hero(c, now)
	refresh_rate(c)
	c.emit({"type": "prestige", "cycle": legend.cycle, "legend": legend.name,
		"mass": legend.mass, "multiplier": legend.multiplier,
		"trait": legend.trait_tag, "ink": c.ink, "at": now})
	return {"ok": true, "reason": "", "legend": legend}


static func reach(c: Campaign) -> int:
	var camp := c.hero.camp if c.hero != null else 0
	return maxi(1, maxi(c.ladder.waypoint(), maxi(camp, c.record_depth)))


static func start_run(c: Campaign, entry_floor: int, now: int) -> RunState:
	if c.run != null:
		if not c.run.is_over():
			push_error("start_run: a run is already in progress")
			return c.run
		push_error("start_run: the previous run has not been banked; call finish_run first")
		return null
	# Reach is the only limit. There used to be a second one -- the authored
	# depth -- and it stopped meaning anything the day the biomes started
	# cycling (§2): the dungeon has no bottom, so how deep you may enter is
	# exactly how deep you have been.
	var deepest := maxi(1, reach(c))
	if entry_floor < 1 or entry_floor > deepest:
		push_error("start_run: entry floor %d outside 1..%d" % [entry_floor, deepest])
		return null
	tick(c, now)
	c.run_counter += 1
	var run_seed := hash([c.campaign_seed, "run", c.run_counter])
	c.run = RunEngine.start_run(c.content, c.hero, entry_floor, run_seed,
		c.onboarding.watch_unlocked,
		Biomes.claimed_pools(c.content, c.ladder, c.claimed_biomes), blessing(c),
		c.campaign_seed, invoked_tag(c), c.seal)
	c.emit({"type": "run_started", "run": c.run_counter, "entry_floor": entry_floor, "seed": run_seed, "at": now})
	return c.run


static func finish_run(c: Campaign, now: int) -> Dictionary:
	if c.run == null or not c.run.is_over():
		push_error("finish_run: no finished run")
		return {}
	tick(c, now)
	var outcome := c.run.outcome
	var kind := String(outcome.get("kind", "death"))
	var floor := int(outcome.get("floor", 1))
	var soul := float(outcome.get("soul", 0.0))
	c.soul += soul
	c.emit({"type": "soul_banked", "amount": soul, "total": c.soul})
	# A floor is cleared by walking out of its exit. `abandon` ends a run as
	# a "retreat" from any phase, mid-fight included, so retreating from
	# anywhere but the exit was banking a floor nobody had finished -- a
	# permanent floor of reach for pressing Escape.
	var walked_out := String(c.run.outcome.get("from_phase", "exit")) == "exit"
	var cleared := floor if (kind == "watch" or walked_out) else floor - 1
	c.record_depth = maxi(c.record_depth, cleared)
	var result := {"kind": kind, "floor": floor, "soul": soul, "ghost_id": 0, "epitaph": "", "new_hero": false, "rite_events": []}
	# Whatever the hero was carrying is the guild's knowledge now, however
	# the run ended -- they came home with it or their ghost is standing in
	# it. Before `new_hero`, which replaces the hero this reads.
	_remember_relics(c, c.hero.relics)
	if kind == "death" or kind == "watch":
		var ghost := Ghost.from_run(c.hero, outcome, c.run.stats.measured(floor), now)
		ghost.seal = c.run.seal
		c.ladder.add(ghost)
		ghost.strength = strength_for(c, ghost)
		result["ghost_id"] = ghost.id
		result["epitaph"] = ghost.epitaph(c.content)
		c.emit({"type": "ghost_placed", "id": ghost.id, "floor": ghost.floor, "strength": ghost.strength, "epitaph": result["epitaph"], "cause": ghost.cause})
		var rite := c.onboarding.on_run_end(outcome)
		for ev in rite:
			c.emit(ev.duplicate())
		result["rite_events"] = rite
		new_hero(c, now)
		result["new_hero"] = true
	c.run = null
	refresh_rate(c)
	c.emit({"type": "run_finished", "kind": kind, "floor": floor, "soul": soul, "at": now})
	return result


## Everything the guild has ever held goes in the compendium (spec §5.5), and
## a prestige keeps it (§6.1). Recorded when a run banks its dead rather than
## when a relic is picked up, because a relic the hero found and then died
## without banking is one the guild never got its hands on.
static func _remember_relics(c: Campaign, relics: Array) -> void:
	for raw in relics:
		var id := String(raw)
		if id != "" and not c.compendium.has(id):
			c.compendium.append(id)


static func strength_for(c: Campaign, ghost: Ghost) -> float:
	if ghost.fixed_strength:
		return ghost.strength
	# A ghost left under a Depth Seal is worth more for ever (§6.2), and the
	# multiplier rides on the ghost so a later tend re-prices it with the
	# seal still on rather than washing it off. After the early return, not
	# before it: a fixed-strength ghost was paying for this and dropping it.
	var sealed := Chronicle.seal_yield(c.content, ghost.seal)
	var sim := Strength.simulate(c.content, blessed_snapshot(c, ghost),
		c.biome_at(ghost.floor), ghost.floor, hash([c.campaign_seed, "strength", ghost.id]),
		c.sim_fights, ghost.rules, c.campaign_seed, ghost.seal)
	return Strength.of_ghost_stats(ghost.measured, sim, c.balance()) * sealed


static func refresh_rate(c: Campaign) -> void:
	c.rate_per_hour = Production.rate_per_hour(c.ladder, c.balance(), c.modifiers())


## Enough for a week of the fastest expeditions. A guard, not a limit:
## expeditions do not relaunch themselves, so the loop is bounded by how many
## are in flight, and this only catches a corrupted save.
const MAX_SEGMENTS := 512


## Production up to `now`, in segments.
##
## `Production.accrue` integrates ONE rate across a window. An expedition that
## landed three hours into an eight-hour absence changed the rate three hours
## in, so a single call underpays every offline session that resolved one --
## silently, by exactly what the new ghost would have earned. The window is
## therefore cut at every expedition that lands inside it: accrue, place the
## ghost, refresh the rate, continue.
##
## Two things the cap does NOT do, both deliberate:
##
## - It does not stop an expedition landing. The cap limits what the ladder
##   PAYS for an absence, not what happened during it; a player returning after
##   a week to find their expedition still in the field would be right to call
##   that a bug.
## - It is not applied per segment. A budget of `min(elapsed, cap)` seconds is
##   spent across the segments in order, so cutting a window into more pieces
##   can never pay more than leaving it whole -- which is exactly what a
##   per-segment cap would do.
static func tick(c: Campaign, now: int) -> Dictionary:
	var elapsed := maxi(0, now - c.last_tick)
	var cap_seconds := int(round(c.offline_cap_hours() * 3600.0))
	var budget := mini(elapsed, cap_seconds)
	var total := {"elapsed": elapsed, "counted": 0, "capped": elapsed > budget,
		"soul": 0.0, "returned": []}
	var at := c.last_tick
	var guard := 0
	while guard < MAX_SEGMENTS:
		guard += 1
		var due := Expeditions.next_due(c)
		if due < 0 or due > now or due <= at:
			break
		budget = _accrue_segment(c, due - at, budget, total)
		at = due
		total["returned"].append_array(Expeditions.resolve_due(c, due))
		refresh_rate(c)
	_accrue_segment(c, now - at, budget, total)
	# Never backwards. `elapsed` is floored at zero, so a `now` behind
	# `last_tick` pays nothing -- and then moved the paid-up marker back,
	# so the next settle re-paid a window this one had already covered. An
	# NTP correction after a sleep is enough to do it.
	c.last_tick = maxi(c.last_tick, now)
	return total


## Pays for `span` seconds at the current rate, out of `budget`, and returns
## what is left of the budget.
static func _accrue_segment(c: Campaign, span: int, budget: int, total: Dictionary) -> int:
	var counted := clampi(span, 0, budget)
	if counted <= 0:
		return budget
	c.soul += c.rate_per_hour * counted / 3600.0
	total["soul"] = float(total["soul"]) + c.rate_per_hour * counted / 3600.0
	total["counted"] = int(total["counted"]) + counted
	return budget - counted


static func buy_upgrade(c: Campaign, id: String) -> Dictionary:
	var price := c.upgrades.cost(c.content, id)
	if price < 0.0:
		return {"ok": false, "cost": price, "reason": "unavailable"}
	if not c.spend(price):
		return {"ok": false, "cost": price, "reason": "soul"}
	c.upgrades.buy(c.content, id)
	var def: UpgradeDef = c.content.upgrades[id]
	var amount := int(def.effect.get("amount", 0))
	match String(def.effect.get("kind", "")):
		"stat":
			var stat := String(def.effect.get("stat", ""))
			c.hero.stats[stat] = int(c.hero.stats.get(stat, 0)) + amount
			if stat == "vigor":
				c.hero.recompute_max_hp(c.content)
		"max_resolve":
			c.hero.max_resolve += amount
			c.hero.resolve += amount
	refresh_rate(c)
	c.emit({"type": "upgrade_bought", "id": id, "level": c.upgrades.level(id), "cost": price})
	return {"ok": true, "cost": price, "reason": ""}


## Call only after settling the old cached rate. Sources precede linked echoes;
## founder and expedition promises (including in-flight ghosts) stay fixed.
static func refresh_content_revision(c: Campaign) -> bool:
	var revision := String(c.content.balance.get("revision", "baseline"))
	if c.content_revision == revision:
		return false
	for ghost in c.ladder.ghosts:
		if not ghost.fixed_strength and ghost.kind != "echo":
			ghost.strength = strength_for(c, ghost)
	for ghost in c.ladder.ghosts:
		if not ghost.fixed_strength and ghost.kind == "echo":
			var source := c.ladder.find(ghost.source_id)
			if source != null:
				ghost.strength = Seance.echo_strength(c, source, ghost.floor)
	var previous := c.content_revision
	c.content_revision = revision
	refresh_rate(c)
	c.emit({"type": "content_revised", "from": previous, "to": revision,
		"active_fight": c.run != null and c.run.phase == "fight"})
	return true
