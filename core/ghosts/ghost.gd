class_name Ghost
extends RefCounted
## A ghost record (spec §5.1): who they were, where they stand, how they
## fought. `strength` is the cached base kills/hour before multipliers.

var id: int = 0
var name: String = ""
var class_id: String = ""
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var max_hp: int = 1
var floor: int = 1
var kind: String = "true"
var source_id: int = 0
var cause: String = "watch"
var killer: String = ""
var prepared: bool = false
var restless: bool = false
var created_at: int = 0
var epitaph_key: String = ""
var measured: Dictionary = {"fights": 0, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}
var strength: float = 0.0
var fixed_strength: bool = false
## How this ghost fights (spec 3.3, 5.2). Inherited from the hero, and the
## reason "the ghost fights as you fought" is true of the simulated half of
## its strength and not only the measured half.
var rules: Array[String] = []


static func from_run(hero: Hero, outcome: Dictionary, p_measured: Dictionary, p_created_at: int) -> Ghost:
	var g := Ghost.new()
	g.name = hero.name
	g.class_id = hero.class_id
	for card in hero.deck:
		g.deck.append(card.clone())
	g.relics = hero.relics.duplicate()
	var bonus: Dictionary = outcome.get("stat_bonus", {})
	for key in hero.stats:
		g.stats[key] = int(hero.stats[key]) + int(bonus.get(key, 0))
	g.max_hp = hero.max_hp
	g.floor = int(outcome.get("floor", 1))
	g.kind = "true"
	var outcome_kind := String(outcome.get("kind", "death"))
	g.cause = "watch" if outcome_kind == "watch" else "death"
	g.killer = String(outcome.get("killer", ""))
	g.prepared = g.cause == "watch"
	g.restless = g.cause == "death"
	g.created_at = p_created_at
	g.measured = p_measured.duplicate()
	g.rules = hero.rules.duplicate()
	if g.cause == "watch":
		g.epitaph_key = "epitaph.watch"
	elif g.killer != "":
		g.epitaph_key = "epitaph.death"
	else:
		g.epitaph_key = "epitaph.death_unknown"
	return g


## The guild's own dead (spec §3.5). A true ghost for every purpose that
## matters -- the waypoint, echoes -- but NOT prepared: only manual play earns
## the +25%, which is the whole reason to still play the game yourself.
static func from_expedition(hero: Hero, p_floor: int, p_created_at: int) -> Ghost:
	var g := Ghost.new()
	g.name = hero.name
	g.class_id = hero.class_id
	for card in hero.deck:
		g.deck.append(card.clone())
	g.relics = hero.relics.duplicate()
	for key in hero.stats:
		g.stats[key] = int(hero.stats[key])
	g.max_hp = hero.max_hp
	g.floor = p_floor
	g.kind = "expedition"
	g.cause = "watch"
	g.prepared = false
	g.restless = false
	g.created_at = p_created_at
	g.rules = hero.rules.duplicate()
	g.epitaph_key = "epitaph.expedition"
	return g


## Whether this ghost counts as one of the guild's own rather than as a copy.
##
## Spec §5.1: an expedition ghost "counts as true for the waypoint and as an
## echo source". There were six scattered `kind == "true"` checks before this
## existed, and adding a second true-ish kind to all six independently is how a
## ghost ends up real on one screen and a copy on the next.
func is_true() -> bool:
	return kind == "true" or kind == "expedition"


static func founder(content: Content, p_created_at: int) -> Ghost:
	var klass: ClassDef = content.classes[Classes.starting(content)]
	var g := Ghost.new()
	g.name = content.text("ghost.founder.name")
	g.class_id = klass.id
	var uid := 1
	for card_id in klass.starting_deck:
		g.deck.append(CardInstance.new(uid, card_id, false))
		uid += 1
	g.relics.append(klass.relic)
	for key in klass.stats:
		g.stats[key] = int(klass.stats[key])
	g.max_hp = HeroSnapshot.max_hp_for(klass.base_hp, int(g.stats["vigor"]))
	g.floor = 1
	g.cause = "founder"
	g.created_at = p_created_at
	g.epitaph_key = "epitaph.founder"
	g.strength = float(content.balance.get("founder_strength", 40))
	g.fixed_strength = true
	return g


func snapshot() -> HeroSnapshot:
	var s := HeroSnapshot.new()
	s.class_id = class_id
	for card in deck:
		s.deck.append(card.clone())
	s.relics = relics.duplicate()
	s.stats = stats.duplicate()
	s.max_hp = max_hp
	s.hp = max_hp
	return s


func epitaph(content: Content) -> String:
	var killer_name := ""
	if killer != "" and content.enemies.has(killer):
		var def: EnemyDef = content.enemies[killer]
		killer_name = content.text(def.name_key)
	return content.text(epitaph_key).format({"name": name, "floor": floor, "killer": killer_name})


func clone_as_echo(p_floor: int, p_created_at: int) -> Ghost:
	var e := Ghost.from_dict(to_dict())
	e.id = 0
	e.kind = "echo"
	e.source_id = id
	e.floor = p_floor
	e.prepared = false
	e.restless = restless
	e.created_at = p_created_at
	e.fixed_strength = false
	e.strength = 0.0
	return e


func to_dict() -> Dictionary:
	var cards: Array = []
	for card in deck:
		cards.append(card.to_dict())
	return {
		"id": id, "name": name, "class_id": class_id, "deck": cards, "relics": relics.duplicate(),
		"stats": stats.duplicate(), "max_hp": max_hp, "floor": floor, "kind": kind, "source_id": source_id,
		"cause": cause, "killer": killer, "prepared": prepared, "restless": restless, "created_at": created_at,
		"epitaph_key": epitaph_key, "measured": measured.duplicate(), "strength": strength, "fixed_strength": fixed_strength,
		"rules": rules.duplicate(),
	}


static func from_dict(d: Dictionary) -> Ghost:
	var g := Ghost.new()
	g.id = int(d.get("id", 0))
	g.name = String(d.get("name", ""))
	g.class_id = String(d.get("class_id", ""))
	for raw in d.get("deck", []):
		g.deck.append(CardInstance.from_dict(raw))
	for r in d.get("relics", []):
		g.relics.append(String(r))
	var s: Dictionary = d.get("stats", {})
	for key in ["might", "wit", "vigor", "focus"]:
		g.stats[key] = int(s.get(key, 0))
	g.max_hp = int(d.get("max_hp", 1))
	g.floor = int(d.get("floor", 1))
	g.kind = String(d.get("kind", "true"))
	g.source_id = int(d.get("source_id", 0))
	g.cause = String(d.get("cause", "watch"))
	g.killer = String(d.get("killer", ""))
	g.prepared = bool(d.get("prepared", false))
	g.restless = bool(d.get("restless", false))
	g.created_at = int(d.get("created_at", 0))
	g.epitaph_key = String(d.get("epitaph_key", ""))
	var m: Dictionary = d.get("measured", {})
	g.measured = {"fights": int(m.get("fights", 0)), "wins": int(m.get("wins", 0)), "win_rate": float(m.get("win_rate", 0.0)), "avg_turns": float(m.get("avg_turns", 0.0))}
	g.strength = float(d.get("strength", 0.0))
	g.fixed_strength = bool(d.get("fixed_strength", false))
	for raw in d.get("rules", []):
		g.rules.append(String(raw))
	return g
