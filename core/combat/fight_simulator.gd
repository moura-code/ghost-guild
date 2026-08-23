class_name FightSimulator
extends RefCounted
## Runs many autopilot fights and summarizes them. The hero snapshot is
## cloned per fight, so callers can reuse it.


static func simulate(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary:
	var groups: Array = [enemy_ids]
	return simulate_table(content, hero, groups, floor, seed, fights, autopilot)


static func simulate_table(content: Content, hero: HeroSnapshot, groups: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary:
	var ap := autopilot if autopilot != null else Autopilot.new()
	var wins := 0
	var turns_total := 0
	var hp_total := 0
	for i in fights:
		var group: Array = groups[i % groups.size()]
		var s := CombatEngine.start_fight(content, hero.clone(), group, floor, Rng.new(hash([seed, i])))
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
