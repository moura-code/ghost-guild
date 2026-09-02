class_name ContentValidator
extends RefCounted
## Checks loaded content for broken references and malformed data.
## Returns every problem found; an empty array means the content is valid.

const OPS: Array[String] = ["damage", "block", "apply_status", "draw", "energy", "heal", "exhaust_self", "add_card", "coin"]
const STATUSES: Array[String] = ["poison", "bleed", "burn", "weak", "vulnerable", "might_buff", "wit_buff", "thorns", "regen", "vigil", "knell"]
const CARD_TYPES: Array[String] = ["attack", "skill", "power"]
const TARGETS: Array[String] = ["enemy", "all_enemies", "self", "none"]
const EFFECT_TARGETS: Array[String] = ["target", "self", "all_enemies"]
const RARITIES: Array[String] = ["basic", "common", "uncommon", "rare"]
const KEYWORDS: Array[String] = ["exhaust", "retain"]
const INTENTS: Array[String] = ["attack", "block", "buff", "debuff", "summon"]
const HOOKS: Array[String] = ["on_fight_start", "on_turn_start", "on_card_played", "on_damage_taken", "on_fight_end", "on_floor_enter"]
const NODE_KINDS: Array[String] = ["fight", "elite", "event", "rest", "shop"]
const ENEMY_KINDS: Array[String] = ["regular", "elite", "boss"]
const PATTERN_KINDS: Array[String] = ["sequence", "weighted"]
const ADD_CARD_WHERE: Array[String] = ["hand", "discard", "draw"]
const RUN_OPS: Array[String] = ["heal", "heal_percent", "damage", "coin", "soul", "add_card", "relic", "stat", "max_hp"]
const STATS: Array[String] = ["might", "wit", "vigor", "focus"]
const UPGRADE_GROUPS: Array[String] = ["hero", "ghosts", "descent", "seance"]
const UPGRADE_EFFECTS: Array[String] = ["stat", "max_resolve", "mend_discount", "global_strength", "global_spawn", "offline_cap", "restless_penalty"]


static func validate(c: Content) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(c.load_errors)
	for id in c.cards:
		_card(c, c.cards[id], errors)
	for id in c.enemies:
		_enemy(c, c.enemies[id], errors)
	for id in c.relics:
		_relic(c, c.relics[id], errors)
	for id in c.classes:
		_class(c, c.classes[id], errors)
	for id in c.biomes:
		_biome(c, c.biomes[id], errors)
	for id in c.events:
		_event(c, c.events[id], errors)
	for id in c.upgrades:
		_upgrade(c, c.upgrades[id], errors)
	for id in c.rules:
		_rule(c, c.rules[id], errors)
	return errors


## A priority rule may bend any of these. `death` and `lethal` are deliberately
## absent: they are what stop the autopilot walking into a loss, and the
## 30-turn fight cap (spec 10) rests on them. A rule that could soften them
## would be a rule that can hang a simulation.
static func _rule(c: Content, r: RuleDef, errors: Array[String]) -> void:
	var where := "rule '%s'" % r.id
	if r.id == "":
		errors.append("rule with no id")
	_key(c, where, r.name_key, errors)
	_key(c, where, r.text_key, errors)
	if r.weights.is_empty():
		errors.append("%s: adjusts nothing" % where)
	for path in r.weights:
		var name := String(path)
		if not PriorityRules.ADJUSTABLE.has(name):
			errors.append("%s: unknown or protected weight '%s'" % [where, name])
		var entry: Variant = r.weights[path]
		if not (entry is Dictionary):
			errors.append("%s: weight '%s' is not an adjustment" % [where, name])
			continue
		var adjust: Dictionary = entry
		if adjust.is_empty():
			errors.append("%s: weight '%s' adjusts nothing" % [where, name])
		for op in adjust:
			if not ["mul", "add"].has(String(op)):
				errors.append("%s: weight '%s' has unknown op '%s'" % [where, name, op])
			elif not (adjust[op] is float or adjust[op] is int):
				# Not `_amount_ok`: that one also accepts the string "x" for
				# X-cost card effects, and an X-cost multiplier is nothing.
				errors.append("%s: weight '%s' has a non-numeric %s" % [where, name, op])


static func _key(c: Content, where: String, key: String, errors: Array[String]) -> void:
	if key == "" or not c.strings.has(key):
		errors.append("%s: missing string key '%s'" % [where, key])


static func _amount_ok(value: Variant) -> bool:
	if value is float or value is int:
		return true
	return value is String and String(value).to_lower() == "x"


