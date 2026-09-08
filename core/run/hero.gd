class_name Hero
extends RefCounted
## The living hero. Persists between runs (deck, relics, stats, HP, Resolve,
## camp) until they become a ghost. Fights receive a HeroSnapshot built by
## snapshot(); the hero's own CardInstances are never handed to a fight.

const NAMES: Array[String] = [
	"Maren", "Osk", "Ilse", "Tobiah", "Wren", "Halvard", "Sabine", "Corvin", "Edda", "Lorcan",
	"Mirabel", "Anselm", "Greta", "Piet", "Rosalind", "Yorick", "Tamsin", "Bram", "Odile", "Casimir",
]

var id: int = 0
var name: String = ""
var class_id: String = ""
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var hp: int = 1
var max_hp: int = 1
var resolve: int = 1
var max_resolve: int = 1
var camp: int = 0
var picks_taken: Dictionary = {}
var next_uid: int = 1
var runs: int = 0
## Ordered, at most `PriorityRules.MAX`. How this hero's autopilot fights --
## for auto-draft and Expeditions now, and for the ghost they leave behind
## (spec 3.3). Empty until the player picks, which is what keeps every
## existing measurement of the game unchanged.
var rules: Array[String] = []


static func generate_name(rng: Rng) -> String:
	return String(rng.pick("names", NAMES))


static func create(content: Content, p_class_id: String, hero_name: String, meta_stats: Dictionary = {}, p_max_resolve: int = 1) -> Hero:
	var klass: ClassDef = content.classes[p_class_id]
	var h := Hero.new()
	h.name = hero_name
	h.class_id = p_class_id
	for key in klass.stats:
		h.stats[key] = int(klass.stats[key]) + int(meta_stats.get(key, 0))
	for card_id in klass.starting_deck:
		h.add_card(card_id)
	h.relics.append(klass.relic)
	h.max_hp = HeroSnapshot.max_hp_for(klass.base_hp, int(h.stats["vigor"]))
	h.hp = h.max_hp
	h.max_resolve = p_max_resolve
	h.resolve = p_max_resolve
	return h


func snapshot(bonus_stats: Dictionary = {}) -> HeroSnapshot:
	var s := HeroSnapshot.new()
	s.class_id = class_id
	for card in deck:
		s.deck.append(card.clone())
	s.relics = relics.duplicate()
	for key in stats:
		s.stats[key] = int(stats[key]) + int(bonus_stats.get(key, 0))
	s.max_hp = max_hp + 3 * int(bonus_stats.get("vigor", 0))
	s.hp = mini(hp, s.max_hp)
	return s


func add_card(def_id: String, upgraded: bool = false) -> CardInstance:
	var card := CardInstance.new(next_uid, def_id, upgraded)
	next_uid += 1
	deck.append(card)
	return card


func find_card(uid: int) -> CardInstance:
	for card in deck:
		if card.uid == uid:
			return card
	return null


func remove_card(uid: int) -> bool:
	for i in deck.size():
		if deck[i].uid == uid:
			deck.remove_at(i)
			return true
	return false


func upgrade_card(uid: int) -> bool:
	var card := find_card(uid)
	if card == null or card.upgraded:
		return false
	card.upgraded = true
	return true


func recompute_max_hp(content: Content) -> void:
	var klass: ClassDef = content.classes[class_id]
	var new_max := HeroSnapshot.max_hp_for(klass.base_hp, int(stats["vigor"]))
	hp = clampi(hp + maxi(0, new_max - max_hp), 0, new_max)
	max_hp = new_max


func to_dict() -> Dictionary:
	var cards: Array = []
	for card in deck:
		cards.append(card.to_dict())
	return {
		"id": id,
		"name": name,
		"class_id": class_id,
		"deck": cards,
		"relics": relics.duplicate(),
		"stats": stats.duplicate(),
		"hp": hp,
		"max_hp": max_hp,
		"resolve": resolve,
		"max_resolve": max_resolve,
		"camp": camp,
		"picks_taken": picks_taken.duplicate(),
		"next_uid": next_uid,
		"runs": runs,
		"rules": rules.duplicate(),
	}


static func from_dict(d: Dictionary) -> Hero:
	var h := Hero.new()
	h.id = int(d.get("id", 0))
	h.name = String(d.get("name", ""))
	h.class_id = String(d.get("class_id", ""))
	for raw in d.get("deck", []):
		h.deck.append(CardInstance.from_dict(raw))
	for r in d.get("relics", []):
		h.relics.append(String(r))
	var s: Dictionary = d.get("stats", {})
	for key in ["might", "wit", "vigor", "focus"]:
		h.stats[key] = int(s.get(key, 0))
	h.hp = int(d.get("hp", 1))
	h.max_hp = int(d.get("max_hp", 1))
	h.resolve = int(d.get("resolve", 1))
	h.max_resolve = int(d.get("max_resolve", 1))
	h.camp = int(d.get("camp", 0))
	var picks: Dictionary = d.get("picks_taken", {})
	for key in picks:
		h.picks_taken[int(key)] = true
	h.next_uid = int(d.get("next_uid", 1))
	h.runs = int(d.get("runs", 0))
	for raw in d.get("rules", []):
		h.rules.append(String(raw))
	return h
