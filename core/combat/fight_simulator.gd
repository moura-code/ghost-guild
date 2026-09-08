class_name FightSimulator
extends RefCounted
## Runs many autopilot fights and summarizes them. The hero snapshot is
## cloned per fight, so callers can reuse it.
##
## `mutation`, `hero_trait` and `seal` are the rules the *real* fight would
## be fought under (spec §2, §6.1, §6.2). They default to none, which is
## every floor of the authored dungeon -- but leaving them out on floor 44
## measures a fight that will not happen, and everything downstream (a
## ghost's price, the survival reading the push decision hangs on) inherits
## the error with nothing to show for it.


static func simulate(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int,
		seed: int, fights: int, autopilot: Autopilot = null, mutation: MutationDef = null,
		hero_trait: TraitDef = null, seal: float = 1.0) -> Dictionary:
	var groups: Array = [enemy_ids]
	return simulate_table(content, hero, groups, floor, seed, fights, autopilot,
		mutation, hero_trait, seal)


static func simulate_table(content: Content, hero: HeroSnapshot, groups: Array, floor: int,
		seed: int, fights: int, autopilot: Autopilot = null, mutation: MutationDef = null,
		hero_trait: TraitDef = null, seal: float = 1.0) -> Dictionary:
	var ap := autopilot if autopilot != null else Autopilot.new()
	var wins := 0
	var turns_total := 0
	var hp_total := 0
	for i in fights:
		var group: Array = groups[i % groups.size()]
		var s := CombatEngine.start_fight(content, hero.clone(), group, floor,
			Rng.new(hash([seed, i])), mutation, hero_trait, seal)
		var r := ap.play_fight(s)
		if r["won"]:
			wins += 1
			turns_total += int(r["turns"])
			hp_total += int(r["hp"])
	return {
		"fights": fights,
		"wins": wins,
		"losses": fights - wins,
		"win_rate": (float(wins) / fights) if fights > 0 else 0.0,
		"avg_turns": (float(turns_total) / wins) if wins > 0 else 0.0,
		"avg_hp_left": (float(hp_total) / wins) if wins > 0 else 0.0,
	}
