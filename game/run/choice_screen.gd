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
## Tall enough that a choice reads as something you press rather than as a
## line of text with a rule under it.
const CHOICE_HEIGHT := 46.0
## A comfortable measure for a paragraph of authored text.
const TEXT_WIDTH := 560.0

var game: GameRoot
var run: RunState

## Which actions are worth showing as a card face rather than as a line of
## text. Winning a card is the payoff of a fight, and it was being delivered
## as a grey list row while the game already owned a drawn card face.
const CARD_ACTIONS := ["take_card", "draft_pick", "buy_card"]

var _title: Label
var _decor: HBoxContainer
var _context: Label
var _context_plate: PanelContainer
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

	# An authored encounter's text sits on something, the way a notice nailed
	# to a wall does. Floating a single grey line in the middle of an empty
	# frame is what made the event screen the flattest in the game.
	_context = ScreenLayout.centre(UiTheme.body("", Palette.BONE))
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context.custom_minimum_size = Vector2(0.0, 30.0)
	_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_plate = PanelContainer.new()
	_context_plate.add_theme_stylebox_override("panel",
		UiTheme.panel_box(Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.72)))
	_context_plate.add_child(_context)
	add_child(ScreenLayout.centred(_context_plate, TEXT_WIDTH))

	# The prizes, laid out as cards; then everything else as a list.
	_fan = HBoxContainer.new()
	_fan.alignment = BoxContainer.ALIGNMENT_CENTER
	_fan.add_theme_constant_override("separation", 26)
	add_child(_fan)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	add_child(ScreenLayout.centred(_options))

	# Candles either side of the choice. These screens are a title, a line of
	# text and some rows in the middle of an empty frame; a pair of flames
	# gives the light somewhere to come from and the eye something to sit on.
	_decor = HBoxContainer.new()
	_decor.alignment = BoxContainer.ALIGNMENT_CENTER
	_decor.add_theme_constant_override("separation", 620)
	_decor.add_child(Prop.of(Prop.Kind.CANDLE, 3))
	_decor.add_child(Prop.of(Prop.Kind.CANDLE, 8))
	add_child(_decor)
	# No rubble here. Debris needs a floor to lie on, and floating in the
	# middle of an empty frame it read as loose grey rectangles rather than
	# as broken stone -- decor that draws attention to itself is worse than
	# no decor.


func refresh() -> void:
	if game == null or run == null or not handles(run.phase):
		return
	_title.text = _title_text()
	_context.text = _context_text()
	if _context_plate != null:
		# A rest or a card pick says nothing here, and an empty plate is
		# worse than no plate.
		(_context_plate.get_parent() as Control).visible = _context.text != ""
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


## An event is titled with its own name -- "The Whispering Well" -- not with
## the literal word "event". The phase key is a fine heading for a shop or a
## card pick, which are the same thing every time; an authored encounter is
## the one place in the run with a name of its own, and throwing it away for
## a generic label was the single flattest thing on any screen.
func _title_text() -> String:
	if run.phase == "event" and game.content.events.has(run.event_id):
		var def: EventDef = game.content.events[run.event_id]
		var named := game.text(def.name_key)
		if named != "" and named != def.name_key:
			return named
	return game.text("ui.run.phase.%s" % run.phase)


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


## The choice itself: the cards or the rows, plus the line of text above
## them. The title sits outside it -- the light should land on what the
## player has to decide.
func focus_rect() -> Rect2:
	if _options == null or not _options.is_inside_tree():
		return Rect2()
	var box: Rect2 = _options.get_global_rect()
	if _fan != null and _fan.is_inside_tree() and _fan.visible and _fan.size.x > 0.0:
		box = box.merge(_fan.get_global_rect())
	return Rect2(box.position - global_position - Vector2(110.0, 90.0),
		box.size + Vector2(220.0, 170.0))


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
		# A choice is a carved plaque, not an underlined row of text. An
		# authored encounter offering "Drink. Heal 12." as a list item with a
		# rule under it is the flattest thing the game does -- this is the
		# moment the run turns on, and it should have some weight under the
		# cursor.
		if refusal:
			var walk := UiTheme.panel_box(Palette.VOID, Palette.STONE_RAISED)
			walk.bevel = 3.0
			walk.pegs = false
			_buttons[i].add_theme_stylebox_override("normal", walk)
		else:
			_buttons[i].add_theme_stylebox_override("normal",
				UiTheme.panel_box(Palette.STONE_RAISED))
			_buttons[i].add_theme_stylebox_override("hover",
				UiTheme.lit_box(Palette.STONE_HIGH, Palette.EDGE_LIGHT))
		_buttons[i].add_theme_color_override("font_color",
			Palette.BONE_FAINT if refusal else Palette.BONE)
		_buttons[i].size_flags_horizontal = (Control.SIZE_SHRINK_CENTER if refusal
			else Control.SIZE_FILL)
		_buttons[i].custom_minimum_size = Vector2(190.0 if refusal else 0.0,
			0.0 if refusal else CHOICE_HEIGHT)


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
