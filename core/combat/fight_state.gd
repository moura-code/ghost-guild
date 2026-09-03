class_name FightState
extends RefCounted
## The complete state of one fight. Mutated in place by the engine;
## clone() returns an independent copy for what-if searches. Events are
## appended to `events` and never cloned.
## CardInstances are immutable during a fight, so clones share them;
## HeroSnapshot.clone() still deep-copies because the run layer mutates
## upgrades between fights.

var content: Content
var rng: Rng
var floor: int = 1
## Which cycle of the dungeon this fight is in (§2). Always 1 for the first
## thirty floors, which is what keeps every existing number unchanged.
var tier: int = 1
var turn: int = 0
var phase: String = "player"
var hero_hp: int = 1
var hero_max_hp: int = 1
var hero_block: int = 0
var energy: int = 0
var max_energy: int = 3
var draw_per_turn: int = 5
## The Legend's Blessing on hero damage and block (spec §4.4). Exactly 1.0
## until the first prestige, which is what keeps every existing number and
## every demo unchanged.
var blessing: float = 1.0
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var statuses: Dictionary = {}
var relics: Array[String] = []
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var enemies: Array[EnemyState] = []
var cards_played_this_turn: int = 0
var next_uid: int = 1000
var pending_x: int = 0
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func card_def(card: CardInstance) -> CardDef:
	return content.cards[card.def_id]


func might() -> int:
	return int(stats.get("might", 0)) + int(statuses.get("might_buff", 0))


func wit() -> int:
	return int(stats.get("wit", 0)) + int(statuses.get("wit_buff", 0))


func hero_status(name: String) -> int:
	return int(statuses.get(name, 0))


func living_enemy_indices() -> Array[int]:
	var out: Array[int] = []
	for i in enemies.size():
		if enemies[i].alive:
			out.append(i)
	return out


func all_enemies_dead() -> bool:
	return living_enemy_indices().is_empty()


func is_over() -> bool:
	return phase != "player"


func hand_limit() -> int:
	return int(content.balance.get("hand_limit", 10))


func new_card(def_id: String, upgraded: bool = false) -> CardInstance:
	var card := CardInstance.new(next_uid, def_id, upgraded)
	next_uid += 1
	return card


func draw(n: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in n:
		if hand.size() >= hand_limit():
			emit({"type": "hand_full"})
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			reshuffle()
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
		emit({"type": "card_drawn", "uid": card.uid, "card": card.def_id})
	return drawn


func reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	rng.shuffle("deck", draw_pile)
	emit({"type": "reshuffle", "count": draw_pile.size()})


func discard_hand() -> void:
	var kept: Array[CardInstance] = []
	for card in hand:
		if card_def(card).has_keyword("retain"):
			kept.append(card)
		else:
			discard_pile.append(card)
			emit({"type": "card_discarded", "uid": card.uid, "card": card.def_id})
	hand = kept


func clone() -> FightState:
	var s := FightState.new()
	s.content = content
	s.rng = rng.clone()
	s.floor = floor
	s.tier = tier
	s.turn = turn
	s.phase = phase
	s.hero_hp = hero_hp
	s.hero_max_hp = hero_max_hp
	s.hero_block = hero_block
	s.energy = energy
	s.max_energy = max_energy
	s.draw_per_turn = draw_per_turn
	s.blessing = blessing
	s.stats = stats.duplicate()
	s.statuses = statuses.duplicate()
	s.relics = relics.duplicate()
	s.draw_pile = draw_pile.duplicate()
	s.hand = hand.duplicate()
	s.discard_pile = discard_pile.duplicate()
	s.exhaust_pile = exhaust_pile.duplicate()
	for e in enemies:
		s.enemies.append(e.clone())
	s.cards_played_this_turn = cards_played_this_turn
	s.next_uid = next_uid
	s.pending_x = pending_x
	return s
