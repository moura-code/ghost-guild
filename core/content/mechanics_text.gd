class_name MechanicsText
extends RefCounted
## Shared, read-only explanations. Authored rules and current modifiers stay
## separate; inspecting never runs a combat action or draws randomness.

static func stat(content: Content, id: String, value: int) -> String:
	var line := content.text("help.stat." + id).replace("{value}", str(value))
	if id == "vigor":
		return line.replace("{hp}", str(HeroSnapshot.max_hp_for(0, value))) \
			.replace("{per}", str(HeroSnapshot.max_hp_for(0, 1)))
	if id != "focus":
		return line
	var draw := 0
	var energy := 0
	var next := 2147483647
	var next_kind := ""
	for kind in ["draw", "energy"]:
		for raw in content.balance.get("focus_" + kind + "_thresholds", []):
			var threshold := int(raw)
			if value >= threshold:
				if kind == "draw":
					draw += 1
				else:
					energy += 1
			elif threshold < next:
				next = threshold
				next_kind = kind
	line = line.replace("{draw}", str(draw)).replace("{energy}", str(energy))
	return line + " " + (content.text("help.focus.next").replace("{n}", str(next))
		.replace("{benefit}", content.text("help.effect." + next_kind)) if next_kind != "" else content.text("help.focus.capped"))


static func status(content: Content, id: String, stacks: int = 1) -> String:
	return (content.text("status." + id + ".name") + ": " + content.text("status." + id + ".help")) \
		.replace("{n}", str(stacks)).replace("{weak}", str(roundi(float(content.balance["weak_multiplier"]) * 100)) + "%") \
		.replace("{vulnerable}", str(roundi(float(content.balance["vulnerable_multiplier"]) * 100)) + "%")


static func scaling(content: Content, def: CardDef, upgraded: bool, stats: Dictionary = {}) -> String:
	var lines := PackedStringArray()
	for effect in def.effects_for(upgraded):
		var scale := String(effect.get("scale", ""))
		if scale == "":
			continue
		var label := content.text("status." + String(effect["status"]) + ".name") if effect.has("status") else content.text("help.effect." + String(effect["op"]))
		var base: Variant = effect.get("amount", effect.get("stacks", 0))
		var stat_name := content.text("stat." + scale + ".name")
		if base is String or stats.is_empty():
			lines.append(content.text("help.scaling.rule").replace("{effect}", label).replace("{stat}", stat_name))
		else:
			var bonus := int(stats.get(scale, 0))
			lines.append(content.text("help.scaling.sum").replace("{effect}", label).replace("{base}", str(base))
				.replace("{bonus}", str(bonus)).replace("{stat}", stat_name).replace("{total}", str(int(base) + bonus)))
	return "\n".join(lines)


static func card_details(content: Content, card: CardInstance, stats: Dictionary = {}) -> String:
	var def: CardDef = content.cards[card.def_id]
	var lines := PackedStringArray([CardText.of(content, def, card.upgraded)])
	var scaled := scaling(content, def, card.upgraded, stats)
	if scaled != "":
		lines.append(scaled)
	lines.append(content.text("help.target." + def.target))
	for keyword in def.keywords:
		lines.append(content.text("help.keyword." + keyword))
	for effect in def.effects_for(card.upgraded):
		if effect.get("op") == "apply_status":
			lines.append(status(content, String(effect["status"])))
	return "\n".join(lines)


static func cost(content: Content, value: int) -> String:
	return content.text("ui.card.cost_x") if value == CardDef.COST_X else str(value)


static func comparison(content: Content, hero: Hero, uid: int, stats: Dictionary = {}) -> String:
	var card := hero.find_card(uid)
	if card == null:
		return ""
	var def: CardDef = content.cards[card.def_id]
	var up := card.clone()
	up.upgraded = true
	var counts := {"plain": 0, "upgraded": 0}
	for copy in hero.deck:
		if copy.def_id == card.def_id:
			counts["upgraded" if copy.upgraded else "plain"] += 1
	return content.text(def.name_key) + " · " + content.text("help.type." + def.type) + " · " \
		+ content.text("ui.inspect.cost").replace("{n}", cost(content, def.cost_for(false)) + " → " + cost(content, def.cost_for(true))) \
		+ "\n" + content.text("help.copy").replace("{uid}", str(uid)).replace("{plain}", str(counts["plain"])) \
		.replace("{upgraded}", str(counts["upgraded"])) + "\n" + content.text("help.before") + "\n" \
		+ card_details(content, card, stats) + "\n\n" + content.text("help.after") + "\n" \
		+ card_details(content, up, stats) + "\n\n" + content.text("help.scope.card").replace("{hero}", hero.name)


static func upgrade(content: Content, hero: Hero, def: UpgradeDef, level: int) -> String:
	var line := content.text(def.name_key) + " · " + str(level) + " → " + str(mini(level + 1, def.max_level))
	line += "\n" + content.text(def.text_key)
	if def.effect.get("kind") == "stat":
		var id := String(def.effect["stat"])
		var before := int(hero.stats.get(id, 0))
		var after := before + (int(def.effect["amount"]) if level < def.max_level else 0)
		line += "\n" + str(before) + " → " + str(after) + "\n" + stat(content, id, after)
	line += "\n" + content.text("help.scope.guild_hero" if def.group == "hero" else "help.scope.guild")
	if level >= def.max_level:
		line += "\n" + content.text("help.capped")
	return line
