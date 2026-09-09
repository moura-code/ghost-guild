class_name CardInspector
extends VBoxContainer
## Copies of visible data only. Draw composition is sorted, never shuffled.

signal closed()
var cards: Array[CardInstance] = []
var pile: String = ""


static func composition(source: Array[CardInstance]) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in source:
		out.append(card.clone())
	out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return (a.def_id + str(a.upgraded)) < (b.def_id + str(b.upgraded)))
	return out


func build(content: Content, source: Array[CardInstance], title_key: String, fight: FightState = null, hero_stats: Dictionary = {}) -> void:
	for child in get_children():
		child.free()
	cards = composition(source)
	pile = title_key
	add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	var title := UiTheme.title(content.text(title_key) + " · " + str(cards.size()))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Button.new()
	back.text = content.text("ui.close")
	back.pressed.connect(func() -> void: closed.emit())
	head.add_child(back)
	add_child(head)
	if title_key == "ui.inspect.draw":
		add_child(UiTheme.body(content.text("ui.inspect.unordered")))
	if fight != null:
		var statuses := UiTheme.body(status_report(content, fight))
		statuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(statuses)
	for card in cards:
		var def: CardDef = content.cards[card.def_id]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label := content.text(def.name_key) + (content.text("ui.upgraded") if card.upgraded else "")
		var cost := def.cost_for(card.upgraded)
		label += " · " + content.text("ui.inspect.cost").replace("{n}", content.text("ui.card.cost_x") if cost == CardDef.COST_X else str(cost))
		row.add_child(UiTheme.title(label))
		var rules := UiTheme.body(MechanicsText.card_details(content, card, {"might": fight.might(), "wit": fight.wit()} if fight != null else hero_stats))
		rules.add_theme_font_size_override("font_size", CardView.RULE_FONT_SIZE)
		rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(rules)
		if fight != null:
			var status := UiTheme.body(content.text("ui.inspect.modifiers")
				.replace("{might}", str(fight.might())).replace("{wit}", str(fight.wit())))
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(status)
			if cost > fight.energy:
				row.add_child(UiTheme.body(content.text("ui.inspect.energy"), Palette.DANGER))
		var plate := ScreenLayout.plate(row)
		add_child(plate)


static func status_text(content: Content, id: String, stacks: int) -> String:
	return MechanicsText.status(content, id, stacks)


static func status_report(content: Content, fight: FightState) -> String:
	var lines: PackedStringArray = []
	for id in fight.statuses:
		lines.append(content.text("ui.hero") + " · " + status_text(content, String(id), int(fight.statuses[id])))
	for enemy in fight.enemies:
		if not enemy.alive:
			continue
		for id in enemy.statuses:
			lines.append(content.text((content.enemies[enemy.def_id] as EnemyDef).name_key) + " · " + status_text(content, String(id), int(enemy.statuses[id])))
	return "\n".join(lines) if not lines.is_empty() else content.text("ui.inspect.no_status")
