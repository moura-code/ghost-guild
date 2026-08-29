class_name HeroScreen
extends VBoxContainer
## The living hero (spec §3.3, §4.2): name, class, vitals, the four stats,
## and the deck the ghost will inherit. Read-only in M1-C1 -- everything
## spendable lives in the Guild and the Séance.

const STAT_IDS := ["might", "wit", "vigor", "focus"]
## A whole starting deck has to fit on the sheet without scrolling.
const DECK_CARD_SCALE := 0.42

var game: GameRoot

var _name: Label
var _class: Label
var _vitals: Label
var _stats: Dictionary = {}
var _deck: HFlowContainer
var _relics: Label
var _relic_row: HBoxContainer
var _figure: TextureRect


func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if _deck == null:
		_build()
	if not g.hero_changed.is_connected(refresh):
		g.hero_changed.connect(refresh)
	refresh()


func _build() -> void:
	# The hero stands at the top of their own sheet. Every other screen in
	# the game now has a figure on it; a page of labels looked like the
	# options menu by comparison.
	_figure = Icons.make_rect(Icons.ui("hero"), 40.0, Palette.BONE)
	_figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_figure)

	_name = ScreenLayout.centre(UiTheme.title(""))
	add_child(_name)
	_class = ScreenLayout.centre(UiTheme.small(""))
	add_child(_class)
	_vitals = ScreenLayout.centre(UiTheme.body(""))
	add_child(_vitals)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 12)
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for stat in STAT_IDS:
		# Each stat in its own chip, so the four read as a set of readings
		# rather than as four loose numbers on a page.
		var value := ScreenLayout.centre(UiTheme.number("0", Palette.BONE))
		_stats[stat] = value
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.custom_minimum_size = Vector2(42.0, 0.0)
		box.add_child(value)
		box.add_child(ScreenLayout.centre(UiTheme.small(game.text("stat.%s.name" % stat))))
		var chip := PanelContainer.new()
		chip.add_child(box)
		stat_row.add_child(chip)
	add_child(stat_row)

	add_child(ScreenLayout.centre(UiTheme.small(game.text("ui.relics"))))
	# Relics are objects you carry, so they are shown as objects. A relic
	# rendered as a word in a comma-separated list has no more weight than
	# a footnote.
	_relic_row = HBoxContainer.new()
	_relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_row.add_theme_constant_override("separation", 10)
	add_child(_relic_row)
	_relics = ScreenLayout.centre(UiTheme.small("", Palette.BONE_DIM))
	_relics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_relics)

	add_child(ScreenLayout.centre(UiTheme.small(game.text("ui.deck"))))
	# The deck as cards, not as "5x Strike / 4x Brace". This is the screen
	# where a player looks at what they have built, and a bulleted text list
	# is the least persuasive possible way to show them a deck.
	_deck = HFlowContainer.new()
	_deck.add_theme_constant_override("h_separation", 8)
	_deck.add_theme_constant_override("v_separation", 8)
	_deck.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(ScreenLayout.centred(_deck, ScreenLayout.WIDE_COLUMN))


func refresh() -> void:
	if game == null or game.campaign == null or game.campaign.hero == null:
		return
	var hero := game.campaign.hero
	_name.text = hero.name
	_class.text = game.text(_class_name_key(hero.class_id))
	_vitals.text = "%s %d/%d   %s %d/%d   %s %d" % [
		game.text("ui.hp"), hero.hp, hero.max_hp,
		game.text("ui.resolve"), hero.resolve, hero.max_resolve,
		game.text("ui.camp"), hero.camp,
	]
	for stat in STAT_IDS:
		(_stats[stat] as Label).text = str(int(hero.stats.get(stat, 0)))
	_refresh_relics(hero)
	_refresh_deck(hero)


## The hero themselves, not the deck below them.
func focus_rect() -> Rect2:
	if _figure == null or not _figure.is_inside_tree():
		return Rect2()
	var box := _figure.get_global_rect()
	return Rect2(box.position - global_position - Vector2(75.0, 20.0),
		box.size + Vector2(150.0, 160.0))


func _class_name_key(class_id: String) -> String:
	if game.content.classes.has(class_id):
		var def: ClassDef = game.content.classes[class_id]
		return def.name_key
	return class_id


func _refresh_relics(hero: Hero) -> void:
	for child in _relic_row.get_children():
		_relic_row.remove_child(child)
		child.queue_free()
	if hero.relics.is_empty():
		_relics.text = game.text("ui.none")
		return
	var names := PackedStringArray()
	for relic_id in hero.relics:
		var name := game.text(_relic_name_key(String(relic_id)))
		names.append(name)
		var plate := Icons.make_plate(Icons.relic(String(relic_id)), 17.0,
			Palette.BONE, Palette.PLATE_NEUTRAL, Palette.EDGE_LIGHT)
		plate.tooltip_text = name
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		_relic_row.add_child(plate)
	_relics.text = ", ".join(names)


func _relic_name_key(relic_id: String) -> String:
	if game.content.relics.has(relic_id):
		var def: RelicDef = game.content.relics[relic_id]
		return def.name_key
	return relic_id


## Cards collapse by definition and upgrade state, so a 30-card deck reads
## as a dozen lines rather than thirty.
func _refresh_deck(hero: Hero) -> void:
	for child in _deck.get_children():
		_deck.remove_child(child)
		child.queue_free()
	var counts := {}
	var order: Array[String] = []
	for card in hero.deck:
		var key := "%s|%s" % [card.def_id, "1" if card.upgraded else "0"]
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] = int(counts[key]) + 1
	for key in order:
		var parts := key.split("|")
		var def_id := String(parts[0])
		var upgraded := parts[1] == "1"
		var card := CardView.new()
		card.bind(game.content, CardInstance.new(0, def_id, upgraded), 0, true)
		# Small enough that a thirty-card deck still fits the screen, big
		# enough that the art and the cost are legible.
		card.scale = Vector2(DECK_CARD_SCALE, DECK_CARD_SCALE)
		card.pivot_offset = Vector2.ZERO
		# A scaled Control still reserves its unscaled size in a container,
		# so the flow has to be told how much room the card really takes.
		var slot := Control.new()
		slot.custom_minimum_size = CardView.CARD_SIZE * DECK_CARD_SCALE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(card)
		_deck.add_child(slot)
		if int(counts[key]) > 1:
			var badge := UiTheme.small("x%d" % int(counts[key]), Palette.LANTERN)
			badge.position = Vector2(4.0, 2.0)
			slot.add_child(badge)


func _card_name_key(def_id: String) -> String:
	if game.content.cards.has(def_id):
		var def: CardDef = game.content.cards[def_id]
		return def.name_key
	return def_id
