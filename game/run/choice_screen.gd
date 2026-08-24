class_name ChoiceScreen
extends VBoxContainer
## Reward, event, rest, shop and the Descent draft (spec §4.1 "Nodes",
## §3.2). All five are the same shape — a title, some context, and a column
## of things you may do — so they share one screen rather than five
## near-identical ones.
##
## The options come straight from RunEngine.legal_actions, which means the
## screen cannot offer a move the engine would refuse, and a shop item the
## player cannot afford simply is not listed.

const PHASES := ["reward", "event", "rest", "shop", "descent"]

var game: GameRoot
var run: RunState

## Which actions are worth showing as a card face rather than as a line of
## text. Winning a card is the payoff of a fight, and it was being delivered
## as a grey list row while the game already owned a drawn card face.
const CARD_ACTIONS := ["take_card", "draft_pick", "buy_card"]

var _title: Label
var _context: Label
var _fan: HBoxContainer
var _options: VBoxContainer
var _buttons: Array[Button] = []
var _cards: Array[CardView] = []
var _actions: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 10)


static func handles(phase: String) -> bool:
	return PHASES.has(phase)


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _options == null:
		_build()
	refresh()


func _build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	_title = ScreenLayout.centre(UiTheme.title(""))
	add_child(_title)

	_context = ScreenLayout.centre(UiTheme.body("", Palette.BONE_DIM))
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_context)

	# The prizes, laid out as cards; then everything else as a list.
	_fan = HBoxContainer.new()
	_fan.alignment = BoxContainer.ALIGNMENT_CENTER
	_fan.add_theme_constant_override("separation", 26)
	add_child(_fan)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	add_child(ScreenLayout.centred(_options))


func refresh() -> void:
	if game == null or run == null or not handles(run.phase):
		return
	_title.text = game.text("ui.run.phase.%s" % run.phase)
	_context.text = _context_text()
	_actions = _collapse(RunEngine.legal_actions(run))
	_rebuild_options()


## The shop offers one remove_card action per card in the deck, so a starter
## deck with five Strikes produced five identical "Burn Strike" buttons and a
## list that ran off the bottom of the screen. Collapsing by label keeps the
## first of each: removing any one copy is the same move to the player.
func _collapse(actions: Array) -> Array:
	var out: Array = []
	var seen := {}
	for action in actions:
		var label := label_for(action)
		if seen.has(label):
			continue
		seen[label] = true
		out.append(action)
	return out


## The shop shows the purse; an event shows its authored text. The other two
## need no more than their title.
func _context_text() -> String:
	match run.phase:
		"shop":
			return "%s %d" % [game.text("ui.coin"), run.coin]
		"event":
			var def: EventDef = game.content.events[run.event_id]
			return game.text(def.text_key)
		"descent":
			# One pick per floor skipped on the way down (spec §3.2).
			var offer: Dictionary = run.descent_offers[0]
			return game.text("ui.descent.offer").replace("{floor}", str(int(offer["floor"])))
	return ""


## What one option reads as, and how to take it, without a test having to
## know whether it is drawn as a card or as a row.
func option_label(index: int) -> String:
	if index < 0 or index >= _actions.size():
		return ""
	return label_for(_actions[index])


func take(index: int) -> void:
	_choose(index)


## Which card an offer is for, or "" if the option is not a card.
func _card_of(action: Dictionary) -> String:
	if not CARD_ACTIONS.has(String(action.get("kind", ""))):
		return ""
	return String(action.get("card", ""))


