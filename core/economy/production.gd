class_name Production
extends RefCounted
## Soul per hour from the ladder, integrated by real time (spec §5.8):
## rate × elapsed, elapsed capped by the offline cap. Never per frame.


static func rate_per_hour(ladder: Ladder, balance: Dictionary, modifiers: Dictionary) -> float:
	return ladder.total_output(balance, modifiers)


static func accrue(rate: float, elapsed_seconds: int, cap_hours: float) -> Dictionary:
	var elapsed := maxi(0, elapsed_seconds)
	var cap := int(round(cap_hours * 3600.0))
	var counted := mini(elapsed, cap)
	return {
		"elapsed": elapsed,
		"counted": counted,
		"capped": elapsed > counted,
		"soul": rate * counted / 3600.0,
	}
