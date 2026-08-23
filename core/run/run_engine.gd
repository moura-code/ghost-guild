class_name RunEngine
extends RefCounted
## The rules of a run: a state machine over RunState. Static functions
## mutate the state and return the events they produced, like CombatEngine.
## During a fight node, actions are forwarded to CombatEngine.


static func start_run(content: Content, hero: Hero, biome_id: String, entry_floor: int, run_seed: int, watch_unlocked: bool) -> RunState:
	var run := RunState.new()
	run.content = content
	run.hero = hero
	run.run_seed = run_seed
	run.biome_id = biome_id
	run.entry_floor = entry_floor
	run.floor = entry_floor
	run.watch_unlocked = watch_unlocked
	hero.runs += 1
	run.emit({"type": "run_start", "seed": run_seed, "entry_floor": entry_floor, "hero": hero.name})
	run.descent_offers = DescentDraft.offers(content, hero, run.biome(), entry_floor, run_seed)
	for offer in run.descent_offers:
		run.emit({"type": "draft_offer", "floor": offer["floor"], "cards": offer["cards"]})
	if run.descent_offers.is_empty():
		_enter_floor(run)
	else:
		run.phase = "descent"
	return run


static func legal_actions(run: RunState) -> Array:
	var out: Array = []
	match run.phase:
		"descent":
			var offer: Dictionary = run.descent_offers[0]
			for card_id in offer["cards"]:
				out.append({"kind": "draft_pick", "floor": int(offer["floor"]), "card": card_id})
			out.append({"kind": "draft_skip", "floor": int(offer["floor"])})
		"node":
			out.append({"kind": "enter"})
		"fight":
			out = CombatEngine.legal_actions(run.fight)
		"reward":
			for card_id in run.reward.get("cards", []):
				out.append({"kind": "take_card", "card": card_id})
			out.append({"kind": "skip_card"})
	return out


static func apply(run: RunState, action: Dictionary) -> Array:
	if run.is_over():
		return []
	var start := run.events.size()
	var kind := String(action.get("kind", ""))
	var combat_events: Array = []
	match run.phase:
		"descent":
			_apply_descent(run, kind, action)
		"node":
			if kind == "enter":
				_enter_node(run)
			else:
				push_error("run: expected enter, got " + kind)
		"fight":
			combat_events = CombatEngine.apply(run.fight, action)
			if run.fight.is_over():
				_finish_fight(run)
		"reward":
			_apply_reward(run, kind, action)
		_:
			push_error("run: no handler for phase " + run.phase)
	var out: Array = combat_events.duplicate()
	out.append_array(run.events.slice(start))
	return out


static func killer_of(f: FightState) -> String:
	for i in range(f.events.size() - 1, -1, -1):
		var ev: Dictionary = f.events[i]
		if ev["type"] != "damage" or String(ev.get("target", "")) != "hero" or int(ev.get("amount", 0)) <= 0:
			continue
		if ev.has("source"):
			return f.enemies[int(ev["source"])].def_id
		return String(ev.get("cause", ""))
	return ""


static func _apply_descent(run: RunState, kind: String, action: Dictionary) -> void:
	var offer: Dictionary = run.descent_offers[0]
	var offer_floor := int(offer["floor"])
	if kind == "draft_pick":
		var card_id := String(action.get("card", ""))
		if not offer["cards"].has(card_id):
			push_error("draft_pick: card not offered: " + card_id)
			return
		var card := run.hero.add_card(card_id)
		run.emit({"type": "draft_pick", "floor": offer_floor, "card": card_id, "uid": card.uid})
	elif kind == "draft_skip":
		run.emit({"type": "draft_skip", "floor": offer_floor})
	else:
		push_error("run: expected draft_pick or draft_skip, got " + kind)
		return
	run.hero.picks_taken[offer_floor] = true
	run.descent_offers.remove_at(0)
	if run.descent_offers.is_empty():
		_enter_floor(run)


static func _enter_floor(run: RunState) -> void:
	run.nodes = FloorGenerator.generate(run.content, run.biome(), run.floor, run.sub_rng("floor", run.floor), run.used_events)
	var kinds: Array = []
	for node in run.nodes:
		kinds.append(node["kind"])
		if String(node["kind"]) == "event":
			run.used_events.append(String(node["event"]))
	run.node_index = 0
	run.phase = "node"
	run.emit({"type": "floor_enter", "floor": run.floor, "nodes": kinds})


