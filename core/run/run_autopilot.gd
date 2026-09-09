class_name RunAutopilot
extends RefCounted
## Plays a whole run with simple policies on top of the fight Autopilot.
## Used by the run demo and the balance simulator; deterministic for a seed.

var fight_ap: Autopilot = Autopilot.new()
var push_threshold: float = 0.5
var survival_samples: int = 8
## The deepest floor this autopilot will *choose* to descend to, or 0 for no
## limit. Nothing in the shipped game sets it.
##
## The descent is infinite (§2), so the only thing that ends a run is the hero
## dying -- right for a game, wrong for a simulation that wants a bounded
## sample from an artificially durable hero.
##
## Advisory, not a stop: a hero with no Resolve who has not unlocked the watch
## has *no* legal exit action other than pushing, and an autopilot that refused
## to push there would deadlock rather than terminate. So the cap steers the
## choice and never removes the last option.
var max_floor: int = 0
## "all" visits each optional room once; "safe" skips elite detours.
var optional_policy: String = "all"


func play_run(run: RunState) -> Dictionary:
	var guard := 0
	while not run.is_over() and guard < 10000:
		guard += 1
		if run.phase == "fight":
			for action in fight_ap.choose_turn(run.fight):
				if run.phase != "fight":
					break
				RunEngine.apply(run, action)
			continue
		var action := choose(run)
		if action.is_empty():
			push_error("run autopilot: no action in phase " + run.phase)
			break
		RunEngine.apply(run, action)
	return run.outcome


func choose(run: RunState) -> Dictionary:
	match run.phase:
		"descent":
			var offer: Dictionary = run.descent_offers[0]
			return {"kind": "draft_pick", "floor": int(offer["floor"]), "card": _best_card(run, offer["cards"])}
		"node":
			return _next_room(run)
		"reward":
			var cards: Array = run.reward.get("cards", [])
			if cards.is_empty():
				return {"kind": "skip_card"}
			return {"kind": "take_card", "card": _best_card(run, cards)}
		"event":
			return {"kind": "choose", "index": 0}
		"rest":
			if run.hero.hp * 2 < run.hero.max_hp:
				return {"kind": "rest_heal"}
			var uid := _best_upgrade(run)
			return {"kind": "rest_upgrade", "uid": uid} if uid >= 0 else {"kind": "rest_heal"}
		"shop":
			var stock: Array = run.shop.get("cards", [])
			if not stock.is_empty() and run.coin >= int(run.shop["card_price"]):
				return {"kind": "buy_card", "card": _best_card(run, stock)}
			return {"kind": "leave"}
		"exit":
			var optional := _next_room(run)
			if not optional.is_empty():
				return optional
			var summary := RunEngine.exit_summary(run, survival_samples)
			var capped := max_floor > 0 and run.floor >= max_floor
			var keen := float(summary["survival"]) >= push_threshold
			if not capped and bool(summary["can_push"]) and keen:
				return {"kind": "push"}
			if bool(summary["can_watch"]):
				return {"kind": "watch"}
			if bool(summary["can_retreat"]):
				return {"kind": "retreat"}
			if bool(summary["can_push"]):
				return {"kind": "push"}
	return {}


func _best_card(run: RunState, ids: Array) -> String:
	var best := ""
	var best_value := -INF
	for id in ids:
		var card: CardDef = run.content.cards[id]
		if card.ai_value > best_value:
			best_value = card.ai_value
			best = String(id)
	return best


func _best_upgrade(run: RunState) -> int:
	var best := -1
	var best_value := -INF
	for card in run.hero.deck:
		if card.upgraded:
			continue
		var def: CardDef = run.content.cards[card.def_id]
		if def.ai_value > best_value:
			best_value = def.ai_value
			best = card.uid
	return best


func _next_room(run: RunState) -> Dictionary:
	for i in run.nodes.size():
		if run.is_resolved(i) or not run.can_enter(i):
			continue
		if optional_policy == "safe" and run.nodes[i].get("kind") == "elite" and not bool(run.room_record(i).get("required", true)):
			continue
		return {"kind": "enter", "index": i}
	return {}
