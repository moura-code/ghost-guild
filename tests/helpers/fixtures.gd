class_name TestFixtures
extends RefCounted
## Builders for engine tests. Uses the real slice content so tests exercise
## the same data the game ships.

static var _content: Content


static func content() -> Content:
	if _content == null:
		_content = Content.load_from("res://data")
	return _content


static func bare_state(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState:
	var s := FightState.new()
	s.content = content()
	s.rng = Rng.new(seed)
	s.floor = floor
	s.hero_hp = 70
	s.hero_max_hp = 70
	s.energy = 3
	s.max_energy = 3
	s.draw_per_turn = 5
	for enemy_id in enemy_ids:
		var def: EnemyDef = content().enemies[String(enemy_id)]
		var e := EnemyState.new()
		e.def_id = String(enemy_id)
		e.max_hp = Scaling.enemy_hp(def.hp, floor, content().balance)
		e.hp = e.max_hp
		s.enemies.append(e)
	return s


static func give_hand(s: FightState, card_ids: Array, upgraded: bool = false) -> void:
	s.hand.clear()
	for id in card_ids:
		s.hand.append(s.new_card(String(id), upgraded))


static func fill_draw(s: FightState, card_ids: Array) -> void:
	s.draw_pile.clear()
	for id in card_ids:
		s.draw_pile.append(s.new_card(String(id)))


static func events_of(s: FightState, type: String) -> Array:
	var out: Array = []
	for ev in s.events:
		if ev["type"] == type:
			out.append(ev)
	return out
