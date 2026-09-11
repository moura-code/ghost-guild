class_name ChoiceScreen
extends VBoxContainer
## Reward, event, rest, shop and the Descent draft (spec §4.1 "Nodes",
## §3.2). All five are the same shape — a title, some context, and a column
## of things you may do — so they share one screen rather than five
## near-identical ones.
##
## Inventory remains visible when unaffordable. Selecting an item is read-only;
## the separate commit button submits the captured room context.

const PHASES := ["reward", "event", "rest", "shop", "descent"]
## Tall enough that a choice reads as something you press rather than as a
## line of text with a rule under it.
const CHOICE_HEIGHT := 22.0
## A comfortable measure for a paragraph of authored text.
const TEXT_WIDTH := 280.0
signal card_inspected(card: CardInstance)
signal deck_requested()

var game: GameRoot
var run: RunState

## Which actions are worth showing as a card face rather than as a line of
## text. Winning a card is the payoff of a fight, and it was being delivered
## as a grey list row while the game already owned a drawn card face.
const CARD_ACTIONS := ["take_card", "draft_pick", "buy_card"]

var selected: Dictionary = {}
var _selection: VBoxContainer
var _comparison: Label
var _commit: Button
var _cancel: Button
var _bound_context: Dictionary = {}
var lesson: TeachingMoment
var lesson_settings: Settings
var lesson_settings_path: String = Settings.PATH
var _title: Label
var _decor: HBoxContainer
var _context: Label
var _context_plate: PanelContainer
var _fan: HFlowContainer
var _resources: Button
var _close_shop: Button
var _lift_room: Control
var _options: VBoxContainer
var _buttons: Array[Button] = []
var _cards: Array[CardView] = []
var _card_prices: Array[Label] = []
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
	lesson = TeachingMoment.new()
	lesson.dismissed.connect(func(id: String) -> void:
		if lesson_settings != null and not lesson_settings.dismissed_lessons.has(id):
			lesson_settings.dismissed_lessons.append(id)
			lesson_settings.save(lesson_settings_path)
		lesson.hide())
	lesson.details_requested.connect(func() -> void:
		_context.text = game.text("help.lesson.upgrade")
		(_context_plate.get_parent() as Control).show())
	add_child(lesson)
	_title = ScreenLayout.centre(UiTheme.title(""))
	add_child(_title)
	_resources = Button.new()
	_resources.pressed.connect(func() -> void: deck_requested.emit())
	var resource_row := HBoxContainer.new()
	_resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_row.add_child(_resources)
	_close_shop = Button.new()
	_close_shop.text = "Esc · " + game.text("ui.choice.leave")
	_close_shop.pressed.connect(func() -> void: _choose(_actions.size() - 1))
	resource_row.add_child(_close_shop)
	add_child(resource_row)

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

	# A card lifts under the cursor, and the top row of a reward is close
	# enough to the heading that the lift printed the card over it. The gap is
	# the lift, named as the lift, so the two cannot drift apart.
	_lift_room = Control.new()
	_lift_room.custom_minimum_size = Vector2(0.0, CardView.hover_headroom())
	_lift_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lift_room)

	# The prizes, laid out as cards; then everything else as a list.
	_fan = HFlowContainer.new()
	_fan.alignment = FlowContainer.ALIGNMENT_CENTER
	_fan.add_theme_constant_override("h_separation", 26)
	_fan.add_theme_constant_override("v_separation", 20)
	add_child(_fan)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	add_child(ScreenLayout.centred(_options))

	_selection = VBoxContainer.new()
	_selection.add_theme_constant_override("separation", 6)
	add_child(_selection)
	_comparison = UiTheme.body("")
	_comparison.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection.add_child(_comparison)
	var controls := HBoxContainer.new()
	_selection.add_child(controls)
	_commit = Button.new()
	_commit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_commit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commit.pressed.connect(commit_selection)
	controls.add_child(_commit)
	_cancel = Button.new()
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.text = game.text("help.cancel")
	_cancel.pressed.connect(cancel_selection)
	controls.add_child(_cancel)
	_selection.hide()

	# Candles either side of the choice. These screens are a title, a line of
	# text and some rows in the middle of an empty frame; a pair of flames
	# gives the light somewhere to come from and the eye something to sit on.
	_decor = HBoxContainer.new()
	_decor.alignment = BoxContainer.ALIGNMENT_CENTER
	_decor.add_theme_constant_override("separation", 100)
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
	lesson.hide()
	if run.phase == "rest" and lesson_settings != null and not lesson_settings.dismissed_lessons.has("upgrade"):
		lesson.present(game.content, "upgrade")
	_title.text = _title_text()
	_close_shop.visible = run.phase == "shop"
	_lift_room.custom_minimum_size.y = CardView.hover_headroom() if run.phase in ["reward", "descent"] else (8.0 if run.phase == "shop" else 0.0)
	_resources.text = resources_text(game.content, run)
	_context.text = _context_text()
	if _context_plate != null:
		# A rest or a card pick says nothing here, and an empty plate is
		# worse than no plate.
		(_context_plate.get_parent() as Control).visible = _context.text != ""
	_bound_context = run.action_context()
	_actions = _collapse(display_actions())
	cancel_selection()
	_rebuild_options()


