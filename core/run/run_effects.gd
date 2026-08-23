class_name RunEffects
extends RefCounted
## Applies run-scoped effect ops (events, rewards, rest) to a RunState.
## Ops and their fields are the ContentValidator.RUN_OPS conventions.


static func apply(run: RunState, effects: Array) -> void:
	for raw in effects:
		var e: Dictionary = raw
		var op := String(e.get("op", ""))
		var amount := int(e.get("amount", 0))
		match op:
			"heal":
				heal(run, amount)
			"heal_percent":
				heal(run, int(round(run.hero.max_hp * float(e.get("amount", 0)) / 100.0)))
			"damage":
				run.hero.hp = clampi(run.hero.hp - amount, 0, run.hero.max_hp)
				run.emit({"type": "hero_damaged", "amount": amount, "hp": run.hero.hp})
			"coin":
				run.add_coin(amount)
			"soul":
				run.add_soul(float(e.get("amount", 0)))
			"add_card":
				var card := run.hero.add_card(String(e.get("card", "")))
				run.emit({"type": "card_gained", "uid": card.uid, "card": card.def_id})
			"relic":
				run.grant_relic(String(e.get("relic", "")))
			"stat":
				var stat := String(e.get("stat", ""))
				run.stat_bonus[stat] = int(run.stat_bonus.get(stat, 0)) + amount
				run.emit({"type": "stat_changed", "stat": stat, "amount": amount, "total": run.stat_bonus[stat]})
			"max_hp":
				run.hero.max_hp += amount
				run.hero.hp = clampi(run.hero.hp + amount, 0, run.hero.max_hp)
				run.emit({"type": "max_hp_changed", "amount": amount, "max_hp": run.hero.max_hp, "hp": run.hero.hp})
			_:
				push_error("unknown run op: " + op)


static func heal(run: RunState, amount: int) -> void:
	var before := run.hero.hp
	run.hero.hp = clampi(run.hero.hp + amount, 0, run.hero.max_hp)
	run.emit({"type": "hero_healed", "amount": run.hero.hp - before, "hp": run.hero.hp})