static func _effects(c: Content, where: String, effects: Array, errors: Array[String]) -> void:
	for raw in effects:
		if not (raw is Dictionary) or not raw.has("op"):
			errors.append("%s: effect without op" % where)
			continue
		var e: Dictionary = raw
		var op := String(e["op"])
		if not OPS.has(op):
			errors.append("%s: unknown op '%s'" % [where, op])
			continue
		if e.has("target") and not EFFECT_TARGETS.has(String(e["target"])):
			errors.append("%s: bad effect target '%s'" % [where, String(e["target"])])
		if e.has("amount") and not _amount_ok(e["amount"]):
			errors.append("%s: amount must be a number or \"x\"" % where)
		match op:
			"apply_status":
				if not STATUSES.has(String(e.get("status", ""))):
					errors.append("%s: unknown status '%s'" % [where, String(e.get("status", ""))])
				if not _amount_ok(e.get("stacks", 1)):
					errors.append("%s: stacks must be a number or \"x\"" % where)
			"add_card":
				if not c.cards.has(String(e.get("card", ""))):
					errors.append("%s: add_card references missing card '%s'" % [where, String(e.get("card", ""))])
				if not ADD_CARD_WHERE.has(String(e.get("where", "hand"))):
					errors.append("%s: add_card bad where '%s'" % [where, String(e.get("where", ""))])
			"damage", "block", "draw", "energy", "heal", "coin":
				if not e.has("amount"):
					errors.append("%s: op '%s' needs an amount" % [where, op])


static func _card(c: Content, card: CardDef, errors: Array[String]) -> void:
	var where := "card " + card.id
	if not CARD_TYPES.has(card.type):
		errors.append("%s: bad type '%s'" % [where, card.type])
	if not TARGETS.has(card.target):
		errors.append("%s: bad target '%s'" % [where, card.target])
	if not RARITIES.has(card.rarity):
		errors.append("%s: bad rarity '%s'" % [where, card.rarity])
	for k in card.keywords:
		if not KEYWORDS.has(k):
			errors.append("%s: bad keyword '%s'" % [where, k])
	if card.cost < CardDef.COST_X:
		errors.append("%s: bad cost" % where)
	_effects(c, where, card.effects, errors)
	_effects(c, where + " (upgraded)", card.upgrade_effects, errors)
	_key(c, where, card.name_key, errors)
	_key(c, where, card.text_key, errors)


static func _enemy(c: Content, enemy: EnemyDef, errors: Array[String]) -> void:
	var where := "enemy " + enemy.id
	if enemy.hp <= 0:
		errors.append("%s: hp must be positive" % where)
	if not ENEMY_KINDS.has(enemy.kind):
		errors.append("%s: bad kind '%s'" % [where, enemy.kind])
	_key(c, where, enemy.name_key, errors)
	for move_id in enemy.moves:
		var m: Dictionary = enemy.moves[move_id]
		var intent := String(m.get("intent", ""))
		var mwhere := "%s move %s" % [where, String(move_id)]
		if not INTENTS.has(intent):
			errors.append("%s: bad intent '%s'" % [mwhere, intent])
			continue
		match intent:
			"attack":
				if not m.has("damage"):
					errors.append("%s: attack needs damage" % mwhere)
				if m.has("status") and not STATUSES.has(String(m["status"])):
					errors.append("%s: unknown status '%s'" % [mwhere, String(m["status"])])
			"block":
				if not m.has("block"):
					errors.append("%s: block needs block" % mwhere)
			"buff", "debuff":
				if not STATUSES.has(String(m.get("status", ""))):
					errors.append("%s: unknown status '%s'" % [mwhere, String(m.get("status", ""))])
			"summon":
				if not c.enemies.has(String(m.get("enemy", ""))):
					errors.append("%s: summon references missing enemy '%s'" % [mwhere, String(m.get("enemy", ""))])
	var kind := String(enemy.pattern.get("kind", ""))
	if not PATTERN_KINDS.has(kind):
		errors.append("%s: bad pattern kind '%s'" % [where, kind])
		return
	var moves: Array = enemy.pattern.get("moves", [])
	if moves.is_empty():
		errors.append("%s: pattern has no moves" % where)
	for entry in moves:
		var move_ref := String(entry["move"]) if entry is Dictionary else String(entry)
		if not enemy.moves.has(move_ref):
			errors.append("%s: pattern references missing move '%s'" % [where, move_ref])
		if kind == "weighted":
			var weight := float(entry.get("weight", 0.0)) if entry is Dictionary else 0.0
			if weight <= 0.0:
				errors.append("%s: weighted move '%s' needs a positive weight" % [where, move_ref])


static func _relic(c: Content, relic: RelicDef, errors: Array[String]) -> void:
	var where := "relic " + relic.id
	for hook in relic.hooks:
		if not HOOKS.has(String(hook)):
			errors.append("%s: unknown hook '%s'" % [where, String(hook)])
			continue
		_effects(c, "%s %s" % [where, String(hook)], relic.hooks[hook], errors)
	_key(c, where, relic.name_key, errors)
	_key(c, where, relic.text_key, errors)


static func _class(c: Content, klass: ClassDef, errors: Array[String]) -> void:
	var where := "class " + klass.id
	if klass.base_hp <= 0:
		errors.append("%s: base_hp must be positive" % where)
	if klass.starting_deck.is_empty():
		errors.append("%s: starting_deck is empty" % where)
	for card_id in klass.starting_deck:
		if not c.cards.has(card_id):
			errors.append("%s: starting_deck references missing card '%s'" % [where, card_id])
	if not c.relics.has(klass.relic):
		errors.append("%s: relic '%s' missing" % [where, klass.relic])
	_key(c, where, klass.name_key, errors)


