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
		"event":
			var ev: EventDef = run.content.events[run.event_id]
			for i in ev.choices.size():
				out.append({"kind": "choose", "index": i})
		"rest":
			out.append({"kind": "rest_heal"})
			for card in run.hero.deck:
				if not card.upgraded:
					out.append({"kind": "rest_upgrade", "uid": card.uid})
		"shop":
			for card_id in run.shop.get("cards", []):
				if run.coin >= int(run.shop["card_price"]):
					out.append({"kind": "buy_card", "card": card_id})
			if String(run.shop.get("relic", "")) != "" and run.coin >= int(run.shop["relic_price"]):
				out.append({"kind": "buy_relic"})
			if not bool(run.shop.get("removed", false)) and run.coin >= int(run.shop["removal_price"]):
				for card in run.hero.deck:
					out.append({"kind": "remove_card", "uid": card.uid})
			out.append({"kind": "leave"})
		"exit":
			if can_push(run):
				out.append({"kind": "push"})
			if run.hero.resolve > 0:
				out.append({"kind": "retreat"})
			if can_watch(run):
				out.append({"kind": "watch"})
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
		"event":
			_apply_event(run, kind, action)
		"rest":
			_apply_rest(run, kind, action)
		"shop":
			_apply_shop(run, kind, action)
		"exit":
			_apply_exit(run, kind)
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


static func loss_cause_of(f: FightState) -> String:
	for i in range(f.events.size() - 1, -1, -1):
		var ev: Dictionary = f.events[i]
		if ev["type"] == "fight_lost":
			return String(ev.get("reason", ""))
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
		"rest":
			run.phase = "rest"
		"shop":
			_open_shop(run)
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
	run.hero.hp = maxi(0, f.hero_hp) if won else 0
	var cause := "" if won else loss_cause_of(f)
	run.emit({"type": "fight_result", "won": won, "turns": f.turn, "hp": run.hero.hp, "floor": run.floor, "kind": kind, "cause": cause})
	if not won:
		var killer := killer_of(f) if cause == "hero_died" else ""
		_end_run(run, "death", killer, cause)
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
	run.reward = {"cards": cards.duplicate()}
	run.phase = "reward"
	run.emit({"type": "reward_offer", "cards": cards.duplicate()})


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


static func _end_run(run: RunState, kind: String, killer: String = "", cause: String = "") -> void:
	var bonus := run.stat_bonus.duplicate()
	run.stat_bonus.clear()
	var rate := float(run.content.balance.get("coin_to_soul", 0.1))
	var soul_from_coin := run.coin * rate
	run.outcome = {
		"kind": kind,
		"floor": run.floor,
		"killer": killer,
		"cause": cause,
		"coin": run.coin,
		"soul_from_coin": soul_from_coin,
		"soul": run.soul + soul_from_coin,
		"hero_hp": run.hero.hp,
		"stat_bonus": bonus,
	}
	run.fight = null
	run.phase = "ended"
	run.emit({"type": "run_end", "kind": kind, "floor": run.floor, "killer": killer, "cause": cause, "soul": run.outcome["soul"]})


static func _apply_event(run: RunState, kind: String, action: Dictionary) -> void:
	if kind != "choose":
		push_error("run: expected choose, got " + kind)
		return
	var ev: EventDef = run.content.events[run.event_id]
	var index := int(action.get("index", -1))
	if index < 0 or index >= ev.choices.size():
		push_error("choose: bad index %d" % index)
		return
	var choice: Dictionary = ev.choices[index]
	run.emit({"type": "event_choice", "event": run.event_id, "choice": String(choice.get("id", ""))})
	RunEffects.apply(run, choice.get("effects", []))
	run.event_id = ""
	_advance(run)


static func _apply_rest(run: RunState, kind: String, action: Dictionary) -> void:
	if kind == "rest_heal":
		var amount := int(round(run.hero.max_hp * float(run.content.balance.get("rest_heal_percent", 0.3))))
		RunEffects.heal(run, amount)
		run.emit({"type": "rest", "choice": "heal"})
	elif kind == "rest_upgrade":
		var uid := int(action.get("uid", -1))
		if not run.hero.upgrade_card(uid):
			push_error("rest_upgrade: cannot upgrade uid %d" % uid)
			return
		run.emit({"type": "rest", "choice": "upgrade", "uid": uid})
	else:
		push_error("run: expected rest_heal or rest_upgrade, got " + kind)
		return
	_advance(run)


