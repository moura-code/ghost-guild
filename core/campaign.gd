class_name Campaign
extends RefCounted
## Everything the save file stores: the ladder, the living hero, the run in
## progress, Soul, upgrades, onboarding and the production clock. Mutated
## only by CampaignEngine and Seance.

var content: Content
var campaign_seed: int = 0
var biome_id: String = "catacombs"
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
var created_at: int = 0
var last_tick: int = 0
var rate_per_hour: float = 0.0
var sim_fights: int = -1
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func balance() -> Dictionary:
	return content.balance


func biome() -> BiomeDef:
	return content.biomes[biome_id]


func modifiers() -> Dictionary:
	return upgrades.modifiers(content)


func sub_rng(tag: String, n: int) -> Rng:
	return Rng.new(hash([campaign_seed, tag, n]))


func spend(cost: float) -> bool:
	if cost < 0.0 or soul < cost:
		return false
	soul -= cost
	emit({"type": "soul_spent", "amount": cost, "total": soul})
	return true


func _expeditions_dict() -> Array:
	var out: Array = []
	for e in expeditions:
		out.append((e as Expedition).to_dict())
	return out


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"campaign_seed": campaign_seed,
		"biome_id": biome_id,
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
		"created_at": created_at,
		"last_tick": last_tick,
		"rate_per_hour": rate_per_hour,
	}


static func from_dict(p_content: Content, d: Dictionary) -> Campaign:
	var c := Campaign.new()
	c.content = p_content
	c.campaign_seed = int(d.get("campaign_seed", 0))
	c.biome_id = String(d.get("biome_id", "catacombs"))
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
	for raw in d.get("expeditions", []):
		c.expeditions.append(Expedition.from_dict(raw))
	c.created_at = int(d.get("created_at", 0))
	c.last_tick = int(d.get("last_tick", 0))
	c.rate_per_hour = float(d.get("rate_per_hour", 0.0))
	return c
