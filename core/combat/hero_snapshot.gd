class_name HeroSnapshot
extends RefCounted
## What the run layer hands the combat engine: the hero as they enter a fight.

var class_id: String = ""
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var hp: int = 1
var max_hp: int = 1


static func max_hp_for(base_hp: int, vigor: int) -> int:
	return base_hp + 3 * vigor


static func starter(content: Content, class_id: String) -> HeroSnapshot:
	var klass: ClassDef = content.classes[class_id]
	var h := HeroSnapshot.new()
	h.class_id = class_id
	var uid := 1
	for card_id in klass.starting_deck:
		h.deck.append(CardInstance.new(uid, card_id, false))
		uid += 1
	h.relics.append(klass.relic)
	for key in klass.stats:
		h.stats[key] = int(klass.stats[key])
	h.max_hp = max_hp_for(klass.base_hp, int(h.stats["vigor"]))
	h.hp = h.max_hp
	return h


func clone() -> HeroSnapshot:
	var h := HeroSnapshot.new()
	h.class_id = class_id
	for card in deck:
		h.deck.append(card.clone())
	h.relics = relics.duplicate()
	h.stats = stats.duplicate()
	h.hp = hp
	h.max_hp = max_hp
	return h