static func _open_shop(run: RunState) -> void:
	var balance := run.content.balance
	var rng := run.sub_rng("shop", run.floor)
	var cards := Rewards.card_offer(run.content, _pools(run), rng, balance, int(balance.get("shop_card_count", 3)))
	run.shop = {
		"cards": cards.duplicate(),
		"relic": Rewards.relic_offer(run.content, run.hero.relics, rng),
		"card_price": int(balance.get("shop_card_price", 50)),
		"relic_price": int(balance.get("shop_relic_price", 150)),
		"removal_price": int(balance.get("shop_removal_price", 75)),
		"removed": false,
	}
	run.phase = "shop"
	run.emit({"type": "shop_open", "cards": cards.duplicate(), "relic": run.shop["relic"]})


static func _apply_shop(run: RunState, kind: String, action: Dictionary) -> void:
	match kind:
		"buy_card":
			var card_id := String(action.get("card", ""))
			var price := int(run.shop["card_price"])
			if not run.shop["cards"].has(card_id) or run.coin < price:
				push_error("buy_card: cannot buy " + card_id)
				return
			run.add_coin(-price)
			run.shop["cards"].erase(card_id)
			var card := run.hero.add_card(card_id)
			run.emit({"type": "shop_buy", "item": "card", "card": card_id, "uid": card.uid, "price": price})
		"buy_relic":
			var relic_id := String(run.shop.get("relic", ""))
			var price := int(run.shop["relic_price"])
			if relic_id == "" or run.coin < price:
				push_error("buy_relic: cannot buy")
				return
			run.add_coin(-price)
			run.shop["relic"] = ""
			run.grant_relic(relic_id)
			run.emit({"type": "shop_buy", "item": "relic", "relic": relic_id, "price": price})
		"remove_card":
			var uid := int(action.get("uid", -1))
			var price := int(run.shop["removal_price"])
			if bool(run.shop["removed"]) or run.coin < price or run.hero.find_card(uid) == null:
				push_error("remove_card: cannot remove uid %d" % uid)
				return
			run.hero.remove_card(uid)
			run.add_coin(-price)
			run.shop["removed"] = true
			run.emit({"type": "shop_buy", "item": "removal", "uid": uid, "price": price})
		"leave":
			run.shop = {}
			run.emit({"type": "shop_leave"})
			_advance(run)
		_:
			push_error("run: unknown shop action " + kind)


static func can_push(run: RunState) -> bool:
	return run.floor < run.biome().last_floor


static func can_watch(run: RunState) -> bool:
	return run.watch_unlocked or not can_push(run)


static func exit_summary(run: RunState, samples: int = -1) -> Dictionary:
	var n := samples if samples >= 0 else int(run.content.balance.get("survival_samples", 20))
	var survival := -1.0
	if can_push(run):
		survival = RunProjection.survival_chance(run.content, run.hero_snapshot(), run.biome(), run.floor + 1, run.run_seed, n)
	return {
		"floor": run.floor,
		"measured": run.stats.measured(run.floor),
		"next_floor": run.floor + 1,
		"survival": survival,
		"can_push": can_push(run),
		"can_retreat": run.hero.resolve > 0,
		"can_watch": can_watch(run),
	}


static func _apply_exit(run: RunState, kind: String) -> void:
	match kind:
		"push":
			if not can_push(run):
				push_error("push: no deeper floor in this biome")
				return
			run.emit({"type": "exit_decision", "floor": run.floor, "choice": "push"})
			run.floor += 1
			_enter_floor(run)
		"retreat":
			if run.hero.resolve <= 0:
				push_error("retreat: no Resolve left")
				return
			run.hero.resolve -= 1
			run.hero.camp = run.floor
			run.emit({"type": "exit_decision", "floor": run.floor, "choice": "retreat", "resolve": run.hero.resolve})
			_end_run(run, "retreat")
		"watch":
			if not can_watch(run):
				push_error("watch: locked until the first death")
				return
			run.emit({"type": "exit_decision", "floor": run.floor, "choice": "watch"})
			_end_run(run, "watch")
		_:
			push_error("run: unknown exit action " + kind)