static func _biome(c: Content, biome: BiomeDef, errors: Array[String]) -> void:
	var where := "biome " + biome.id
	if biome.first_floor > biome.last_floor:
		errors.append("%s: floors out of order" % where)
	for enc in biome.encounters:
		var groups: Array = enc.get("groups", [])
		if groups.is_empty():
			errors.append("%s: encounter without groups" % where)
		for group in groups:
			if group.is_empty():
				errors.append("%s: empty encounter group" % where)
			for enemy_id in group:
				if not c.enemies.has(String(enemy_id)):
					errors.append("%s: encounter references missing enemy '%s'" % [where, String(enemy_id)])
	if biome.elites.is_empty():
		errors.append("%s: no elites" % where)
	for group in biome.elites:
		for enemy_id in group:
			if not c.enemies.has(String(enemy_id)):
				errors.append("%s: elite references missing enemy '%s'" % [where, String(enemy_id)])
	if biome.boss.is_empty():
		errors.append("%s: no boss" % where)
	for enemy_id in biome.boss:
		if not c.enemies.has(enemy_id):
			errors.append("%s: boss references missing enemy '%s'" % [where, enemy_id])
	if biome.node_patterns.is_empty():
		errors.append("%s: no node patterns" % where)
	for pattern in biome.node_patterns:
		for node in pattern:
			if not NODE_KINDS.has(String(node)):
				errors.append("%s: bad node kind '%s'" % [where, String(node)])
	_key(c, where, biome.name_key, errors)


static func _number(value: Variant) -> bool:
	return value is float or value is int


static func _run_effects(c: Content, where: String, effects: Array, errors: Array[String]) -> void:
	for raw in effects:
		if not (raw is Dictionary) or not raw.has("op"):
			errors.append("%s: effect without op" % where)
			continue
		var e: Dictionary = raw
		var op := String(e["op"])
		if not RUN_OPS.has(op):
			errors.append("%s: unknown run op '%s'" % [where, op])
			continue
		match op:
			"heal", "heal_percent", "damage", "coin", "soul", "max_hp":
				if not _number(e.get("amount")):
					errors.append("%s: op '%s' needs a numeric amount" % [where, op])
			"add_card":
				if not c.cards.has(String(e.get("card", ""))):
					errors.append("%s: add_card references missing card '%s'" % [where, String(e.get("card", ""))])
			"relic":
				if not c.relics.has(String(e.get("relic", ""))):
					errors.append("%s: relic references missing relic '%s'" % [where, String(e.get("relic", ""))])
			"stat":
				if not STATS.has(String(e.get("stat", ""))):
					errors.append("%s: unknown stat '%s'" % [where, String(e.get("stat", ""))])
				if not _number(e.get("amount")):
					errors.append("%s: stat needs a numeric amount" % where)


static func _event(c: Content, ev: EventDef, errors: Array[String]) -> void:
	var where := "event " + ev.id
	if ev.biome != "" and not c.biomes.has(ev.biome):
		errors.append("%s: unknown biome '%s'" % [where, ev.biome])
	if ev.choices.size() < 2 or ev.choices.size() > 3:
		errors.append("%s: needs 2 or 3 choices" % where)
	for raw in ev.choices:
		if not (raw is Dictionary):
			errors.append("%s: choice is not an object" % where)
			continue
		var choice: Dictionary = raw
		var choice_id := String(choice.get("id", ""))
		var cwhere := "%s choice '%s'" % [where, choice_id]
		if choice_id == "":
			errors.append("%s: choice without id" % where)
		_key(c, cwhere, String(choice.get("text", "")), errors)
		_run_effects(c, cwhere, choice.get("effects", []), errors)
	_key(c, where, ev.name_key, errors)
	_key(c, where, ev.text_key, errors)


static func _upgrade(c: Content, up: UpgradeDef, errors: Array[String]) -> void:
	var where := "upgrade " + up.id
	if not UPGRADE_GROUPS.has(up.group):
		errors.append("%s: bad group '%s'" % [where, up.group])
	var kind := String(up.effect.get("kind", ""))
	if not UPGRADE_EFFECTS.has(kind):
		errors.append("%s: unknown effect kind '%s'" % [where, kind])
	elif kind == "stat" and not STATS.has(String(up.effect.get("stat", ""))):
		errors.append("%s: unknown stat '%s'" % [where, String(up.effect.get("stat", ""))])
	if not _number(up.effect.get("amount")):
		errors.append("%s: effect needs a numeric amount" % where)
	if up.max_level < 1:
		errors.append("%s: max_level must be at least 1" % where)
	if up.base_cost <= 0.0:
		errors.append("%s: base_cost must be positive" % where)
	_key(c, where, up.name_key, errors)
	_key(c, where, up.text_key, errors)
