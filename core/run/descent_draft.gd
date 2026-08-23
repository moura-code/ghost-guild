class_name DescentDraft
extends RefCounted
## One pick-of-three per skipped floor (spec §3.2), granted once per floor
## per hero: floors already offered to this hero are skipped.


static func offers(content: Content, hero: Hero, biome: BiomeDef, entry_floor: int, run_seed: int) -> Array:
	var out: Array = []
	var klass: ClassDef = content.classes[hero.class_id]
	var pools: Array = [klass.pool, biome.card_pool]
	for f in range(1, entry_floor):
		if hero.picks_taken.has(f):
			continue
		var rng := Rng.new(hash([run_seed, "draft", f]))
		var cards := Rewards.card_offer(content, pools, rng, content.balance)
		out.append({"floor": f, "cards": cards.duplicate()})
	return out
