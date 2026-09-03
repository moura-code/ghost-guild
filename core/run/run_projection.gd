class_name RunProjection
extends RefCounted
## Survival chance for a floor (spec §3.2): the share of simulated descents
## in which the deck clears every fight on that floor without dying. Event
## and shop nodes are no-ops; rest nodes heal rest_heal_percent.
##
## The simulated floor is fought under the rules the real one will be: the
## tier's mutation, the invoked Legend's trait and the Depth Seal. It was
## not, which made this the worst kind of wrong -- the number the push
## decision hangs on, measured against an easier fight than the one the
## player was about to walk into.


static func survival_chance(content: Content, hero: HeroSnapshot, biome: BiomeDef,
		floor: int, run_seed: int, samples: int, autopilot: Autopilot = null,
		mutation: MutationDef = null, hero_trait: TraitDef = null,
		seal: float = 1.0) -> float:
	if samples <= 0:
		return 0.0
	var ap := autopilot if autopilot != null else Autopilot.new()
	var survived := 0
	for i in samples:
		if simulate_floor(content, hero.clone(), biome, floor,
			hash([run_seed, "survival", floor, i]), ap, mutation, hero_trait, seal):
			survived += 1
	return float(survived) / samples


static func simulate_floor(content: Content, hero: HeroSnapshot, biome: BiomeDef,
		floor: int, sample_seed: int, ap: Autopilot, mutation: MutationDef = null,
		hero_trait: TraitDef = null, seal: float = 1.0) -> bool:
	var nodes := FloorGenerator.generate(content, biome, floor, Rng.new(sample_seed))
	var fight_no := 0
	for node in nodes:
		match String(node.get("kind", "")):
			"fight", "elite", "boss":
				fight_no += 1
				var s := CombatEngine.start_fight(content, hero, node["enemies"], floor,
					Rng.new(hash([sample_seed, fight_no])), mutation, hero_trait, seal)
				var r := ap.play_fight(s)
				hero.hp = int(r["hp"])
				if not bool(r["won"]):
					return false
			"rest":
				var heal := int(round(hero.max_hp * float(content.balance.get("rest_heal_percent", 0.3))))
				hero.hp = mini(hero.max_hp, hero.hp + heal)
	return true
