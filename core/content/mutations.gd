class_name Mutations
extends RefCounted
## Which rule is in force on a floor (spec §2: "one mutation modifier per
## tier"), and applying it.
##
## A mutation is drawn per (biome, tier) from the campaign seed, so a cycle is
## a set of three rules the player learns and plans around, and a prestige --
## which is a new cycle, not a new seed -- rolls the next set. §6.1: "the
## dungeon regenerates with a new seed and a new mutation per biome."
##
## **Tier 1 has no mutations.** The first thirty floors are the game as it was
## authored and as every screenshot, demo and balance number in the repo was
## taken; a mutation there would rebalance the whole game by accident.


## The mutation in force on `floor`, or null on tier 1 and when there are none
## authored.
static func for_floor(content: Content, floor: int, campaign_seed: int) -> MutationDef:
	var tier := Biomes.tier_of(content, floor)
	if tier <= 1 or content.mutations.is_empty():
		return null
	var ids: Array = content.mutations.keys()
	ids.sort()
	# Deterministic from the seed and the (biome, tier) pair. Two floors of the
	# same biome in the same cycle are under the same rule; the same biome one
	# cycle deeper is not.
	var rng := Rng.new(hash([campaign_seed, "mutation", Biomes.for_floor(content, floor).id, tier]))
	return content.mutations[String(rng.pick("mutation", ids))]


## Applies the floor's mutation to a fight that has just started.
##
## Called from `CombatEngine.start_fight`, after the enemies are spawned and
## before the first turn begins, so a status it grants is already in the
## intent the player reads.
static func apply(s: FightState, mutation: MutationDef) -> void:
	if mutation == null:
		return
	match mutation.op:
		"enemy_status":
			for i in s.living_enemy_indices():
				EffectResolver.apply_status(s, {"kind": "enemy", "index": i},
					mutation.status, mutation.stacks)
		"hero_status":
			EffectResolver.apply_status(s, {"kind": "hero"}, mutation.status, mutation.stacks)
		"hero_draw":
			s.draw_per_turn = maxi(1, s.draw_per_turn + int(mutation.amount))
		"hero_energy":
			s.max_energy = maxi(1, s.max_energy + int(mutation.amount))
		"enemy_hp":
			for e in s.enemies:
				var enemy := e as EnemyState
				enemy.max_hp = maxi(1, int(round(float(enemy.max_hp) * mutation.amount)))
				enemy.hp = enemy.max_hp
	s.emit({"type": "mutation", "id": mutation.id})
