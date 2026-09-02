class_name Strength
extends RefCounted
## Ghost strength in kills per hour (spec §5.2): ghost-time per kill from a
## win rate and an average fight length, measured stats blended with a
## simulation by sample size. Never called per tick.


static func seconds_per_kill(win_rate: float, avg_turns: float, balance: Dictionary) -> float:
	if win_rate <= 0.0:
		return INF
	var turn := float(balance.get("ghost_turn_seconds", 10))
	var respawn := float(balance.get("ghost_respawn_seconds", 20))
	var loss := float(balance.get("ghost_loss_seconds", 120))
	return (avg_turns * turn + respawn) / win_rate + (1.0 - win_rate) / win_rate * loss


static func from_stats(win_rate: float, avg_turns: float, balance: Dictionary) -> float:
	var seconds := seconds_per_kill(win_rate, avg_turns, balance)
	if is_inf(seconds) or seconds <= 0.0:
		return 0.0
	return 3600.0 / seconds


## `rules` is who is fighting (spec 3.3). Empty is the default autopilot, which
## is what every caller passed before this existed and what every caller with
## nothing to say still passes -- so a ghost with no rules simulates exactly as
## it always did.
static func simulate(content: Content, snapshot: HeroSnapshot, biome: BiomeDef, floor: int, seed_value: int, fights: int = -1, rules: Array = []) -> Dictionary:
	var n := fights if fights > 0 else int(content.balance.get("strength_sim_fights", 50))
	var groups := FloorGenerator.groups_for(biome, floor)
	var ap: Autopilot = Autopilot.with_rules(rules, content) if not rules.is_empty() else null
	var r := FightSimulator.simulate_table(content, snapshot, groups, floor, seed_value, n, ap)
	return {"fights": int(r["fights"]), "wins": int(r["wins"]), "win_rate": float(r["win_rate"]), "avg_turns": float(r["avg_turns"])}


static func blend(measured: Dictionary, simulated: Dictionary, balance: Dictionary) -> Dictionary:
	var n := float(measured.get("fights", 0))
	var k := float(balance.get("strength_blend_k", 3))
	var w := n / (n + k) if n > 0.0 else 0.0
	var sim_rate := float(simulated.get("win_rate", 0.0))
	var sim_turns := float(simulated.get("avg_turns", 0.0))
	var win_rate := w * float(measured.get("win_rate", 0.0)) + (1.0 - w) * sim_rate
	var avg_turns := sim_turns
	if int(measured.get("wins", 0)) > 0:
		avg_turns = w * float(measured.get("avg_turns", 0.0)) + (1.0 - w) * sim_turns
	return {"win_rate": win_rate, "avg_turns": avg_turns, "weight": w}


static func of_ghost_stats(measured: Dictionary, simulated: Dictionary, balance: Dictionary) -> float:
	var b := blend(measured, simulated, balance)
	return from_stats(float(b["win_rate"]), float(b["avg_turns"]), balance)
