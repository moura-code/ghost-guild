class_name RunRecap
extends VBoxContainer

signal closed()


func build(c: Campaign, result: Dictionary) -> void:
	for child in get_children():
		child.free()
	add_theme_constant_override("separation", 9)
	add_child(ScreenLayout.centre(UiTheme.title(c.content.text("help.recap.title"))))
	var text := c.content.text("help.recap.earnings").replace("{floor}", str(result.get("floor", 1))) \
		.replace("{soul}", Num.short(float(result.get("soul", 0.0))))
	var ghost := c.ladder.find(int(result.get("ghost_id", 0)))
	text += "\n" + (c.content.text("help.recap.ghost").replace("{name}", ghost.name).replace("{strength}", Num.short(ghost.strength)) if ghost != null else c.content.text("help.recap.retreat"))
	var next := affordable_upgrade(c)
	if next != "":
		var upgrade: UpgradeDef = c.content.upgrades[next]
		text += "\n\n" + c.content.text("help.recap.next").replace("{name}", c.content.text(upgrade.name_key)) \
			.replace("{price}", Num.short(c.upgrades.cost(c.content, next)))
		text += "\n" + MechanicsText.upgrade(c.content, c.hero, upgrade, c.upgrades.level(next))
	var body := UiTheme.body(text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(body)
	var close := Button.new()
	close.text = c.content.text("ui.close")
	close.pressed.connect(func() -> void: closed.emit())
	add_child(close)


static func affordable_upgrade(c: Campaign) -> String:
	# Prefer an immediately useful hero stat after a run; no purchase is made.
	for id in ["wit", "might", "vigor", "focus", "ghost_strength", "ghost_spawn"]:
		if c.upgrades.can_buy(c.content, id, c.soul):
			return id
	return ""