## Both pools are pooled, not churned — the same reason the fight's are.
func _rebuild_options() -> void:
	var offers: Array = []
	var rows: Array = []
	for i in _actions.size():
		if _card_of(_actions[i]) != "":
			offers.append(i)
		else:
			rows.append(i)

	while _cards.size() < offers.size():
		var card := CardView.new()
		card.pressed.connect(_on_card_pressed)
		_fan.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		var shown := i < offers.size()
		_cards[i].visible = shown
		if not shown:
			continue
		var index: int = offers[i]
		var instance := CardInstance.new()
		instance.uid = -1 - index
		instance.def_id = _card_of(_actions[index])
		_cards[i].bind(game.content, instance, index, true)
		_cards[i].tooltip_text = label_for(_actions[index])

	while _buttons.size() < rows.size():
		var button := Button.new()
		_options.add_child(button)
		_buttons.append(button)
	for i in _buttons.size():
		var used := i < rows.size()
		_buttons[i].visible = used
		if not used:
			continue
		var at: int = rows[i]
		_buttons[i].text = label_for(_actions[at])
		# Rebound every refresh: which action sits in which row moves as the
		# list shrinks, and a lambda captured at creation would go stale.
		for existing in _buttons[i].pressed.get_connections():
			_buttons[i].pressed.disconnect(existing["callable"])
		_buttons[i].pressed.connect(func() -> void: _choose(at))
		# Taking nothing should not look like a fourth prize.
		var refusal := ["skip_card", "draft_skip", "leave"].has(
			String(_actions[at].get("kind", "")))
		_buttons[i].add_theme_stylebox_override("normal",
			UiTheme.panel_box(Palette.VOID, Palette.STONE_RAISED) if refusal
			else UiTheme.list_row_box())
		_buttons[i].add_theme_color_override("font_color",
			Palette.BONE_FAINT if refusal else Palette.BONE)
		_buttons[i].size_flags_horizontal = (Control.SIZE_SHRINK_CENTER if refusal
			else Control.SIZE_FILL)
		_buttons[i].custom_minimum_size = Vector2(190.0 if refusal else 0.0, 0.0)


## CardView reports the index it was bound with, which is the action's.
func _on_card_pressed(index: int) -> void:
	_choose(index)


## What one action reads as. Kept public so a test can assert the wording
## without reaching into the button list.
func label_for(action: Dictionary) -> String:
	var kind := String(action.get("kind", ""))
	match kind:
		"take_card", "draft_pick":
			return _card_name(String(action["card"]))
		"draft_skip":
			return game.text("ui.choice.skip")
		"skip_card":
			return game.text("ui.choice.skip")
		"choose":
			var def: EventDef = game.content.events[run.event_id]
			var choice: Dictionary = def.choices[int(action["index"])]
			return game.text(String(choice.get("text", "")))
		"rest_heal":
			return game.text("ui.choice.rest_heal").replace("{amount}", str(_rest_heal_amount()))
		"rest_upgrade":
			return game.text("ui.choice.rest_upgrade").replace("{card}", _uid_name(int(action["uid"])))
		"buy_card":
			return "%s — %d" % [_card_name(String(action["card"])), int(run.shop["card_price"])]
		"buy_relic":
			return "%s — %d" % [_relic_name(String(run.shop["relic"])), int(run.shop["relic_price"])]
		"remove_card":
			return game.text("ui.choice.remove").replace("{card}", _uid_name(int(action["uid"]))) \
				+ " — %d" % int(run.shop["removal_price"])
		"leave":
			return game.text("ui.choice.leave")
	return kind


func _rest_heal_amount() -> int:
	var percent := float(game.content.balance.get("rest_heal_percent", 0.3))
	return int(roundf(float(run.hero.max_hp) * percent))


func _card_name(def_id: String) -> String:
	if game.content.cards.has(def_id):
		var def: CardDef = game.content.cards[def_id]
		return game.text(def.name_key)
	return def_id


func _relic_name(relic_id: String) -> String:
	if game.content.relics.has(relic_id):
		var def: RelicDef = game.content.relics[relic_id]
		return game.text(def.name_key)
	return relic_id


func _uid_name(uid: int) -> String:
	var card := run.hero.find_card(uid)
	if card == null:
		return str(uid)
	var name := _card_name(card.def_id)
	return name + game.text("ui.upgraded") if card.upgraded else name


func _choose(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	game.run_action(_actions[index])
