class_name HeroScreen
extends VBoxContainer
## The living hero (spec §3.3, §4.2): name, class, vitals, the four stats,
## and the deck the ghost will inherit. Read-only in M1-C1 -- everything
## spendable lives in the Guild and the Séance.

const STAT_IDS := ["might", "wit", "vigor", "focus"]

var game: GameRoot

var _name: Label
var _class: Label
var _vitals: Label
var _stats: Dictionary = {}
var _deck: VBoxContainer
var _relics: Label


func _init() -> void:
	add_theme_constant_override("separation", 10)


func bind(g: GameRoot) -> void:
	game = g
	if _deck == null:
		_build()
	if not g.hero_changed.is_connected(refresh):
		g.hero_changed.connect(refresh)
	refresh()


func _build() -> void:
	_name = UiTheme.title("")
	add_child(_name)
	_class = UiTheme.small("")
	add_child(_class)
	_vitals = UiTheme.body("")
	add_child(_vitals)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 18)
	for stat in STAT_IDS:
		var value := UiTheme.number("0", Palette.BONE)
		_stats[stat] = value
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(value)
		box.add_child(UiTheme.small(game.text("stat.%s.name" % stat)))
		stat_row.add_child(box)
	add_child(stat_row)

	add_child(UiTheme.small(game.text("ui.relics")))
	_relics = UiTheme.body("")
	_relics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_relics)

	add_child(UiTheme.small(game.text("ui.deck")))
	_deck = VBoxContainer.new()
	_deck.add_theme_constant_override("separation", 1)
	add_child(_deck)


func refresh() -> void:
	if game == null or game.campaign == null or game.campaign.hero == null:
		return
	var hero := game.campaign.hero
	_name.text = hero.name
	_class.text = game.text("class.%s.name" % hero.class_id)
	_vitals.text = "%s %d/%d   %s %d/%d   %s %d" % [
		game.text("ui.hp"), hero.hp, hero.max_hp,
		game.text("ui.resolve"), hero.resolve, hero.max_resolve,
		game.text("ui.camp"), hero.camp,
	]
	for stat in STAT_IDS:
		(_stats[stat] as Label).text = str(int(hero.stats.get(stat, 0)))
	_refresh_relics(hero)
	_refresh_deck(hero)


func _refresh_relics(hero: Hero) -> void:
	if hero.relics.is_empty():
		_relics.text = game.text("ui.none")
		return
	var names := PackedStringArray()
	for relic_id in hero.relics:
		names.append(game.text(_relic_name_key(relic_id)))
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
		var def_id := parts[0]
		var upgraded := parts[1] == "1"
		var label_text := "%d× %s" % [int(counts[key]), game.text(_card_name_key(def_id))]
		if upgraded:
			label_text += game.text("ui.upgraded")
		_deck.add_child(UiTheme.small(label_text, Palette.BONE))


func _card_name_key(def_id: String) -> String:
	if game.content.cards.has(def_id):
		var def: CardDef = game.content.cards[def_id]
		return def.name_key
	return def_id
