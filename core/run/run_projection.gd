class_name RunProjection
extends RefCounted
## Survival chance for a floor (spec §3.2): the share of simulated descents
## in which the deck clears every fight on that floor without dying. Event
## and shop nodes are no-ops; rest nodes heal rest_heal_percent.


static func survival_chance(content: Content, hero: HeroSnapshot, biome: BiomeDef, floor: int, run_seed: int, samples: int, autopilot: Autopilot = null) -> float:
	if samples <= 0:
		return 0.0
	var ap := autopilot if autopilot != null else Autopilot.new()
	var survived := 0
	for i in samples:
		if simulate_floor(content, hero.clone(), biome, floor, hash([run_seed, "survival", floor, i]), ap):
			survived += 1
	return float(survived) / samples


static func simulate_floor(content: Content, hero: HeroSnapshot, biome: BiomeDef, floor: int, sample_seed: int, ap: Autopilot) -> bool:
	var nodes := FloorGenerator.generate(content, biome, floor, Rng.new(sample_seed))
	var fight_no := 0
	for node in nodes:
		match String(node.get("kind", "")):
			"fight", "elite", "boss":
				fight_no += 1
				var s := CombatEngine.start_fight(content, hero, node["enemies"], floor, Rng.new(hash([sample_seed, fight_no])))
				var r := ap.play_fight(s)
				hero.hp = int(r["hp"])
				if not bool(r["won"]):
					return false
			"rest":
				var heal := int(round(hero.max_hp * float(content.balance.get("rest_heal_percent", 0.3))))
				hero.hp = mini(hero.max_hp, hero.hp + heal)
	return true