## Preserve individual copy identities for upgrades and removal. Only
## genuinely identical actions (such as duplicate stock offers) collapse.
func _collapse(actions: Array) -> Array:
	var out: Array = []
	var seen := {}
	for action in actions:
		var label := label_for(action) + (str(action["uid"]) if action.has("uid") else "")
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
			return "" # The persistent resource button already shows the purse.
		"event":
			var def: EventDef = game.content.events[run.event_id]
			return game.text(def.text_key)
		"rest":
			return game.text("help.select_card")
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
	return Rect2(box.position - global_position - Vector2(55.0, 45.0),
		box.size + Vector2(110.0, 85.0))


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
		card.inspected.connect(func(value: CardInstance) -> void: card_inspected.emit(value))
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 3)
		slot.add_child(card)
		var price := ScreenLayout.centre(UiTheme.body("", Palette.LANTERN))
		slot.add_child(price)
		slot.move_child(price, 0)
		_fan.add_child(slot)
		_cards.append(card)
		_card_prices.append(price)
	for i in _cards.size():
		var shown := i < offers.size()
		_cards[i].visible = shown
		(_cards[i].get_parent() as Control).visible = shown
		if not shown:
			continue
		var index: int = offers[i]
		var instance := CardInstance.new()
		instance.uid = -1 - index
		instance.def_id = _card_of(_actions[index])
		_cards[i].bind(game.content, instance, index, affordability(_actions[index]) == "")
		_cards[i].tooltip_text = label_for(_actions[index]) + "\n" + affordability(_actions[index])
		_card_prices[i].visible = run.phase == "shop"
		_card_prices[i].text = "%d %s" % [price_for(_actions[index]), game.text("ui.coin")]

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
		_buttons[i].tooltip_text = affordability(_actions[at])
		_buttons[i].disabled = run.phase == "event" and not RunEffects.can_apply(run, (game.content.events[run.event_id] as EventDef).choices[int(_actions[at]["index"])].get("effects", []))
		_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		_buttons[i].custom_minimum_size = Vector2(95.0 if refusal else 0.0,
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
			return MechanicsText.event_choice(run, choice)
		"rest_heal":
			return game.text("ui.choice.rest_heal").replace("{amount}", str(_rest_heal_amount()))
		"rest_upgrade":
			return game.text("ui.choice.rest_upgrade").replace("{card}", _uid_name(int(action["uid"]))) + " · #" + str(action["uid"])
		"buy_card":
			return "%s — %d %s" % [_card_name(String(action["card"])), int(run.shop["card_price"]), game.text("ui.coin")]
		"buy_relic":
			return "%s — %d" % [_relic_name(String(run.shop["relic"])), int(run.shop["relic_price"])]
		"remove_card":
			return game.text("ui.choice.remove").replace("{card}", _uid_name(int(action["uid"]))) \
				+ " · #%d — %d" % [int(action["uid"]), int(run.shop["removal_price"])]
		"leave":
			return game.text("ui.choice.leave")
	return kind


func _rest_heal_amount() -> int:
	var percent := float(game.content.balance.get("rest_heal_percent", 0.3))
	return mini(run.hero.max_hp - run.hero.hp, int(roundf(float(run.hero.max_hp) * percent)))


static func resources_text(content: Content, state: RunState) -> String:
	return "%s %d/%d · %s %d · %s %d · %s %d/%d" % [
		content.text("ui.hp"), state.hero.hp, state.hero.max_hp,
		content.text("ui.coin"), state.coin, content.text("ui.deck"), state.hero.deck.size(),
		content.text("ui.resolve"), state.hero.resolve, state.hero.max_resolve]


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
	if not _context_matches():
		return
	var action: Dictionary = _actions[index]
	if action.get("kind") in ["rest_upgrade", "remove_card", "buy_card", "buy_relic"]:
		select_action(action)
		return
	action = action.duplicate(true)
	action["context"] = _bound_context.duplicate()
	game.run_action(action)


func display_actions() -> Array:
	if run.phase == "event":
		var out: Array = []
		var ev: EventDef = game.content.events[run.event_id]
		for i in ev.choices.size():
			out.append({"kind": "choose", "index": i})
		return out
	if run.phase != "shop":
		return RunEngine.legal_actions(run)
	var out: Array = []
	for id in run.shop.get("cards", []):
		out.append({"kind": "buy_card", "card": id})
	if run.shop.get("relic", "") != "":
		out.append({"kind": "buy_relic"})
	if not bool(run.shop.get("removed", false)):
		for card in run.hero.deck:
			out.append({"kind": "remove_card", "uid": card.uid})
	out.append({"kind": "leave"})
	return out


func price_for(action: Dictionary) -> int:
	match action.get("kind", ""):
		"buy_card": return int(run.shop.get("card_price", 0))
		"buy_relic": return int(run.shop.get("relic_price", 0))
		"remove_card": return int(run.shop.get("removal_price", 0))
	return 0


func affordability(action: Dictionary) -> String:
	var missing := price_for(action) - run.coin
	return game.text("help.need_coin").replace("{n}", str(missing)) if missing > 0 else ""


func select_action(action: Dictionary) -> void:
	selected = action.duplicate(true)
	selected["context"] = _bound_context.duplicate()
	var kind := String(action["kind"])
	var stats := run.hero_snapshot().stats
	if kind == "rest_upgrade":
		_comparison.text = MechanicsText.comparison(game.content, run.hero, int(action["uid"]), stats)
		_commit.text = game.text("help.commit_upgrade").replace("{uid}", str(action["uid"]))
	elif kind == "remove_card":
		_comparison.text = _uid_name(int(action["uid"])) + "\n" + MechanicsText.card_details(game.content, run.hero.find_card(int(action["uid"])), stats) + "\n" + game.text("help.remove")
		_commit.text = game.text("help.commit_remove").replace("{uid}", str(action["uid"]))
	elif kind == "buy_card":
		var card := CardInstance.new(-1, String(action["card"]), false)
		_comparison.text = _card_name(card.def_id) + "\n" + MechanicsText.card_details(game.content, card, stats) + "\n" + game.text("help.scope.item")
		_commit.text = game.text("help.commit_buy")
	elif kind == "buy_relic":
		var relic: RelicDef = game.content.relics[String(run.shop["relic"])]
		_comparison.text = game.text(relic.name_key) + "\n" + game.text(relic.text_key) + "\n" + game.text("help.scope.item")
		_commit.text = game.text("help.commit_buy")
	_commit.text = _commit.text.replace("{price}", str(price_for(action)))
	_commit.disabled = affordability(action) != ""
	if _commit.disabled:
		_comparison.text += "\n" + affordability(action)
	_selection.show()
	_lift_room.hide()
	(_options.get_parent() as Control).hide()
	(_context_plate.get_parent() as Control).hide()
	_fan.hide()
	_decor.hide()
	lesson.hide()
	_commit.grab_focus() if not _commit.disabled else _cancel.grab_focus()


func cancel_selection() -> void:
	selected = {}
	if _selection != null:
		_selection.hide()
		_lift_room.show()
		(_options.get_parent() as Control).show()
		(_context_plate.get_parent() as Control).visible = _context.text != ""
		_fan.show()
		_decor.show()


func _context_matches() -> bool:
	return game != null and game.campaign.run == run and run != null \
		and run.run_seed == _bound_context.get("run_seed") and run.floor == _bound_context.get("floor") \
		and run.action_context() == _bound_context


func commit_selection() -> void:
	if selected.is_empty() or not _context_matches() or affordability(selected) != "":
		return
	var action := selected.duplicate(true)
	cancel_selection()
	game.run_action(action)
