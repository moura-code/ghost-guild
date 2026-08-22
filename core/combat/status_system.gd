class_name StatusSystem
extends RefCounted
## Start/end-of-turn status processing for hero and enemies.


static func decay(statuses: Dictionary, name: String) -> void:
	if not statuses.has(name):
		return
	var left := int(statuses[name]) - 1
	if left <= 0:
		statuses.erase(name)
	else:
		statuses[name] = left


static func hero_turn_start(s: FightState, reset_block: bool) -> void:
	if reset_block:
		s.hero_block = 0
	var vigil := s.hero_status("vigil")
	if vigil > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "vigil", "amount": vigil})
		s.hero_block += vigil
		s.emit({"type": "block_gained", "target": "hero", "amount": vigil})
	var regen := s.hero_status("regen")
	if regen > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "regen", "amount": regen})
		EffectResolver.heal_hero(s, regen)
		decay(s.statuses, "regen")
	var poison := s.hero_status("poison")
	if poison > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "poison", "amount": poison})
		EffectResolver.direct_damage_hero(s, poison, "poison")
		decay(s.statuses, "poison")
	var knell := s.hero_status("knell")
	if knell > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "knell", "amount": knell})
		for i in s.living_enemy_indices():
			EffectResolver.direct_damage_enemy(s, i, knell, "knell")


static func hero_turn_end(s: FightState) -> void:
	var burn := s.hero_status("burn")
	if burn > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "burn", "amount": burn})
		EffectResolver.direct_damage_hero(s, burn, "burn")
		decay(s.statuses, "burn")
	decay(s.statuses, "weak")
	decay(s.statuses, "vulnerable")
	decay(s.statuses, "bleed")


static func enemy_turn_start(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	e.block = 0
	var poison := e.status("poison")
	if poison > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "poison", "amount": poison})
		EffectResolver.direct_damage_enemy(s, index, poison, "poison")
		decay(e.statuses, "poison")
	if not e.alive:
		return
	var regen := e.status("regen")
	if regen > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "regen", "amount": regen})
		e.hp = mini(e.max_hp, e.hp + regen)
		s.emit({"type": "heal", "target": "enemy", "index": index, "amount": regen, "hp": e.hp})
		decay(e.statuses, "regen")


static func enemy_turn_end(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	var burn := e.status("burn")
	if burn > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "burn", "amount": burn})
		EffectResolver.direct_damage_enemy(s, index, burn, "burn")
		decay(e.statuses, "burn")
	decay(e.statuses, "weak")
	decay(e.statuses, "vulnerable")
	decay(e.statuses, "bleed")
