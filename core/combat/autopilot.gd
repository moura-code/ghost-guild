class_name Autopilot
extends RefCounted
## Plays a turn by searching every distinct ordering of playable cards
## (bounded) on cloned states and scoring the result. Used by ghosts,
## projections, Expeditions and the balance simulator. Deterministic.

const MAX_SEQUENCES := 200

var weights: Dictionary = default_weights()
var last_explored: int = 0


## The table every autopilot starts from, and the one `PriorityRules` bends.
##
## A function rather than a const because a const Dictionary in GDScript is
## read-only, and because two autopilots must not share one table: a ghost
## that edited its weights in place would change how every other ghost fights.
##
## `cards_drawn` and `powers_played` are zero on purpose. Spec 3.3's own
## examples -- "Draw before attacking", "Powers on turn 1" -- cannot be
## expressed without them, and at zero they leave the scorer arithmetically
## identical to the one the balance simulator was tuned against. They are
## terms a rule turns on, not terms the game plays by default.
static func default_weights() -> Dictionary:
	return {
		"lethal": 1000.0,
		"death": -10000.0,
		"damage": 1.0,
		"kill": 25.0,
		"block_useful": 1.2,
		"block_excess": 0.1,
		"unblocked": -3.0,
		"hp_lost": -3.0,
		"heal": 1.0,
		"energy_left": -0.2,
		"ai_value": 0.1,
		"cards_drawn": 0.0,
		"powers_played": 0.0,
		"enemy_status": {"poison": 1.5, "vulnerable": 2.0, "weak": 2.0, "burn": 1.0},
		"hero_status": {"might_buff": 3.0, "wit_buff": 2.0, "thorns": 1.0, "vigil": 2.0, "regen": 1.0, "knell": 3.0},
	}


## An autopilot that fights the way `rule_ids` say. The one constructor every
## ghost-driven simulation should use, so "how does this ghost fight" has a
## single answer.
static func with_rules(rule_ids: Array, content: Content) -> Autopilot:
	var a := Autopilot.new()
	a.weights = PriorityRules.weights_for(default_weights(), rule_ids, content)
	return a


static func incoming_damage(s: FightState) -> int:
	var total := 0
	for i in s.living_enemy_indices():
		var intent := EnemyAI.intent_of(s, i)
		if String(intent.get("kind", "")) == "attack":
			total += int(intent["damage"]) * int(intent["hits"])
	return total


func choose_turn(s: FightState) -> Array:
	var incoming := incoming_damage(s)
	var best := {"score": -INF, "seq": []}
	var counter := {"n": 0}
	_explore(s, s, [], 0.0, 0, incoming, best, counter)
	last_explored = counter["n"]
	var out: Array = []
	for action in best["seq"]:
		out.append(action)
	out.append({"kind": "end_turn"})
	return out


func play_fight(s: FightState) -> Dictionary:
	while not s.is_over():
		var turn_before := s.turn
		for action in choose_turn(s):
			if s.is_over():
				break
			CombatEngine.apply(s, action)
		if not s.is_over() and s.turn == turn_before:
			push_error("autopilot made no progress; forcing end_turn")
			CombatEngine.apply(s, {"kind": "end_turn"})
	return {"won": s.phase == "won", "turns": s.turn, "hp": maxi(0, s.hero_hp)}


func _explore(start: FightState, s: FightState, seq: Array, ai_sum: float, powers: int, incoming: int, best: Dictionary, counter: Dictionary) -> void:
	counter["n"] += 1
	var score := _score(start, s, incoming, ai_sum, powers, seq.size())
	if score > best["score"]:
		best["score"] = score
		best["seq"] = seq.duplicate()
	if s.is_over() or counter["n"] >= MAX_SEQUENCES:
		return
	var seen := {}
	for action in CombatEngine.legal_actions(s):
		if String(action["kind"]) != "play":
			continue
		var card: CardInstance = s.hand[int(action["hand_index"])]
		var key := "%s|%s|%d" % [card.def_id, str(card.upgraded), int(action["target"])]
		if seen.has(key):
			continue
		seen[key] = true
		var next := s.clone()
		CombatEngine.apply(next, action)
		var next_seq := seq.duplicate()
		next_seq.append(action)
		var def := s.card_def(card)
		var next_powers := powers + (1 if def.type == "power" else 0)
		_explore(start, next, next_seq, ai_sum + def.ai_value, next_powers, incoming, best, counter)
		if counter["n"] >= MAX_SEQUENCES:
			return


func _score(start: FightState, s: FightState, incoming: int, ai_sum: float, powers: int, played: int) -> float:
	var w := weights
	if s.phase == "lost":
		return float(w["death"])
	var score := 0.0
	if s.all_enemies_dead():
		score += float(w["lethal"])
	var damage := 0
	var kills := 0
	for i in start.enemies.size():
		var before := start.enemies[i].hp
		var after := s.enemies[i].hp if i < s.enemies.size() else 0
		damage += maxi(0, before - after)
		if start.enemies[i].alive and (i >= s.enemies.size() or not s.enemies[i].alive):
			kills += 1
	score += damage * float(w["damage"]) + kills * float(w["kill"])
	var useful := mini(s.hero_block, incoming)
	var excess := maxi(0, s.hero_block - incoming)
	var unblocked := maxi(0, incoming - s.hero_block)
	if not s.all_enemies_dead():
		score += useful * float(w["block_useful"]) + excess * float(w["block_excess"]) + unblocked * float(w["unblocked"])
	var hp_delta := s.hero_hp - start.hero_hp
	score += (hp_delta * float(w["hp_lost"]) * -1.0) if hp_delta < 0 else hp_delta * float(w["heal"])
	score += s.energy * float(w["energy_left"])
	score += ai_sum * float(w["ai_value"])
	# Playing a card removes it from hand, so the hand delta alone understates
	# the draw by exactly the number of cards played.
	score += float((s.hand.size() - start.hand.size()) + played) * float(w["cards_drawn"])
	score += float(powers) * float(w["powers_played"])
	var enemy_w: Dictionary = w["enemy_status"]
	for i in s.living_enemy_indices():
		var before: Dictionary = start.enemies[i].statuses if i < start.enemies.size() else {}
		for status in enemy_w:
			var gained := s.enemies[i].status(status) - int(before.get(status, 0))
			score += maxi(0, gained) * float(enemy_w[status])
	var hero_w: Dictionary = w["hero_status"]
	for status in hero_w:
		var gained := s.hero_status(status) - start.hero_status(status)
		score += maxi(0, gained) * float(hero_w[status])
	return score
