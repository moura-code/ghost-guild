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
## One flag per node, so a floor can be walked in any order. `node_index`
## still means "the node being played"; this is what says which ones are
## behind you.
var resolved: Array = []
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


## The flags always match the node list. Nodes get written from three places --
## the floor generator, a loaded save, and the test fixtures -- and a flag array
## that has drifted out of step is a silent wrong answer rather than a crash, so
## every reader sizes it first instead of trusting whoever wrote nodes last.
func _sync_resolved() -> void:
	if resolved.size() == nodes.size():
		return
	var out: Array = []
	for i in nodes.size():
		out.append(bool(resolved[i]) if i < resolved.size() else false)
	resolved = out


func is_resolved(index: int) -> bool:
	_sync_resolved()
	return index >= 0 and index < resolved.size() and bool(resolved[index])


func resolve(index: int) -> void:
	_sync_resolved()
	if index >= 0 and index < resolved.size():
		resolved[index] = true


func next_unresolved() -> int:
	_sync_resolved()
	for i in resolved.size():
		if not bool(resolved[i]):
			return i
	return -1


func hero_snapshot() -> HeroSnapshot:
	return hero.snapshot(stat_bonus)


func to_dict() -> Dictionary:
	var in_fight := phase == "fight"
	return {
		"version": 1,
		"run_seed": run_seed,
		"biome_id": biome_id,
		"entry_floor": entry_floor,
		"floor": floor,
		"nodes": nodes.duplicate(true),
		"node_index": node_index,
		"resolved": resolved.duplicate(),
		"phase": "node" if in_fight else phase,
		"fight_counter": fight_counter - 1 if in_fight else fight_counter,
		"coin": coin,
		"soul": soul,
		"stat_bonus": stat_bonus.duplicate(),
		"stats": stats.to_dict(),
		"descent_offers": descent_offers.duplicate(true),
		"reward": reward.duplicate(true),
		"shop": shop.duplicate(true),
		"event_id": event_id,
		"used_events": used_events.duplicate(),
		"watch_unlocked": watch_unlocked,
		"outcome": outcome.duplicate(true),
		"hero": hero.to_dict(),
	}


static func from_dict(p_content: Content, d: Dictionary) -> RunState:
	var run := RunState.new()
	run.content = p_content
	run.hero = Hero.from_dict(d.get("hero", {}))
	run.run_seed = int(d.get("run_seed", 0))
	run.biome_id = String(d.get("biome_id", ""))
	run.entry_floor = int(d.get("entry_floor", 1))
	run.floor = int(d.get("floor", 1))
	var nodes_raw: Array = d.get("nodes", [])
	run.nodes = nodes_raw.duplicate(true)
	run.node_index = int(d.get("node_index", 0))
	for flag in d.get("resolved", []):
		run.resolved.append(bool(flag))
	run.phase = String(d.get("phase", "node"))
	run.fight_counter = int(d.get("fight_counter", 0))
	run.coin = int(d.get("coin", 0))
	run.soul = float(d.get("soul", 0.0))
	var bonus: Dictionary = d.get("stat_bonus", {})
	for key in bonus:
		run.stat_bonus[String(key)] = int(bonus[key])
	run.stats = RunStats.from_dict(d.get("stats", {}))
	for raw in d.get("descent_offers", []):
		var offer: Dictionary = raw
		var cards: Array = offer.get("cards", [])
		run.descent_offers.append({"floor": int(offer.get("floor", 0)), "cards": cards.duplicate()})
	var reward_raw: Dictionary = d.get("reward", {})
	run.reward = reward_raw.duplicate(true)
	var shop_raw: Dictionary = d.get("shop", {})
	for key in shop_raw:
		var value: Variant = shop_raw[key]
		run.shop[String(key)] = int(value) if value is float else value
	run.event_id = String(d.get("event_id", ""))
	for id in d.get("used_events", []):
		run.used_events.append(String(id))
	run.watch_unlocked = bool(d.get("watch_unlocked", false))
	var outcome_raw: Dictionary = d.get("outcome", {})
	run.outcome = outcome_raw.duplicate(true)
	for key in ["floor", "coin", "hero_hp"]:
		if run.outcome.has(key):
			run.outcome[key] = int(run.outcome[key])
	return run
