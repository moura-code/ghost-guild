class_name Rewards
extends RefCounted
## Card and relic offers and the Coin/Soul a fight pays (spec §3.2, §4.1).
## All randomness goes through the "reward" stream of the Rng it is given.

const OFFER_SIZE := 3


static func soul_for(floor: int, balance: Dictionary) -> float:
	return pow(float(balance.get("soul_per_kill_growth", 1.3)), floor)


static func coin_for(kind: String, floor: int, balance: Dictionary) -> int:
	var base := int(balance.get("coin_per_fight_base", 10)) + int(balance.get("coin_per_fight_growth", 2)) * floor
	match kind:
		"elite":
			return int(round(base * float(balance.get("coin_elite_multiplier", 2.0))))
		"boss":
			return int(round(base * float(balance.get("coin_boss_multiplier", 3.0))))
	return base


static func pool_cards(content: Content, pools: Array, rarities: Array) -> Array[String]:
	var ids: Array[String] = []
	var keys: Array = content.cards.keys()
	keys.sort()
	for id in keys:
		var card: CardDef = content.cards[id]
		if pools.has(card.pool) and rarities.has(card.rarity):
			ids.append(String(id))
	return ids


static func card_offer(content: Content, pools: Array, rng: Rng, balance: Dictionary, count: int = OFFER_SIZE, rare_only: bool = false) -> Array[String]:
	var weights_cfg: Dictionary = balance.get("reward_rarity_weights", {"common": 60, "uncommon": 30, "rare": 10})
	var rarities: Array = ["rare"] if rare_only else ["common", "uncommon", "rare"]
	var candidates := pool_cards(content, pools, rarities)
	var offer: Array[String] = []
	while offer.size() < count and not candidates.is_empty():
		var weights: Array = []
		for id in candidates:
			var card: CardDef = content.cards[id]
			weights.append(float(weights_cfg.get(card.rarity, 1)))
		var i := rng.weighted_pick("reward", weights)
		offer.append(candidates[i])
		candidates.remove_at(i)
	return offer


static func relic_offer(content: Content, owned: Array, rng: Rng) -> String:
	var keys: Array = content.relics.keys()
	keys.sort()
	var candidates: Array = []
	for id in keys:
		if not owned.has(id):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	return String(rng.pick("reward", candidates))
