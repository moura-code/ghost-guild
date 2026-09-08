class_name Scaling
extends RefCounted
## Per-floor enemy curves. Floor 1 is the unscaled base.


## The jump per tier (§2), on top of the per-floor curve.
##
## It is a separate multiplier because the per-floor curve already compounds
## across the whole depth: without a jump, floor 31 is 1.06 times floor 30 and
## walking into the next cycle costs nothing. Tier 1 raises it to the zeroth
## power, so the first thirty floors are byte-identical to what they always
## were.
static func tier_step(tier: int, balance: Dictionary, key: String) -> float:
	return pow(float(balance.get(key, 1.0)), float(maxi(1, tier) - 1))


## `seal` is the Depth Seal the run is under (spec §6.2): opt-in difficulty,
## 1.0 at no seal, so an unsealed descent is the one the game is balanced
## around and every existing number is untouched.
static func enemy_hp(base: int, floor: int, balance: Dictionary, tier: int = 1,
		seal: float = 1.0) -> int:
	var growth := float(balance.get("enemy_hp_growth", 1.06))
	var step := tier_step(tier, balance, "tier_hp_jump")
	return maxi(1, int(round(base * pow(growth, floor - 1) * step * seal)))


static func enemy_damage(base: int, floor: int, balance: Dictionary, tier: int = 1,
		seal: float = 1.0) -> int:
	var growth := float(balance.get("enemy_damage_growth", 1.04))
	var step := tier_step(tier, balance, "tier_damage_jump")
	return maxi(0, int(round(base * pow(growth, floor - 1) * step * seal)))
