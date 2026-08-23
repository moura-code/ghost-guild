class_name RunState
extends RefCounted
## The complete state of one run. Mutated in place by RunEngine; `fight`
## holds the active FightState during a fight node. Randomness is derived
## per use from (run_seed, tag, n) so a saved run resumes deterministically.

var content: Content
var hero: Hero
var run_seed: int = 0
var biome_id: String = ""
var entry_floor: int = 1
var floor: int = 1
var nodes: Array = []
var node_index: int = 0
var phase: String = "descent"
var fight: FightState
var fight_counter: int = 0
var coin: int = 0
var soul: float = 0.0
var stat_bonus: Dictionary = {}
var stats: RunStats = RunStats.new()
var descent_offers: Array = []
var reward: Dictionary = {}
var shop: Dictionary = {}
var event_id: String = ""
var used_events: Array = []
var watch_unlocked: bool = false
var outcome: Dictionary = {}
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func biome() -> BiomeDef:
	return content.biomes[biome_id]


func sub_rng(tag: String, n: int) -> Rng:
	return Rng.new(hash([run_seed, tag, n]))


func add_coin(amount: int) -> void:
	coin = maxi(0, coin + amount)
	emit({"type": "coin_changed", "amount": amount, "total": coin})


func add_soul(amount: float) -> void:
	soul = maxf(0.0, soul + amount)
	emit({"type": "soul_changed", "amount": amount, "total": soul})


func grant_relic(relic_id: String) -> bool:
	if relic_id == "" or hero.relics.has(relic_id):
		emit({"type": "relic_already_owned", "relic": relic_id})
		return false
	hero.relics.append(relic_id)
	emit({"type": "relic_gained", "relic": relic_id})
	return true


func is_over() -> bool:
	return phase == "ended"


func current_node() -> Dictionary:
	if node_index < 0 or node_index >= nodes.size():
		return {}
	return nodes[node_index]


func hero_snapshot() -> HeroSnapshot:
	return hero.snapshot(stat_bonus)
