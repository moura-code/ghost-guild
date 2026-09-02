class_name EffectResolver
extends RefCounted
## Executes effect op lists from cards and relics, and owns the damage
## pipeline used by enemy moves as well. Everything here is static and
## mutates the FightState it is given.


static func resolve(s: FightState, effects: Array, source: Dictionary, ctx: Dictionary) -> void:
	for raw in effects:
		var e: Dictionary = raw
		var op := String(e.get("op", ""))
		match op:
			"damage":
				_damage(s, e, ctx)
			"block":
				_block(s, e, ctx)
			"apply_status":
				_apply_status_op(s, e, ctx)
			"draw":
				s.draw(_amount(e, "amount", ctx))
			"energy":
				s.energy += _amount(e, "amount", ctx)
				s.emit({"type": "energy_changed", "energy": s.energy})
			"heal":
				heal_hero(s, _amount(e, "amount", ctx))
			"exhaust_self":
				ctx["exhaust"] = true
			"add_card":
				_add_card(s, e)
			"coin":
				s.emit({"type": "coin", "amount": _amount(e, "amount", ctx)})
			_:
				push_error("unknown effect op: " + op)


static func _amount(e: Dictionary, key: String, ctx: Dictionary) -> int:
	var v: Variant = e.get(key, 0)
	if v is String:
		return int(ctx.get("x", 0))
	return int(v)


static func _enemy_targets(s: FightState, e: Dictionary, ctx: Dictionary) -> Array[int]:
	var mode := String(e.get("target", "target"))
	var card_target := String(ctx.get("card_target", "enemy"))
	var out: Array[int] = []
	if mode == "self":
		return out
	if mode == "all_enemies" or (mode == "target" and card_target == "all_enemies"):
		return s.living_enemy_indices()
	var t := int(ctx.get("target", -1))
	if t >= 0 and t < s.enemies.size() and s.enemies[t].alive:
		out.append(t)
	return out


## Applies the Blessing to a number. Exactly the identity at 1.0 -- integer
## in, integer out, no rounding drift -- which is what lets every demo in the
## repo stay byte-identical until a player prestiges.
static func blessed(amount: int, blessing: float) -> int:
	if is_equal_approx(blessing, 1.0):
		return amount
	return int(round(float(amount) * blessing))


