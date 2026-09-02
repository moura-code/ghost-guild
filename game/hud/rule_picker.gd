class_name RulePicker
extends VBoxContainer
## How your ghost will fight (spec §3.3).
##
## Taking the watch is the one death the player chooses, and until now the
## only thing they chose about it was *when*. This is the rest of it: up to
## three priority rules, in order, that bias the autopilot in every simulation
## that ghost will ever run.
##
## Order is the point, not decoration. The first pick bends the scorer hardest
## (`PriorityRules.INFLUENCE`), so a chosen rule wears its position and the
## same three in a different order make a different ghost. That is why this is
## a numbered list and not a set of checkboxes.
##
## **Twelve names in a grid, one description at a time.** The first cut put
## each rule's full sentence on its own row: at the HUD's 640x360 authoring
## space that is a 12-row scrolling list with clipped text, where choosing
## means scrolling past choices you cannot see. Names fit in two columns with
## room to spare; the sentence belongs to whichever rule the player is
## actually pointing at.
##
## Choosing nothing is legal and is stated rather than hidden -- a locked
## confirm button on a screen the player reached by choosing to die would be
## the cruellest possible place to put a modal.

signal confirmed(rule_ids: Array)
signal cancelled()

## Two columns of six, in the 640x360 space every kept widget is authored in.
const COLUMNS := 2
const CELL := Vector2(196.0, 20.0)

var game: GameRoot

## Ordered, at most `PriorityRules.MAX`.
var chosen: Array[String] = []

var _grid: GridContainer
var _blurb: Label
var _summary: Label
var _confirm: Button
var _rows: Dictionary = {}
var _ids: Array[String] = []
## Whichever rule the player is pointing at, or the last one they chose.
var _focus: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot, already: Array = []) -> void:
	game = g
	if _grid == null:
		_build()
	_fill()
	chosen = PriorityRules.normalize_ids(already, g.content)
	_focus = chosen[0] if not chosen.is_empty() else ""
	_refresh()


## The rules on offer, in a stable order. Sorted by id rather than left in
## dictionary order: the loader's order depends on which file a rule came from,
## and the list would reshuffle the day a second rules file is added.
func rule_ids() -> Array[String]:
	var out: Array[String] = []
	if game == null:
		return out
	var keys: Array = game.content.rules.keys()
	keys.sort()
	for key in keys:
		out.append(String(key))
	return out


## Adds `id` at the end, or takes it out again. A pick past the cap is ignored
## rather than pushing the first one out: silently replacing a choice the
## player made two clicks ago is worse than doing nothing visible.
func toggle(id: String) -> void:
	var at := chosen.find(id)
	if at >= 0:
		chosen.remove_at(at)
	elif chosen.size() < PriorityRules.MAX:
		chosen.append(id)
	_focus = id
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

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 3)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_grid)

	# One description, for whatever is under the cursor. Body rather than
	# small: it is the only prose on the screen and the thing the player is
	# actually reading, and at FONT_SMALL it sat under 8px buttons looking
	# like a footnote about them.
	# Fixed height, so the grid above it does not jump every time the mouse
	# moves.
	_blurb = UiTheme.body("", Palette.BONE)
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.custom_minimum_size = Vector2(400.0, 26.0)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_blurb)

	_summary = UiTheme.body("", Palette.GHOST)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.custom_minimum_size = Vector2(400.0, 18.0)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
		var button := Button.new()
		button.custom_minimum_size = CELL
		button.clip_text = true
		button.pressed.connect(toggle.bind(id))
		# Pointing at a rule is how you read it. Kept separate from choosing,
		# so the player can survey all twelve without committing to one.
		button.mouse_entered.connect(_look_at.bind(id))
		_grid.add_child(button)
		_rows[id] = button


func _look_at(id: String) -> void:
	_focus = id
	_refresh_blurb()


func _refresh() -> void:
	for id in _ids:
		var button: Button = _rows[id]
		var rule: RuleDef = game.content.rules[id]
		var place := position_of(id)
		# The number IS the feature. Without it the player has picked a set
		# and the game has read an ordered list.
		var name := game.text(rule.name_key)
		button.text = "%d. %s" % [place, name] if place > 0 else name
		button.add_theme_color_override("font_color", Palette.GHOST if place > 0 else Palette.BONE)
		if place > 0:
			button.add_theme_stylebox_override("normal", UiTheme.lit_box(Palette.STONE_HIGH, Palette.GHOST))
		else:
			button.remove_theme_stylebox_override("normal")
		# Full, and this one is not in it: greyed rather than hidden, so the
		# player can see what they are trading away by keeping their three.
		button.disabled = place == 0 and chosen.size() >= PriorityRules.MAX
	_refresh_blurb()
	_summary.text = game.text("ui.watch.none") if chosen.is_empty() else _order_text()


func _refresh_blurb() -> void:
	if _focus == "" or not game.content.rules.has(_focus):
		_blurb.text = ""
		return
	var rule: RuleDef = game.content.rules[_focus]
	_blurb.text = game.text(rule.text_key)


func _order_text() -> String:
	var names: Array[String] = []
	for id in chosen:
		var rule: RuleDef = game.content.rules[id]
		names.append(game.text(rule.name_key))
	return game.text("ui.watch.order").replace("{rules}", ", ".join(names))
