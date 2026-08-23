class_name Onboarding
extends RefCounted
## The first twenty minutes (spec §3.4): the Founder is seeded by the
## campaign, the first death unlocks Take the Watch, the first Tend is free.

var first_death_seen: bool = false
var watch_unlocked: bool = false
var free_tend_available: bool = true
var founder_seeded: bool = false


func on_run_end(outcome: Dictionary) -> Array:
	if String(outcome.get("kind", "")) != "death" or first_death_seen:
		return []
	first_death_seen = true
	watch_unlocked = true
	return [{"type": "first_death", "floor": int(outcome.get("floor", 1))}, {"type": "watch_unlocked"}]


func consume_free_tend() -> bool:
	if not free_tend_available:
		return false
	free_tend_available = false
	return true


func to_dict() -> Dictionary:
	return {"first_death_seen": first_death_seen, "watch_unlocked": watch_unlocked, "free_tend_available": free_tend_available, "founder_seeded": founder_seeded}


static func from_dict(d: Dictionary) -> Onboarding:
	var o := Onboarding.new()
	o.first_death_seen = bool(d.get("first_death_seen", false))
	o.watch_unlocked = bool(d.get("watch_unlocked", false))
	o.free_tend_available = bool(d.get("free_tend_available", true))
	o.founder_seeded = bool(d.get("founder_seeded", false))
	return o
