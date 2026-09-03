class_name CombatEngine
extends RefCounted
## The rules of a fight. Static functions that mutate a FightState and
## return the events they produced. Pure with respect to the scene tree.


## `mutation` is the tier's rule (spec §2), applied after the enemies exist and
## before the first turn, so a status it grants is already in the intent the
## player reads. Null on tier 1, which is every floor of the authored dungeon.
static func start_fight(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int,
		rng: Rng, mutation: MutationDef = null, hero_trait: TraitDef = null) -> FightState:
	var s := FightState.new()
	s.content = content
	s.rng = rng
	s.floor = floor
	s.tier = Biomes.tier_of(content, floor)
	s.hero_trait = hero_trait
	s.hero_hp = hero.hp
	s.hero_max_hp = hero.max_hp
	s.blessing = hero.blessing
	s.stats = hero.stats.duplicate()
	s.relics = hero.relics.duplicate()
	var focus := int(s.stats.get("focus", 0))
	var balance := content.balance
	s.max_energy = int(balance.get("base_energy", 3)) + _thresholds_met(focus, balance.get("focus_energy_thresholds", []))
	s.draw_per_turn = int(balance.get("base_draw", 5)) + _thresholds_met(focus, balance.get("focus_draw_thresholds", []))
	var max_uid := 0
	for card in hero.deck:
		s.draw_pile.append(card.clone())
		max_uid = maxi(max_uid, card.uid)
	s.next_uid = max_uid + 1000
	s.rng.shuffle("deck", s.draw_pile)
	s.emit({"type": "fight_start", "floor": floor})
	for enemy_id in enemy_ids:
		EnemyAI.spawn(s, String(enemy_id))
	Mutations.apply(s, mutation)
	Relics.fire(s, "on_fight_start")
	_begin_player_turn(s)
	return s


static func _thresholds_met(value: int, thresholds: Array) -> int:
	var n := 0
	for t in thresholds:
		if value >= int(t):
			n += 1
	return n


static func legal_actions(s: FightState) -> Array:
	var out: Array = []
	if s.is_over():
		return out
	for i in s.hand.size():
		var card := s.hand[i]
		var def := s.card_def(card)
		var cost := def.cost_for(card.upgraded)
		if cost == CardDef.COST_X:
			cost = 0
		if cost > s.energy:
			continue
		if def.target == "enemy":
			for t in s.living_enemy_indices():
				out.append({"kind": "play", "hand_index": i, "target": t})
		else:
			out.append({"kind": "play", "hand_index": i, "target": -1})
	out.append({"kind": "end_turn"})
	return out


static func apply(s: FightState, action: Dictionary) -> Array:
	if s.is_over():
		return []
	var start := s.events.size()
	match String(action.get("kind", "")):
		"play":
			_play(s, int(action.get("hand_index", -1)), int(action.get("target", -1)))
		"end_turn":
			_end_turn(s)
		_:
			push_error("unknown action kind: " + String(action.get("kind", "")))
	return s.events.slice(start)


static func _play(s: FightState, hand_index: int, target: int) -> void:
	if hand_index < 0 or hand_index >= s.hand.size():
		push_error("play: bad hand index %d" % hand_index)
		return
	var card := s.hand[hand_index]
	var def := s.card_def(card)
	var cost := def.cost_for(card.upgraded)
	var x := 0
	if cost == CardDef.COST_X:
		x = s.energy
		cost = s.energy
	if cost > s.energy:
		push_error("play: cannot afford %s" % card.def_id)
		return
	if def.target == "enemy":
		if target < 0 or target >= s.enemies.size() or not s.enemies[target].alive:
			var living := s.living_enemy_indices()
			if living.is_empty():
				return
			target = living[0]
	s.energy -= cost
	s.hand.remove_at(hand_index)
	s.cards_played_this_turn += 1
	s.emit({"type": "card_played", "uid": card.uid, "card": card.def_id, "target": target, "cost": cost})
	var is_attack := def.type == "attack"
	if is_attack and s.hero_status("bleed") > 0:
		EffectResolver.direct_damage_hero(s, s.hero_status("bleed"), "bleed")
	var ctx := {"target": target, "card_target": def.target, "tags": def.tags, "is_attack": is_attack, "x": x, "exhaust": false}
	EffectResolver.resolve(s, def.effects_for(card.upgraded), {"kind": "hero"}, ctx)
	Relics.fire(s, "on_card_played")
	if def.type == "power" or def.has_keyword("exhaust") or bool(ctx.get("exhaust", false)):
		s.exhaust_pile.append(card)
		s.emit({"type": "card_exhausted", "uid": card.uid, "card": card.def_id})
	else:
		s.discard_pile.append(card)
	_check_end(s)


static func _end_turn(s: FightState) -> void:
	s.emit({"type": "turn_end", "turn": s.turn})
	StatusSystem.hero_turn_end(s)
	if _check_end(s):
		return
	s.discard_hand()
	for i in s.enemies.size():
		if not s.enemies[i].alive:
			continue
		StatusSystem.enemy_turn_start(s, i)
		if _check_end(s):
			return
		if not s.enemies[i].alive:
			continue
		EnemyAI.execute_move(s, i)
		if _check_end(s):
			return
		StatusSystem.enemy_turn_end(s, i)
		if _check_end(s):
			return
	for i in s.enemies.size():
		if s.enemies[i].alive and s.enemies[i].next_move == "":
			EnemyAI.choose_next_move(s, i)
	if s.turn >= int(s.content.balance.get("turn_cap", 30)):
		s.phase = "lost"
		s.emit({"type": "fight_lost", "reason": "turn_cap"})
		return
	_begin_player_turn(s)


static func _begin_player_turn(s: FightState) -> void:
	s.turn += 1
	s.cards_played_this_turn = 0
	s.emit({"type": "turn_start", "turn": s.turn})
	StatusSystem.hero_turn_start(s, s.turn > 1)
	if _check_end(s):
		return
	s.energy = s.max_energy
	s.emit({"type": "energy_changed", "energy": s.energy})
	Relics.fire(s, "on_turn_start")
	s.draw(s.draw_per_turn)


static func _check_end(s: FightState) -> bool:
	if s.phase != "player":
		return true
	if s.hero_hp <= 0:
		s.phase = "lost"
		s.emit({"type": "fight_lost", "reason": "hero_died"})
		return true
	if s.all_enemies_dead():
		s.phase = "won"
		Relics.fire(s, "on_fight_end")
		s.emit({"type": "fight_won", "turns": s.turn, "hp": s.hero_hp})
		return true
	return false
