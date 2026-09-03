class_name Campaign
extends RefCounted
## Everything the save file stores: the ladder, the living hero, the run in
## progress, Soul, upgrades, onboarding and the production clock. Mutated
## only by CampaignEngine and Seance.

var content: Content
var campaign_seed: int = 0
var ladder: Ladder = Ladder.new()
var upgrades: Upgrades = Upgrades.new()
var onboarding: Onboarding = Onboarding.new()
var hero: Hero
var run: RunState
var soul: float = 0.0
var record_depth: int = 0
var hero_counter: int = 0
var run_counter: int = 0
var expedition_counter: int = 0
## In flight. Empty until the Descent upgrade is bought; at most
## `Expeditions.slots`.
var expeditions: Array[Expedition] = []
## The prestige layer (spec §6.1). Every merged cycle, oldest first, and the
## currency the next layer will spend. Both survive a prestige by definition;
## almost nothing else does.
var legends: Array[Legend] = []
## The Legend carried into the next run (spec §6.1: "one Legend can be invoked
## per run as an extra relic"), by id, or 0 for none. By id rather than index
## because a later prestige appends to the list and must not silently re-point
## an invocation at somebody else's grave.
var invoked_legend: int = 0
## Every relic the guild has ever held (spec §5.5's compendium, and §6.1 lists
## it among the things a prestige keeps). Tending adds a relic *from here*, so
## the guild can only give a ghost something it has actually found -- which is
## what makes finding one matter after the run it was found on.
var compendium: Array[String] = []
var ink: int = 0
## Biomes claimed in an earlier cycle. Claims are derived from the ladder
## (spec §5.6) and prestige wipes the ladder, so without this the rite would
## silently re-lock the Fungal Deep and take the Hexer with it -- §6.1 lists
## biome claims among the things a prestige keeps.
var claimed_biomes: Array[String] = []
var created_at: int = 0
var last_tick: int = 0
var rate_per_hour: float = 0.0
var sim_fights: int = -1
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func balance() -> Dictionary:
	return content.balance


## The biome a floor is in. Not a field: a ghost on floor 14 and a ghost on
## floor 3 are standing in different places, and every projection in the game
## is handed the floor it cares about.
func biome_at(floor: int) -> BiomeDef:
	return Biomes.for_floor(content, floor)


func modifiers() -> Dictionary:
	var mods := upgrades.modifiers(content)
	# Hauntings (spec §5.6) are a property of *who is standing where*, so they
	# ride with the other floor modifiers rather than living inside `Ladder`,
	# which holds ghosts and has never needed to know what a card is.
	mods["haunting"] = Hauntings.by_floor(content, ladder, balance())
	return mods


func sub_rng(tag: String, n: int) -> Rng:
	return Rng.new(hash([campaign_seed, tag, n]))


func spend(cost: float) -> bool:
	if cost < 0.0 or soul < cost:
		return false
	soul -= cost
	emit({"type": "soul_spent", "amount": cost, "total": soul})
	return true


func _legends_dict() -> Array:
	var out: Array = []
	for l in legends:
		out.append((l as Legend).to_dict())
	return out


func _expeditions_dict() -> Array:
	var out: Array = []
	for e in expeditions:
		out.append((e as Expedition).to_dict())
	return out


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"campaign_seed": campaign_seed,
		"ladder": ladder.to_dict(),
		"upgrades": upgrades.to_dict(),
		"onboarding": onboarding.to_dict(),
		"hero": hero.to_dict() if hero != null else {},
		"run": run.to_dict() if run != null else {},
		"soul": soul,
		"record_depth": record_depth,
		"hero_counter": hero_counter,
		"run_counter": run_counter,
		"expedition_counter": expedition_counter,
		"expeditions": _expeditions_dict(),
		"legends": _legends_dict(),
		"invoked_legend": invoked_legend,
		"compendium": compendium.duplicate(),
		"ink": ink,
		"claimed_biomes": claimed_biomes.duplicate(),
		"created_at": created_at,
		"last_tick": last_tick,
		"rate_per_hour": rate_per_hour,
	}


static func from_dict(p_content: Content, d: Dictionary) -> Campaign:
	var c := Campaign.new()
	c.content = p_content
	c.campaign_seed = int(d.get("campaign_seed", 0))
	c.ladder = Ladder.from_dict(d.get("ladder", {}))
	c.upgrades = Upgrades.from_dict(d.get("upgrades", {}))
	c.onboarding = Onboarding.from_dict(d.get("onboarding", {}))
	var hero_raw: Dictionary = d.get("hero", {})
	if not hero_raw.is_empty():
		c.hero = Hero.from_dict(hero_raw)
	var run_raw: Dictionary = d.get("run", {})
	if not run_raw.is_empty():
		c.run = RunState.from_dict(p_content, run_raw)
		c.hero = c.run.hero
	c.soul = float(d.get("soul", 0.0))
	c.record_depth = int(d.get("record_depth", 0))
	c.hero_counter = int(d.get("hero_counter", 0))
	c.run_counter = int(d.get("run_counter", 0))
	c.expedition_counter = int(d.get("expedition_counter", 0))
	c.ink = int(d.get("ink", 0))
	for claimed in d.get("claimed_biomes", []):
		c.claimed_biomes.append(String(claimed))
	for raw_legend in d.get("legends", []):
		c.legends.append(Legend.from_dict(raw_legend))
	c.invoked_legend = int(d.get("invoked_legend", 0))
	for relic in d.get("compendium", []):
		c.compendium.append(String(relic))
	for raw in d.get("expeditions", []):
		c.expeditions.append(Expedition.from_dict(raw))
	c.created_at = int(d.get("created_at", 0))
	c.last_tick = int(d.get("last_tick", 0))
	c.rate_per_hour = float(d.get("rate_per_hour", 0.0))
	return c