static func _enter_node(run: RunState) -> void:
	var node := run.current_node()
	var kind := String(node.get("kind", ""))
	run.emit({"type": "node_enter", "index": run.node_index, "kind": kind})
	match kind:
		"fight", "elite", "boss":
			_start_fight(run, node)
		"event":
			run.event_id = String(node["event"])
			run.phase = "event"
		"rest", "shop":
			run.phase = kind
		_:
			push_error("unknown node kind: " + kind)
			_advance(run)


static func _start_fight(run: RunState, node: Dictionary) -> void:
	run.fight_counter += 1
	var enemies: Array = node.get("enemies", [])
	run.fight = CombatEngine.start_fight(run.content, run.hero_snapshot(), enemies, run.floor, run.sub_rng("fight", run.fight_counter))
	run.phase = "fight"
	run.emit({"type": "fight_begin", "index": run.node_index, "kind": String(node["kind"]), "enemies": enemies.duplicate()})


static func _finish_fight(run: RunState) -> void:
	var f := run.fight
	var node := run.current_node()
	var kind := String(node.get("kind", "fight"))
	var won := f.phase == "won"
	run.stats.record(run.floor, won, f.turn)
	run.hero.hp = maxi(0, f.hero_hp)
	run.emit({"type": "fight_result", "won": won, "turns": f.turn, "hp": run.hero.hp, "floor": run.floor, "kind": kind})
	if not won:
		_end_run(run, "death", killer_of(f))
		return
	var coin := Rewards.coin_for(kind, run.floor, run.content.balance)
	for ev in f.events:
		if ev["type"] == "coin":
			coin += int(ev["amount"])
	run.add_coin(coin)
	run.add_soul(Rewards.soul_for(run.floor, run.content.balance))
	var rng := run.sub_rng("reward", run.fight_counter)
	if kind == "elite" or kind == "boss":
		var relic_id := Rewards.relic_offer(run.content, run.hero.relics, rng)
		if relic_id != "":
			run.grant_relic(relic_id)
	var cards := Rewards.card_offer(run.content, _pools(run), rng, run.content.balance, Rewards.OFFER_SIZE, kind == "boss")
	run.reward = {"cards": Array(cards)}
	run.phase = "reward"
	run.emit({"type": "reward_offer", "cards": Array(cards)})


static func _pools(run: RunState) -> Array:
	var klass: ClassDef = run.content.classes[run.hero.class_id]
	return [klass.pool, run.biome().card_pool]


static func _apply_reward(run: RunState, kind: String, action: Dictionary) -> void:
	if kind == "take_card":
		var card_id := String(action.get("card", ""))
		if not run.reward.get("cards", []).has(card_id):
			push_error("take_card: not offered: " + card_id)
			return
		var card := run.hero.add_card(card_id)
		run.emit({"type": "reward_taken", "card": card_id, "uid": card.uid})
	elif kind == "skip_card":
		run.emit({"type": "reward_skipped"})
	else:
		push_error("run: expected take_card or skip_card, got " + kind)
		return
	run.reward = {}
	_advance(run)


static func _advance(run: RunState) -> void:
	if run.node_index < run.nodes.size() - 1:
		run.node_index += 1
		run.phase = "node"
	else:
		run.phase = "exit"
		run.emit({"type": "floor_cleared", "floor": run.floor})


static func _end_run(run: RunState, kind: String, killer: String = "") -> void:
	run.stat_bonus.clear()
	var rate := float(run.content.balance.get("coin_to_soul", 0.1))
	var soul_from_coin := run.coin * rate
	run.outcome = {
		"kind": kind,
		"floor": run.floor,
		"killer": killer,
		"coin": run.coin,
		"soul_from_coin": soul_from_coin,
		"soul": run.soul + soul_from_coin,
		"hero_hp": run.hero.hp,
	}
	run.fight = null
	run.phase = "ended"
	run.emit({"type": "run_end", "kind": kind, "floor": run.floor, "killer": killer, "soul": run.outcome["soul"]})
