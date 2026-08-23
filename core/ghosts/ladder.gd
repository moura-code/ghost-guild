class_name Ladder
extends RefCounted
## Every ghost on every floor and what each floor pays (spec §5.3):
## output/h = min(spawn_rate, S) × soul_per_kill + max(0, S − spawn_rate) × 0.25 × soul_per_kill.

var ghosts: Array[Ghost] = []
var next_ghost_id: int = 1


static func spawn_rate(floor: int, balance: Dictionary) -> float:
	return float(balance.get("spawn_rate_base", 60)) * pow(float(balance.get("spawn_rate_growth", 1.08)), floor)


static func soul_per_kill(floor: int, balance: Dictionary) -> float:
	return Rewards.soul_for(floor, balance)


static func output_for(total_strength: float, floor: int, balance: Dictionary, spawn_mult: float = 1.0) -> float:
	var rate := spawn_rate(floor, balance) * spawn_mult
	var per_kill := soul_per_kill(floor, balance)
	var overflow := float(balance.get("overflow_rate", 0.25))
	return minf(rate, total_strength) * per_kill + maxf(0.0, total_strength - rate) * overflow * per_kill


static func effective_strength(ghost: Ghost, balance: Dictionary, modifiers: Dictionary) -> float:
	var s := ghost.strength
	if ghost.prepared:
		s *= 1.0 + float(balance.get("prepared_bonus", 0.25))
	if ghost.restless:
		s *= 1.0 - float(modifiers.get("restless_penalty", balance.get("restless_penalty", 0.3)))
	return s * float(modifiers.get("global_strength", 1.0))


func add(ghost: Ghost) -> Ghost:
	ghost.id = next_ghost_id
	next_ghost_id += 1
	ghosts.append(ghost)
	return ghost


func find(id: int) -> Ghost:
	for g in ghosts:
		if g.id == id:
			return g
	return null


func remove(id: int) -> bool:
	for i in ghosts.size():
		if ghosts[i].id == id:
			ghosts.remove_at(i)
			return true
	return false


func on_floor(floor: int) -> Array[Ghost]:
	var out: Array[Ghost] = []
	for g in ghosts:
		if g.floor == floor:
			out.append(g)
	return out


func floors() -> Array[int]:
	var seen := {}
	for g in ghosts:
		seen[g.floor] = true
	var out: Array[int] = []
	for f in seen:
		out.append(int(f))
	out.sort()
	return out


func floor_strength(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	var total := 0.0
	for g in on_floor(floor):
		total += effective_strength(g, balance, modifiers)
	return total


func floor_output(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	return output_for(floor_strength(floor, balance, modifiers), floor, balance, float(modifiers.get("global_spawn", 1.0)))


func saturation(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	var rate := spawn_rate(floor, balance) * float(modifiers.get("global_spawn", 1.0))
	return floor_strength(floor, balance, modifiers) / rate if rate > 0.0 else 0.0


func total_output(balance: Dictionary, modifiers: Dictionary) -> float:
	var total := 0.0
	for f in floors():
		total += floor_output(f, balance, modifiers)
	return total


func marginal_yield(floor: int, candidate_strength: float, balance: Dictionary, modifiers: Dictionary) -> float:
	var spawn_mult := float(modifiers.get("global_spawn", 1.0))
	var current := floor_strength(floor, balance, modifiers)
	return output_for(current + candidate_strength, floor, balance, spawn_mult) - output_for(current, floor, balance, spawn_mult)


func waypoint() -> int:
	var deepest := 0
	for g in ghosts:
		if g.kind == "true" and g.floor > deepest:
			deepest = g.floor
	return deepest


func to_dict() -> Dictionary:
	var out: Array = []
	for g in ghosts:
		out.append(g.to_dict())
	return {"ghosts": out, "next_ghost_id": next_ghost_id}


static func from_dict(d: Dictionary) -> Ladder:
	var ladder := Ladder.new()
	for raw in d.get("ghosts", []):
		ladder.ghosts.append(Ghost.from_dict(raw))
	ladder.next_ghost_id = int(d.get("next_ghost_id", 1))
	return ladder