static func _damage(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var base := _amount(e, "amount", ctx)
	if String(e.get("scale", "")) == "might":
		base += s.might()
	# The Legend's Blessing, after Might rather than before it: it multiplies
	# what the hero deals, which is the card plus the stat (spec §4.4).
	base = blessed(base, s.blessing)
	var hits := int(e.get("hits", 1))
	var is_attack := bool(ctx.get("is_attack", false))
	var tags: Array = ctx.get("tags", [])
	for i in hits:
		for t in _enemy_targets(s, e, ctx):
			hit_enemy(s, t, base, is_attack, tags)


static func _block(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var amount := _amount(e, "amount", ctx)
	if String(e.get("scale", "")) == "wit":
		amount += s.wit()
	amount = blessed(amount, s.blessing)
	s.hero_block += amount
	s.emit({"type": "block_gained", "target": "hero", "amount": amount})


static func _apply_status_op(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var status := String(e.get("status", ""))
	var stacks := _amount(e, "stacks", ctx)
	if String(e.get("scale", "")) == "wit":
		stacks += s.wit()
	var mode := String(e.get("target", "target"))
	var card_target := String(ctx.get("card_target", "enemy"))
	if mode == "self" or (mode == "target" and (card_target == "self" or card_target == "none")):
		apply_status(s, {"kind": "hero"}, status, stacks)
		return
	for t in _enemy_targets(s, e, ctx):
		apply_status(s, {"kind": "enemy", "index": t}, status, stacks)


static func _add_card(s: FightState, e: Dictionary) -> void:
	var card := s.new_card(String(e.get("card", "")))
	var where := String(e.get("where", "hand"))
	match where:
		"hand":
			s.hand.append(card)
		"discard":
			s.discard_pile.append(card)
		"draw":
			s.draw_pile.append(card)
	s.emit({"type": "card_added", "uid": card.uid, "card": card.def_id, "where": where})


static func affinity_multiplier(s: FightState, tags: Array, enemy: EnemyState) -> float:
	var mult := 1.0
	var def: EnemyDef = s.content.enemies[enemy.def_id]
	for tag in tags:
		var row: Dictionary = s.content.affinity.get(String(tag), {})
		for enemy_tag in def.tags:
			mult *= float(row.get(enemy_tag, 1.0))
	return mult


static func hit_enemy(s: FightState, index: int, base: int, is_attack: bool, tags: Array) -> int:
	var e := s.enemies[index]
	if not e.alive:
		return 0
	var mult := 1.0
	if is_attack and s.hero_status("weak") > 0:
		mult *= float(s.content.balance.get("weak_multiplier", 0.75))
	if e.status("vulnerable") > 0:
		mult *= float(s.content.balance.get("vulnerable_multiplier", 1.5))
	mult *= affinity_multiplier(s, tags, e)
	var amount := int(floor(base * mult))
	var blocked := mini(e.block, amount)
	e.block -= blocked
	var dealt := amount - blocked
	e.hp -= dealt
	s.emit({"type": "damage", "target": "enemy", "index": index, "amount": dealt, "blocked": blocked, "hp": e.hp})
	if is_attack and e.status("thorns") > 0:
		direct_damage_hero(s, e.status("thorns"), "thorns")
	if e.hp <= 0:
		kill_enemy(s, index)
	return dealt


static func hit_hero(s: FightState, base: int, attacker_index: int, is_attack: bool) -> int:
	var attacker := s.enemies[attacker_index]
	var mult := 1.0
	if is_attack and attacker.status("weak") > 0:
		mult *= float(s.content.balance.get("weak_multiplier", 0.75))
	if s.hero_status("vulnerable") > 0:
		mult *= float(s.content.balance.get("vulnerable_multiplier", 1.5))
	var amount := int(floor(base * mult))
	var blocked := mini(s.hero_block, amount)
	s.hero_block -= blocked
	var dealt := amount - blocked
	s.hero_hp = maxi(0, s.hero_hp - dealt)
	s.emit({"type": "damage", "target": "hero", "amount": dealt, "blocked": blocked, "hp": s.hero_hp, "source": attacker_index})
	if is_attack and s.hero_status("thorns") > 0:
		direct_damage_enemy(s, attacker_index, s.hero_status("thorns"), "thorns")
	return dealt


static func direct_damage_hero(s: FightState, amount: int, cause: String) -> void:
	s.hero_hp = maxi(0, s.hero_hp - amount)
	s.emit({"type": "damage", "target": "hero", "amount": amount, "blocked": 0, "hp": s.hero_hp, "direct": true, "cause": cause})


static func direct_damage_enemy(s: FightState, index: int, amount: int, cause: String) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	e.hp -= amount
	s.emit({"type": "damage", "target": "enemy", "index": index, "amount": amount, "blocked": 0, "hp": e.hp, "direct": true, "cause": cause})
	if e.hp <= 0:
		kill_enemy(s, index)


static func kill_enemy(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	e.hp = 0
	e.alive = false
	e.block = 0
	s.emit({"type": "enemy_died", "index": index, "enemy": e.def_id})


static func heal_hero(s: FightState, amount: int) -> void:
	var before := s.hero_hp
	s.hero_hp = mini(s.hero_max_hp, s.hero_hp + amount)
	s.emit({"type": "heal", "target": "hero", "amount": s.hero_hp - before, "hp": s.hero_hp})


static func apply_status(s: FightState, who: Dictionary, status: String, stacks: int) -> void:
	if String(who.get("kind", "")) == "hero":
		s.statuses[status] = s.hero_status(status) + stacks
		s.emit({"type": "status_applied", "target": "hero", "status": status, "stacks": stacks, "total": s.statuses[status]})
		return
	var index := int(who.get("index", -1))
	var e := s.enemies[index]
	if not e.alive:
		return
	if status == "poison":
		stacks = int(floor(stacks * affinity_multiplier(s, ["poison"], e)))
	if stacks <= 0:
		return
	e.statuses[status] = e.status(status) + stacks
	s.emit({"type": "status_applied", "target": "enemy", "index": index, "status": status, "stacks": stacks, "total": e.statuses[status]})
