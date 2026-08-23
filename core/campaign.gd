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
