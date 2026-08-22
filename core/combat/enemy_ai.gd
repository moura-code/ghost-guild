class_name EnemyAI
extends RefCounted
## Enemy move selection and execution. Patterns come from EnemyDef.pattern;
## move choice uses the "enemy_ai" rng stream so fights replay from a seed.

const MAX_ENEMIES := 5


static func spawn(s: FightState, enemy_id: String) -> int:
	if s.living_enemy_indices().size() >= MAX_ENEMIES:
		s.emit({"type": "summon_failed", "enemy": enemy_id})
		return -1
	var def: EnemyDef = s.content.enemies[enemy_id]
	var e := EnemyState.new()
	e.def_id = enemy_id
	e.max_hp = Scaling.enemy_hp(def.hp, s.floor, s.content.balance)
	e.hp = e.max_hp
	s.enemies.append(e)
	var index := s.enemies.size() - 1
	choose_next_move(s, index)
	return index


static func choose_next_move(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	var def: EnemyDef = s.content.enemies[e.def_id]
	var kind := String(def.pattern.get("kind", "sequence"))
	var moves: Array = def.pattern.get("moves", [])
	var chosen := ""
	if kind == "sequence":
		chosen = String(moves[e.pattern_index % moves.size()])
		e.pattern_index += 1
	else:
		var no_repeat := bool(def.pattern.get("no_repeat", false))
		var candidates: Array = []
		var weights: Array = []
		for entry in moves:
			var move_id := String(entry["move"])
			if no_repeat and move_id == e.last_move and moves.size() > 1:
				continue
			candidates.append(move_id)
			weights.append(float(entry["weight"]))
		chosen = String(candidates[s.rng.weighted_pick("enemy_ai", weights)])
	e.next_move = chosen
	s.emit({"type": "enemy_intent", "index": index, "move": chosen, "intent": intent_of(s, index)})


static func scaled_damage(s: FightState, index: int, move: Dictionary) -> int:
	var e := s.enemies[index]
	return Scaling.enemy_damage(int(move.get("damage", 0)), s.floor, s.content.balance) + e.status("might_buff")


static func intent_of(s: FightState, index: int) -> Dictionary:
	var e := s.enemies[index]
	var def: EnemyDef = s.content.enemies[e.def_id]
	var move: Dictionary = def.moves.get(e.next_move, {})
	var intent := String(move.get("intent", ""))
	var out := {"kind": intent}
	match intent:
		"attack":
			out["damage"] = scaled_damage(s, index, move)
			out["hits"] = int(move.get("hits", 1))
		"block":
			out["block"] = int(move.get("block", 0))
		"buff", "debuff":
			out["status"] = String(move.get("status", ""))
			out["stacks"] = int(move.get("stacks", 1))
		"summon":
			out["enemy"] = String(move.get("enemy", ""))
	return out


static func execute_move(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive or e.next_move == "":
		return
	var def: EnemyDef = s.content.enemies[e.def_id]
	var move: Dictionary = def.moves[e.next_move]
	var intent := String(move.get("intent", ""))
	var hp_before := s.hero_hp
	s.emit({"type": "enemy_move", "index": index, "move": e.next_move, "intent": intent})
	match intent:
		"attack":
			var dmg := scaled_damage(s, index, move)
			for i in int(move.get("hits", 1)):
				EffectResolver.hit_hero(s, dmg, index, true)
			if e.alive and e.status("bleed") > 0:
				EffectResolver.direct_damage_enemy(s, index, e.status("bleed"), "bleed")
			if move.has("status"):
				EffectResolver.apply_status(s, {"kind": "hero"}, String(move["status"]), int(move.get("stacks", 1)))
		"block":
			var amount := int(move.get("block", 0))
			e.block += amount
			s.emit({"type": "block_gained", "target": "enemy", "index": index, "amount": amount})
		"buff":
			EffectResolver.apply_status(s, {"kind": "enemy", "index": index}, String(move.get("status", "")), int(move.get("stacks", 1)))
		"debuff":
			EffectResolver.apply_status(s, {"kind": "hero"}, String(move.get("status", "")), int(move.get("stacks", 1)))
		"summon":
			var enemy_id := String(move.get("enemy", ""))
			var new_index := spawn(s, enemy_id)
			if new_index >= 0:
				s.emit({"type": "summon", "index": new_index, "enemy": enemy_id, "by": index})
	e.last_move = e.next_move
	e.next_move = ""
	if s.hero_hp < hp_before:
		Relics.fire(s, "on_damage_taken")
