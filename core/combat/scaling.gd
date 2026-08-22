class_name Scaling
extends RefCounted
## Per-floor enemy curves. Floor 1 is the unscaled base.


static func enemy_hp(base: int, floor: int, balance: Dictionary) -> int:
	var growth := float(balance.get("enemy_hp_growth", 1.06))
	return maxi(1, int(round(base * pow(growth, floor - 1))))


static func enemy_damage(base: int, floor: int, balance: Dictionary) -> int:
	var growth := float(balance.get("enemy_damage_growth", 1.04))
	return maxi(0, int(round(base * pow(growth, floor - 1))))
