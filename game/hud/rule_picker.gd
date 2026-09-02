class_name RulePicker
extends VBoxContainer
## How your ghost will fight (spec §3.3).
##
## Taking the watch is the one death the player chooses, and until now the
## only thing they chose about it was *when*. This is the rest of it: up to
## three priority rules, in order, that bias the autopilot every simulation
## that ghost will ever run.
##
## Order is the point, not decoration. The first pick bends the scorer hardest
## (`PriorityRules.INFLUENCE`), so the badge on a chosen rule shows its
## position and picking the same three in a different order makes a different
## ghost. That is why this is a numbered list and not a set of checkboxes.
##
## Choosing nothing is legal and is stated rather than hidden -- a locked
## confirm button on a screen the player reached by choosing to die would be
## the cruellest possible place to put a modal.

signal confirmed(rule_ids: Array)
signal cancelled()

const ROW_HEIGHT := 40.0

var game: GameRoot

## Ordered, at most `PriorityRules.MAX`.
var chosen: Array[String] = []

var _list: VBoxContainer
var _summary: Label
var _confirm: Button
var _rows: Dictionary = {}
var _ids: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot, already: Array = []) -> void:
	game = g
	if _list == null:
		_build()
	_fill()
	chosen = PriorityRules.normalize_ids(already, g.content)
	_refresh()


## The rules on offer, in a stable order. Sorted by id rather than left in
## dictionary order: the loader's order depends on which file a rule came from
## and would reshuffle the list the day a second rules file is added.
func rule_ids() -> Array[String]:
	var out: Array[String] = []
	if game == null:
		return out
	var keys: Array = game.content.rules.keys()
	keys.sort()
	for key in keys:
		out.append(String(key))
	return out


## Adds `id` at the end, or takes it out again. A pick past the cap is
## ignored rather than pushing the first one out: silently replacing a choice
## the player made two clicks ago is worse than doing nothing visible.
func toggle(id: String) -> void:
	var at := chosen.find(id)
	if at >= 0:
		chosen.remove_at(at)
	elif chosen.size() < PriorityRules.MAX:
		chosen.append(id)
	_refresh()


## Where `id` sits in the order, 1-based, or 0 if it was not chosen.
func position_of(id: String) -> int:
	return chosen.find(id) + 1


func _build() -> void:
	var title := UiTheme.title(game.text("ui.watch.title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var hint := UiTheme.small(game.text("ui.watch.hint"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	# Scrolled, because twelve rules at launch becomes more later and a list
	# that runs off the bottom of a decision screen is a decision made blind.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420.0, 240.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_summary = UiTheme.small("", Palette.GHOST)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := Button.new()
	back.text = game.text("ui.watch.back")
	back.custom_minimum_size = Vector2(88.0, 22.0)
	back.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(back)
	_confirm = Button.new()
	_confirm.text = game.text("ui.watch.confirm")
	_confirm.custom_minimum_size = Vector2(150.0, 22.0)
	_confirm.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.GHOST))
	_confirm.add_theme_stylebox_override("hover", UiTheme.lit_box(Palette.STONE_HIGH, Palette.GHOST))
	_confirm.pressed.connect(func() -> void: confirmed.emit(chosen.duplicate()))
	buttons.add_child(_confirm)
	add_child(buttons)


func _fill() -> void:
	if not _rows.is_empty():
		return
	_ids = rule_ids()
	for id in _ids:
		var rule: RuleDef = game.content.rules[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.pressed.connect(toggle.bind(id))
		_list.add_child(button)
		_rows[id] = button


func _refresh() -> void:
	for id in _ids:
		var button: Button = _rows[id]
		var rule: RuleDef = game.content.rules[id]
		var place := position_of(id)
		# The number IS the feature. Without it the player has picked a set
		# and the game has read an ordered list.
		var name := game.text(rule.name_key)
		button.text = ("%d.  %s — %s" % [place, name, game.text(rule.text_key)]) if place > 0 \
			else ("%s — %s" % [name, game.text(rule.text_key)])
		button.add_theme_color_override("font_color", Palette.GHOST if place > 0 else Palette.BONE)
		if place > 0:
			button.add_theme_stylebox_override("normal", UiTheme.lit_box(Palette.STONE_HIGH, Palette.GHOST))
		else:
			button.remove_theme_stylebox_override("normal")
		# Full, and this one is not in it: greyed rather than hidden, so the
		# player can see what they are trading away by keeping their three.
		button.disabled = place == 0 and chosen.size() >= PriorityRules.MAX
	_summary.text = game.text("ui.watch.none") if chosen.is_empty() else _order_text()


func _order_text() -> String:
	var names: Array[String] = []
	for id in chosen:
		var rule: RuleDef = game.content.rules[id]
		names.append(game.text(rule.name_key))
	return game.text("ui.watch.order").replace("{rules}", ", ".join(names))
