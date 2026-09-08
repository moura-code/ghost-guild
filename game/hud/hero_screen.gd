class_name HeroScreen
extends VBoxContainer
## The living hero (spec §3.3, §4.2): name, class, vitals, the four stats,
## and the deck the ghost will inherit. Read-only in M1-C1 -- everything
## spendable lives in the Guild and the Séance.

const STAT_IDS := ["might", "wit", "vigor", "focus"]
## Compact faces open a full, readable inspection view.
const DECK_CARD_SCALE := 0.56

var game: GameRoot
## One button per class in the data, locked ones included. Keyed by class id.
var class_rows: Dictionary = {}

var _name: Label
var _class_row: HBoxContainer
var _class: Label
var _vitals: Label
var _stats: Dictionary = {}
var _deck: HFlowContainer
var _relics: Label
var _relic_row: HBoxContainer
signal card_inspected(card: CardInstance)
var _figure: ModelPreview
var _visual_identity: String = ""
var _deck_identity: String = ""
var _relic_identity: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 5)
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
	var header := HFlowContainer.new()
	header.alignment = FlowContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("h_separation", 16)
	add_child(header)
	_figure = ModelPreview.new()
	_figure.custom_minimum_size = Vector2(145, 170)
	header.add_child(_figure)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 200
	identity.add_theme_constant_override("separation", 6)
	header.add_child(identity)

	_name = ScreenLayout.centre(UiTheme.title(""))
	identity.add_child(_name)
	_class = ScreenLayout.centre(UiTheme.small(""))
	identity.add_child(_class)

	# Who goes down next. Every class in the data is here, the locked ones
	# greyed with the biome that opens them on the tooltip -- a reward you
	# cannot see is not a reward. The row closes the moment this hero has
	# descended, because by then their deck was built rather than dealt.
	_class_row = HBoxContainer.new()
	_class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_class_row.add_theme_constant_override("separation", 6)
	var ids: Array = game.content.classes.keys()
	ids.sort()
	for id in ids:
		var button := Button.new()
		button.custom_minimum_size = Vector2(72.0, 16.0)
		# Inherit the shared HUD theme, including focus and disabled states.
		button.add_theme_font_size_override("font_size", UiTheme.FONT_BODY)
		button.pressed.connect(_on_class_pressed.bind(String(id)))
		_class_row.add_child(button)
		class_rows[String(id)] = button
	identity.add_child(_class_row)
	_vitals = ScreenLayout.centre(UiTheme.body(""))
	identity.add_child(_vitals)

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
	identity.add_child(stat_row)

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
	var hero := game.campaign.run.hero if game.campaign.run != null else game.campaign.hero
	var visual_id := hero.name + ":" + hero.class_id
	if _visual_identity != visual_id:
		_visual_identity = visual_id
		_figure.show_hero(hero)
	_name.text = hero.name
	_class.text = game.text(_class_name_key(hero.class_id))
	_vitals.text = "%s %d/%d   %s %d/%d   %s %d" % [
		game.text("ui.hp"), hero.hp, hero.max_hp,
		game.text("ui.resolve"), hero.resolve, hero.max_resolve,
		game.text("ui.camp"), hero.camp,
	]
	for stat in STAT_IDS:
		(_stats[stat] as Label).text = str(int(hero.stats.get(stat, 0)))
	_refresh_classes(hero)
	_refresh_relics(hero)
	_refresh_deck(hero)


## Which classes this hero could still become.
##
## A locked class shows what would open it; a hero who has descended shows
## nothing, because at that point the answer is "die first" and a row of dead
## buttons says that better than a sentence would.
func _refresh_classes(hero: Hero) -> void:
	var open := Classes.unlocked(game.content, game.campaign.ladder,
		game.campaign.claimed_biomes)
	var committed := hero.runs > 0 or game.campaign.run != null
	for id in class_rows:
		var button: Button = class_rows[id]
		var class_id := String(id)
		var def: ClassDef = game.content.classes[class_id]
		button.text = game.text(def.name_key)
		var behind := Classes.locked_behind(game.content, class_id)
		if not open.has(class_id) and behind != "":
			button.tooltip_text = game.text("ui.class.locked") \
				.replace("{biome}", game.text(_biome_name_key(behind)))
		elif class_id == hero.class_id:
			button.tooltip_text = game.text("ui.class.current")
		else:
			button.tooltip_text = game.text("ui.class.swap")
		button.disabled = committed or not open.has(class_id) or class_id == hero.class_id
		_style_class(button, class_id == hero.class_id, not button.disabled)


## Three states, and the tablets in the Guild already say what each looks
## like: the one you are is lit and unpressable, one you could become is an
## offer, and one you cannot reach recedes.
func _style_class(button: Button, current: bool, offered: bool) -> void:
	if current:
		button.add_theme_stylebox_override("normal",
			UiTheme.panel_box(Palette.VOID, Palette.PREPARED))
		button.add_theme_color_override("font_color", Palette.PREPARED)
		button.add_theme_color_override("font_disabled_color", Palette.PREPARED)
		return
	if offered:
		button.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.EDGE_LIGHT))
		button.add_theme_color_override("font_color", Palette.BONE)
		return
	button.add_theme_stylebox_override("normal",
		UiTheme.panel_box(Palette.VOID, Palette.STONE_RAISED))
	button.add_theme_color_override("font_disabled_color", Palette.BONE_FAINT)


func _biome_name_key(biome_id: String) -> String:
	if game.content.biomes.has(biome_id):
		return (game.content.biomes[biome_id] as BiomeDef).name_key
	return biome_id


func _on_class_pressed(class_id: String) -> void:
	game.choose_class(class_id)
	refresh()


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
	var identity := game.content.locale + str(hero.relics)
	if identity == _relic_identity:
		return
	_relic_identity = identity
	for child in _relic_row.get_children():
		child.free()
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
	var identity := game.content.locale + str(hero.deck.map(func(card: CardInstance) -> Dictionary: return card.to_dict()))
	if identity == _deck_identity:
		return
	_deck_identity = identity
	for child in _deck.get_children():
		child.free()
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
		var record := CardInstance.new(0, def_id, upgraded)
		card.bind(game.content, record, 0, true)
		card.pressed.connect(func(_index: int) -> void: card_inspected.emit(record))
		card.inspected.connect(func(value: CardInstance) -> void: card_inspected.emit(value))
		# Small enough that a thirty-card deck still fits the screen, big
		# enough that the art and the cost are legible.
		card.scale = Vector2(DECK_CARD_SCALE, DECK_CARD_SCALE)
		card.hover_scale = 1.5
		card.tooltip_text = "%s\n%s" % [card._name.text, card._text.text]
		card.pivot_offset = Vector2.ZERO
		# A scaled Control still reserves its unscaled size in a container,
		# so the flow has to be told how much room the card really takes.
		var slot := Control.new()
		slot.custom_minimum_size = CardView.CARD_SIZE * DECK_CARD_SCALE + Vector2(0, 11)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(card)
		_deck.add_child(slot)
		if int(counts[key]) > 1:
			var badge := UiTheme.small("x%d" % int(counts[key]), Palette.LANTERN)
			badge.position = Vector2(0, CardView.CARD_SIZE.y * DECK_CARD_SCALE + 1)
			badge.custom_minimum_size.x = slot.custom_minimum_size.x
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_child(badge)


func _card_name_key(def_id: String) -> String:
	if game.content.cards.has(def_id):
		var def: CardDef = game.content.cards[def_id]
		return def.name_key
	return def_id
